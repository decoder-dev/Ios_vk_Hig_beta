import SwiftUI
import UIKit
import Observation

struct CommentThread: Identifiable, Equatable {
    var id: Int64 { root.id }
    var root: CommentItem
    var replies: [CommentItem]
    var totalReplies: Int
}

@MainActor
@Observable
final class CommentsViewModel {
    let postID: Int64
    private let environment: AppEnvironment
    var state: LoadState<[CommentThread]> = .idle
    var draft = ""
    var replyTo: CommentItem?
    var sending = false
    var loading = false
    var loadingThreads: Set<Int64> = []
    var hasMore = true
    var error: String?
    private var offset = 0
    private var sendGUID = UUID().uuidString
    private var lastSubmission = ""
    private var draftKey: String
    init(postID:Int64,environment:AppEnvironment) {
        self.postID = postID; self.environment = environment
        draftKey = "vkhig.comment.draft.\(VKSession.currentUserID ?? 0).\(postID)"
        draft = UserDefaults.standard.string(forKey:draftKey) ?? ""
    }
    func saveDraft() { UserDefaults.standard.set(draft,forKey:draftKey) }
    private func item(_ j:VKJSON,names:[Int64:String]) -> CommentItem {
        let author = names[j["from_id"].int] ?? "VK \(j["from_id"].int)"
        return CommentItem(id:j["id"].int,postID:postID,author:author,initials:VKCatalogService.initials(author),text:j["text"].string,
            dateLabel:VKCatalogService.date(j["date"]),replyToID:j["reply_to_comment"].int == 0 ? nil : j["reply_to_comment"].int,authorID:j["from_id"].int,attachments:j["attachments"].chatAttachments)
    }
    private func names(_ response:VKJSON) -> [Int64:String] {
        var names=Dictionary(response["profiles"].items.map { ($0["id"].int,VKCatalogService.name($0)) },uniquingKeysWith:{a,_ in a})
        for group in response["groups"].items { names[-group["id"].int]=group["name"].string }
        return names
    }
    func load(reset:Bool = true) async {
        guard !loading else { return }; loading=true; defer { loading=false }
        if reset { offset=0;hasMore=true;if case .loaded = state {} else {state = .loading} }
        error=nil
        if !environment.isLiveVKSession {
            let items=CatalogFixtures.comments.filter {$0.postID == postID}
            let roots=items.filter {$0.replyToID == nil}
            let threads=roots.map { root in CommentThread(root:root,replies:items.filter {$0.replyToID == root.id},totalReplies:items.filter {$0.replyToID == root.id}.count) }
            state=threads.isEmpty ? .empty : .loaded(threads);hasMore=false;return
        }
        do {
            let post=try environment.catalog.post(postID)
            let response=try await environment.catalog.request("wall.getComments",["owner_id":"\(post.ownerID)","post_id":"\(post.nativeID ?? post.id)","extended":"1","count":"30","offset":"\(offset)","thread_items_count":"3","sort":"asc"])
            try Task.checkCancellation()
            let authors=names(response)
            let page=response.list.map { j in CommentThread(root:item(j,names:authors),replies:j["thread"]["items"].items.map {item($0,names:authors)},totalReplies:Int(j["thread"]["count"].int)) }
            var current:[CommentThread]=[];if !reset,case .loaded(let old)=state {current=old}
            var seen=Set(current.map(\.id));current+=page.filter {seen.insert($0.id).inserted}
            offset+=page.count;hasMore=page.count == 30
            state=current.isEmpty ? .empty : .loaded(current)
        } catch is CancellationError {return}
        catch {
            self.error=error.localizedDescription
            if case .loaded = state {} else {state = .failed(error as? AppError ?? .network(error.localizedDescription))}
        }
    }
    func loadReplies(_ thread:CommentThread) async {
        guard !loadingThreads.contains(thread.id),environment.isLiveVKSession else {return}
        loadingThreads.insert(thread.id);defer {loadingThreads.remove(thread.id)}
        do {
            let post=try environment.catalog.post(postID)
            let response=try await environment.catalog.request("wall.getComments",["owner_id":"\(post.ownerID)","post_id":"\(post.nativeID ?? post.id)","comment_id":"\(thread.id)","offset":"\(thread.replies.count)","count":"30","extended":"1"])
            let authors=names(response),page=response.list.filter {$0["id"].int != thread.id}.map {item($0,names:authors)}
            guard case .loaded(var all)=state,let index=all.firstIndex(where:{$0.id == thread.id}) else {return}
            var seen=Set(all[index].replies.map(\.id));all[index].replies+=page.filter {seen.insert($0.id).inserted}
            if page.isEmpty {all[index].totalReplies=all[index].replies.count}
            state = .loaded(all)
        } catch {self.error=error.localizedDescription}
    }
    func send() async {
        let text=draft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty,!sending else {return};sending=true;defer {sending=false}
        if !environment.isLiveVKSession {
            let local=CommentItem(id:Int64(Date().timeIntervalSince1970 * 1000),postID:postID,author:"Вы (демо)",initials:"ВЫ",text:text,dateLabel:"Сейчас",replyToID:replyTo?.id)
            var all:[CommentThread]=[];if case .loaded(let old)=state {all=old}
            if let replyTo,let i=all.firstIndex(where:{$0.id == replyTo.id || $0.replies.contains(where:{$0.id == replyTo.id})}) {all[i].replies.append(local);all[i].totalReplies+=1}
            else {all.append(CommentThread(root:local,replies:[],totalReplies:0))}
            state = .loaded(all);draft="";replyTo=nil;saveDraft();return
        }
        do {
            let submission="\(replyTo?.id ?? 0):\(text)"
            if submission != lastSubmission {sendGUID=UUID().uuidString;lastSubmission=submission}
            let post=try environment.catalog.post(postID)
            var parameters=["owner_id":"\(post.ownerID)","post_id":"\(post.nativeID ?? post.id)","message":text,"guid":sendGUID]
            if let replyTo {parameters["reply_to_comment"]="\(replyTo.id)"}
            let response=try await environment.catalog.request("wall.createComment",parameters)
            guard response["comment_id"].int > 0 || response.int > 0 else {throw AppError.decoding}
            draft="";replyTo=nil;sendGUID=UUID().uuidString;saveDraft();await load()
        } catch {self.error=error.localizedDescription}
    }
    func edit(_ comment:CommentItem,text:String) async -> Bool {
        let text=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty,!sending else {return false}
        sending=true;error=nil;defer {sending=false}
        do {
            if environment.isLiveVKSession {
                let post=try environment.catalog.post(postID)
                let response=try await environment.catalog.request("wall.editComment",["owner_id":"\(post.ownerID)","comment_id":"\(comment.id)","message":text])
                guard response.int == 1 else {throw AppError.decoding}
            }
            let updated=CommentItem(id:comment.id,postID:comment.postID,author:comment.author,initials:comment.initials,text:text,dateLabel:comment.dateLabel,replyToID:comment.replyToID,authorID:comment.authorID,attachments:comment.attachments)
            if case .loaded(var threads)=state {
                for i in threads.indices {
                    if threads[i].root.id == comment.id {threads[i].root=updated}
                    if let j=threads[i].replies.firstIndex(where:{$0.id == comment.id}) {threads[i].replies[j]=updated}
                }
                state = .loaded(threads)
            }
            return true
        } catch {self.error=error.localizedDescription;return false}
    }
    func remove(_ comment:CommentItem) async {
        do {
            if environment.isLiveVKSession {
                let post=try environment.catalog.post(postID)
                let response=try await environment.catalog.request("wall.deleteComment",["owner_id":"\(post.ownerID)","comment_id":"\(comment.id)"])
                guard response.int == 1 else {throw AppError.decoding}
            }
            if case .loaded(var all)=state {
                all.removeAll {$0.id == comment.id}
                for i in all.indices {
                    let removed=all[i].replies.filter {$0.id == comment.id}.count
                    all[i].replies.removeAll {$0.id == comment.id}
                    all[i].totalReplies=max(0,all[i].totalReplies-removed)
                }
                state=all.isEmpty ? .empty : .loaded(all)
            }
        } catch {self.error=error.localizedDescription}
    }
}

struct CommentsView:View {
    let postID:Int64
    @Environment(AppEnvironment.self) private var env
    @State private var model:CommentsViewModel?
    @State private var deleting:CommentItem?
    @State private var editing:CommentItem?
    @State private var editedText=""
    var body:some View {
        Group {
            if let model {content(model)} else {ProgressView()}
        }.navigationTitle("Комментарии")
        .task {if model == nil {let vm=CommentsViewModel(postID:postID,environment:env);model=vm;await vm.load()}}
        .sheet(item:$editing) {comment in
            NavigationStack {
                Form {
                    TextField("Комментарий",text:$editedText,axis:.vertical).lineLimit(3...12)
                    if let error=model?.error {Text(error).foregroundStyle(.red)}
                }.navigationTitle("Изменить комментарий")
                .interactiveDismissDisabled(model?.sending == true)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) {Button("Отмена") {editing=nil}.disabled(model?.sending == true)}
                    ToolbarItem(placement:.confirmationAction) {
                        Button("Сохранить") {Task {if await model?.edit(comment,text:editedText) == true {editing=nil}}}.disabled(model?.sending == true || editedText.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .confirmationDialog("Удалить комментарий?",isPresented:Binding(get:{deleting != nil},set:{if !$0 {deleting=nil}})) {
            Button("Удалить",role:.destructive) {if let comment=deleting {Task {await model?.remove(comment)}};deleting=nil}
        }
    }
    @ViewBuilder private func content(_ model:CommentsViewModel) -> some View {
        @Bindable var model=model
        LoadableContainer(state:model.state,titleForEmpty:"Нет комментариев",emptySymbol:"text.bubble",emptyDetails:"Оставьте первый комментарий.",onRetry:{Task {await model.load()}}) {threads in
            List {
                if !env.isLiveVKSession {FixtureBanner()}
                ForEach(threads) {thread in
                    Section {
                        row(thread.root,model:model)
                        ForEach(thread.replies) {reply in row(reply,model:model).padding(.leading,24)}
                        if thread.replies.count < thread.totalReplies {
                            Button("Показать ответы (\(thread.totalReplies - thread.replies.count))") {Task {await model.loadReplies(thread)}}.disabled(model.loadingThreads.contains(thread.id)).frame(minHeight:44)
                        }
                    }
                }
                if model.hasMore {Button("Загрузить ещё комментарии") {Task {await model.load(reset:false)}}.disabled(model.loading).frame(minHeight:44)}
            }.listStyle(.plain).refreshable {await model.load()}
        }
        .safeAreaInset(edge:.bottom) {
            VStack(alignment:.leading,spacing:8) {
                if let reply=model.replyTo {HStack {Text("Ответ: \(reply.author)").font(.caption);Spacer();Button("Отмена") {model.replyTo=nil}}}
                if let error=model.error {Text(error).font(.caption).foregroundStyle(.red)}
                HStack {
                    TextField("Комментарий",text:$model.draft,axis:.vertical).lineLimit(1...5).textFieldStyle(.roundedBorder).onChange(of:model.draft) {_,_ in model.saveDraft()}
                    Button {Task {await model.send()}} label:{Image(systemName:"arrow.up.circle.fill").font(.title).frame(width:44,height:44)}.disabled(model.sending || model.draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityLabel("Отправить комментарий")
                }
            }.padding(12).background(.regularMaterial)
        }
    }
    private func row(_ comment:CommentItem,model:CommentsViewModel) -> some View {
        HStack(alignment:.top,spacing:10) {
            VKAvatar(initials:comment.initials,size:36,tint:.indigo)
            VStack(alignment:.leading,spacing:5) {
                Text(comment.author).font(.headline)
                Text(comment.text)
                ForEach(comment.attachments) {AttachmentPreview(attachment:$0)}
                HStack {Text(comment.dateLabel).foregroundStyle(.secondary);Button("Ответить") {model.replyTo=comment}.frame(minHeight:44)}.font(.caption)
            }
        }.padding(.vertical,4).contextMenu {
            Button("Копировать") {UIPasteboard.general.string=comment.text}
            Button("Ответить") {model.replyTo=comment}
            if !env.isLiveVKSession || comment.authorID == VKSession.currentUserID {
                Button("Изменить") {editedText=comment.text;editing=comment;model.error=nil}
                Button("Удалить",role:.destructive) {deleting=comment}
            }
        }
    }
}
