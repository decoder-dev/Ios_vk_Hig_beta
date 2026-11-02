import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct MusicArtwork:View {
    let track:LocalAudioTrack?
    var large=false
    var body:some View {
        Group {
            if let url=track?.artworkURL {AsyncImage(url:url) {image in image.resizable().scaledToFill()} placeholder:{placeholder}}
            else {placeholder}
        }.aspectRatio(1,contentMode:.fit).clipped().clipShape(RoundedRectangle(cornerRadius:large ? 22 : 8))
    }
    private var placeholder:some View {
        RoundedRectangle(cornerRadius:large ? 22 : 8).fill(.quaternary)
            .overlay {Image(systemName:"music.note").font(large ? .system(size:72) : .body).foregroundStyle(.secondary)}
    }
}
struct MusicTrackLabel:View {
    let track:LocalAudioTrack
    var body:some View {
        HStack(spacing:12) {
            MusicArtwork(track:track).frame(width:46,height:46).accessibilityHidden(true)
            VStack(alignment:.leading,spacing:3) {
                Text(track.title).font(.body).lineLimit(2)
                Text(track.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength:4)
            if let duration=track.duration,duration>0 {Text(MusicPolicy.time(duration)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)}
        }.frame(minHeight:48).contentShape(Rectangle())
    }
}
struct MusicLibraryView:View {
    @Environment(AppEnvironment.self) private var env
    @State private var library=AudioLibrary.shared
    @State private var query=""
    @State private var importing=false
    @State private var newPlaylist=false
    @State private var playlistName=""
    @State private var deleting:[LocalAudioTrack]=[]
    private var filtered:[LocalAudioTrack] {
        library.visibleTracks.filter {query.isEmpty || ($0.title+" "+($0.artist ?? "")).localizedCaseInsensitiveContains(query)}
    }
    var body:some View {
        List {
            Section("Медиатека на устройстве") {
                Button("Добавить из Файлов",systemImage:"plus") {importing=true}.disabled(library.importing)
                if library.importing {ProgressView("Импорт аудиофайлов…")}
                NavigationLink("Открыть плеер",value:AppRoute.audioPlayer)
                NavigationLink {MusicQueueView()} label:{Label("Очередь",systemImage:"list.bullet")}
                NavigationLink {MusicEqualizerView()} label:{Label("Эквалайзер",systemImage:"slider.horizontal.3")}
            }
            Section("Плейлисты на устройстве") {
                Button("Новый плейлист",systemImage:"plus") {newPlaylist=true}
                ForEach(library.visiblePlaylists) {playlist in
                    NavigationLink {MusicPlaylistDetail(playlistID:playlist.id)} label:{
                        Label {VStack(alignment:.leading) {Text(playlist.title);Text("\(library.playlistTracks(playlist).count) треков").font(.caption).foregroundStyle(.secondary)}} icon:{Image(systemName:"music.note.list")}
                    }.accessibilityIdentifier("music-playlist-"+playlist.id)
                }
            }
            Section("Мои аудиофайлы") {
                ForEach(filtered.filter {$0.accountID==nil}) {track in trackRow(track)}
                if library.visibleTracks.isEmpty && !library.importing {ContentUnavailableView("Добавьте свою музыку",systemImage:"music.note",description:Text("Импортируйте аудиофайлы или откройте доступный каталог VK."))}
            }
            if !filtered.filter({$0.accountID != nil}).isEmpty {
                Section {
                    ForEach(filtered.filter {$0.accountID != nil}) {track in trackRow(track)}
                } header:{Text("Скачано из VK")} footer:{Text("\(ByteCountFormatter.string(fromByteCount:library.cacheBytes,countStyle:.file)) из 500 МБ. Доступно без сети для этого аккаунта.")}
            }
            if !query.isEmpty && filtered.isEmpty {Text("В локальной медиатеке ничего не найдено").foregroundStyle(.secondary)}
            if env.capabilities.canUseLiveAPI(.music) {VKMusicCatalogSection(query:query)}
            else {
                Section("VK Музыка") {
                    Link("Открыть каталог VK",destination:URL(string:"https://vk.com/music")!)
                    Text("Онлайн-каталог доступен после выдачи музыкальных прав VK. Локальные файлы работают без входа.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let error=library.error {Section {Text(error).foregroundStyle(.red);Button("Скрыть сообщение") {library.error=nil}}}
        }.navigationTitle("Музыка").withAppRoutes()
        .searchable(text:$query,prompt:"Треки и исполнители")
        .fileImporter(isPresented:$importing,allowedContentTypes:[.audio],allowsMultipleSelection:true) {result in
            switch result {case .success(let urls):Task {await library.importFiles(urls)};case .failure(let error):library.error=error.localizedDescription}
        }
        .alert("Новый плейлист",isPresented:$newPlaylist) {
            TextField("Название",text:$playlistName)
            Button("Создать") {library.createPlaylist(playlistName);playlistName=""}
            Button("Отмена",role:.cancel) {}
        }
        .confirmationDialog("Удалить выбранный аудиофайл с устройства?",isPresented:Binding(get:{!deleting.isEmpty},set:{if !$0 {deleting=[]}})) {
            Button("Удалить файл",role:.destructive) {for track in deleting {library.remove(track)};deleting=[]}
        }
    }
    private func trackRow(_ track:LocalAudioTrack) -> some View {
        Button {library.play(track)} label:{MusicTrackLabel(track:track)}.buttonStyle(.plain)
            .contextMenu {
                Button("Воспроизвести следующим") {library.enqueue(track,next:true)}
                Button("Добавить в конец очереди") {library.enqueue(track)}
                Menu("В плейлист") {
                    ForEach(library.visiblePlaylists) {playlist in Button(playlist.title) {library.add(track,to:playlist)}}
                }
                ShareLink(item:track.url) {Label("Поделиться файлом",systemImage:"square.and.arrow.up")}
                Button("Удалить с устройства",role:.destructive) {deleting=[track]}
            }
    }
}
struct VKMusicCatalogSection:View {
    var query:String=""
    @Environment(AppEnvironment.self) private var env
    @State private var model=VKMusicCatalogModel()
    @State private var library=AudioLibrary.shared
    var body:some View {
        Section {
            ForEach(model.tracks.filter {query.isEmpty || ($0.title+" "+$0.artist).localizedCaseInsensitiveContains(query)}) {track in
                HStack {
                    Button {
                        if let item=track.local {library.playRemote(item,queue:model.tracks.compactMap(\.local))}
                    } label:{
                        VStack(alignment:.leading,spacing:4) {
                            Text(track.title).foregroundStyle(.primary)
                            Text(track.artist).font(.caption).foregroundStyle(.secondary)
                            if track.url==nil {Text("VK не предоставил поток").font(.caption).foregroundStyle(.secondary)}
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }.buttonStyle(.plain).disabled(track.url==nil)
                    if library.downloading.contains(track.id) {
                        Button {library.cancelDownload(track.id)} label:{ProgressView()}.accessibilityLabel("Отменить загрузку "+track.title)
                    } else {
                        Button {library.download(track)} label:{Image(systemName:library.cached(track) ? "checkmark.circle.fill" : "arrow.down.circle").frame(minWidth:44,minHeight:44)}
                            .buttonStyle(.borderless).disabled(track.url==nil || library.cached(track)).accessibilityLabel("Скачать "+track.title)
                    }
                }
            }
            if model.loading {ProgressView("Загрузка VK…")}
            if let error=model.error {Text(error).foregroundStyle(.red);Button("Повторить каталог") {Task {await model.load(grants:env.capabilities.grantedScopes)}}}
            if !model.loading && model.error==nil && model.tracks.isEmpty {Text("VK не вернул аудиозаписи")}
            if model.more && !model.loading {Button("Загрузить ещё треки VK") {Task {await model.load(reset:false,grants:env.capabilities.grantedScopes)}}}
        } header:{Text("Моя музыка VK")} footer:{
            if !query.isEmpty {Text("Поиск по загруженным страницам каталога. Для остальных треков загрузите следующую страницу.")}
        }
        .task {await model.load(grants:env.capabilities.grantedScopes)}
    }
}
struct AudioPlayerView:View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var library=AudioLibrary.shared
    @State private var scrub=0.0
    @State private var scrubbing=false
    var body:some View {
        ScrollView {
            VStack(spacing:22) {
                MusicArtwork(track:library.current,large:true).frame(maxWidth:300).padding(.top,12)
                VStack(spacing:6) {
                    Text(library.current?.title ?? "Выберите аудиофайл").font(.title2.bold()).multilineTextAlignment(.center)
                    Text(library.current?.subtitle ?? "Добавьте музыку в медиатеку").foregroundStyle(.secondary)
                }
                VStack(spacing:6) {
                    Slider(value:$scrub,in:0...max(1,library.duration),onEditingChanged:{editing in scrubbing=editing;if !editing {library.seek(scrub)}})
                        .disabled(library.current==nil || library.duration<=0).accessibilityLabel("Позиция воспроизведения")
                    HStack {Text(MusicPolicy.time(scrubbing ? scrub : library.elapsed));Spacer();Text(MusicPolicy.time(library.duration))}
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                HStack(spacing:32) {
                    Button {library.previous()} label:{Image(systemName:"backward.fill").font(.system(size:24)).frame(width:48,height:48)}.accessibilityLabel("Предыдущий трек")
                    Button {if library.playing {library.pause()} else {library.resume()}} label:{
                        Group {if library.buffering {ProgressView()} else {Image(systemName:library.playing ? "pause.fill" : "play.fill").font(.system(size:34))}}
                            .frame(width:64,height:64)
                    }.accessibilityLabel(library.playing ? "Пауза" : "Воспроизвести")
                    Button {library.next()} label:{Image(systemName:"forward.fill").font(.system(size:24)).frame(width:48,height:48)}.accessibilityLabel("Следующий трек")
                }.disabled(library.current==nil)
                HStack(spacing:30) {
                    Button {library.setShuffle(!library.shuffle)} label:{Image(systemName:"shuffle").foregroundStyle(library.shuffle ? Color.accentColor : Color.secondary).frame(width:44,height:44)}
                        .accessibilityLabel("Перемешивание").accessibilityValue(library.shuffle ? "Включено" : "Выключено")
                    AudioRoutePicker().frame(width:44,height:44).accessibilityLabel("AirPlay")
                    Button {library.repeatOne.toggle()} label:{Image(systemName:"repeat.1").foregroundStyle(library.repeatOne ? Color.accentColor : Color.secondary).frame(width:44,height:44)}
                        .accessibilityLabel("Повтор трека").accessibilityValue(library.repeatOne ? "Включён" : "Выключен")
                }
                playerLinks
                if let error=library.error {Text(error).font(.footnote).foregroundStyle(.red);Button("Повторить воспроизведение") {library.retryPlayback()}.disabled(library.current==nil)}
            }.padding(20).frame(maxWidth:560).frame(maxWidth:.infinity)
        }.navigationTitle("Плеер").navigationBarTitleDisplayMode(.inline)
        .onAppear {library.playerPresented=true;scrub=library.elapsed}
        .onDisappear {library.playerPresented=false}
        .onChange(of:library.elapsed) {_,value in if !scrubbing {scrub=min(max(1,library.duration),value)}}
    }
    @ViewBuilder private var playerLinks:some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment:.leading,spacing:16) {
                NavigationLink {MusicQueueView()} label:{Label("Очередь",systemImage:"list.bullet").frame(minHeight:44)}
                NavigationLink {MusicLyricsView()} label:{Label("Текст",systemImage:"quote.bubble").frame(minHeight:44)}
                NavigationLink {MusicEqualizerView()} label:{Label("Эквалайзер",systemImage:"slider.horizontal.3").frame(minHeight:44)}
            }.frame(maxWidth:.infinity,alignment:.leading)
        } else {
            HStack {
                NavigationLink {MusicQueueView()} label:{Label("Очередь",systemImage:"list.bullet")}
                Spacer()
                NavigationLink {MusicLyricsView()} label:{Label("Текст",systemImage:"quote.bubble")}
                Spacer()
                NavigationLink {MusicEqualizerView()} label:{Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("Эквалайзер")
            }.font(.subheadline)
        }
    }
}
struct AudioRoutePicker:UIViewRepresentable {
    func makeUIView(context:Context) -> AVRoutePickerView {AVRoutePickerView()}
    func updateUIView(_ view:AVRoutePickerView,context:Context) {}
}
struct MusicQueueView:View {
    @State private var library=AudioLibrary.shared
    @State private var clearing=false
    var body:some View {
        List {
            if let track=library.current {Section("Сейчас") {MusicTrackLabel(track:track)}}
            Section("Далее") {
                ForEach(Array(library.upcoming.enumerated()),id:\.element.id) {entry in
                    Button {library.selectQueue(library.queueIndex+entry.offset+1)} label:{MusicTrackLabel(track:entry.element)}.buttonStyle(.plain)
                }.onMove {library.moveUpcoming($0,to:$1)}.onDelete {library.removeUpcoming($0)}
                if library.upcoming.isEmpty {Text("Следующих треков нет").foregroundStyle(.secondary)}
            }
        }.navigationTitle("Очередь")
        .toolbar {
            ToolbarItem(placement:.topBarTrailing) {EditButton()}
            ToolbarItem(placement:.bottomBar) {Button("Очистить следующие",role:.destructive) {clearing=true}.disabled(library.upcoming.isEmpty)}
        }
        .confirmationDialog("Убрать следующие треки из очереди?",isPresented:$clearing) {Button("Очистить очередь",role:.destructive) {library.clearUpcoming()}}
    }
}
struct MusicPlaylistDetail:View {
    let playlistID:String
    @State private var library=AudioLibrary.shared
    @State private var adding=false
    @State private var deleting=false
    @Environment(\.dismiss) private var dismiss
    private var playlist:MusicPlaylist? {library.visiblePlaylists.first {$0.id==playlistID}}
    var body:some View {
        List {
            if let playlist {
                let items=library.playlistTracks(playlist)
                Button("Воспроизвести всё",systemImage:"play.fill") {if let first=items.first {library.playQueue(items,startingAt:first.id)}}.disabled(items.isEmpty)
                Button("Добавить треки",systemImage:"plus") {adding=true}
                ForEach(items) {track in Button {library.playQueue(items,startingAt:track.id)} label:{MusicTrackLabel(track:track)}.buttonStyle(.plain)}
                    .onDelete {library.removePlaylistTracks(playlist,offsets:$0)}
                if items.isEmpty {Text("Добавьте треки из медиатеки")}
                Button("Удалить плейлист",role:.destructive) {deleting=true}
            }
        }.navigationTitle(playlist?.title ?? "Плейлист")
        .sheet(isPresented:$adding) {
            NavigationStack {
                List(library.visibleTracks) {track in
                    Button {if let playlist {library.add(track,to:playlist)}} label:{
                        HStack {MusicTrackLabel(track:track);if playlist?.trackIDs.contains(track.id)==true {Image(systemName:"checkmark")}}
                    }.buttonStyle(.plain)
                }.navigationTitle("Добавить треки")
                .toolbar {ToolbarItem(placement:.confirmationAction) {Button("Готово") {adding=false}}}
            }
        }
        .confirmationDialog("Удалить плейлист? Аудиофайлы останутся.",isPresented:$deleting) {
            Button("Удалить плейлист",role:.destructive) {if let playlist {library.removePlaylist(playlist)};dismiss()}
        }
    }
}
struct MusicEqualizerView:View {
    @State private var library=AudioLibrary.shared
    var body:some View {
        Form {
            Section {
                Toggle("Эквалайзер",isOn:Binding(get:{library.equalizerSettings.enabled},set:{value in var settings=library.equalizerSettings;settings.enabled=value;library.setEqualizer(settings)}))
                    .disabled(!library.canEqualize && !library.equalizerSettings.enabled)
                Text("Работает с локальными и скачанными аудиофайлами на iPhone. Для онлайн-потоков и AirPlay используется обычный плеер.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Предустановки") {
                ForEach(["Ровно","Бас","Голос"],id:\.self) {name in
                    Button(name) {var value=MusicEQSettings.preset(name);value.enabled=library.canEqualize;library.setEqualizer(value)}
                }
            }
            Section("10 полос") {
                ForEach(0..<10,id:\.self) {index in
                    VStack(alignment:.leading,spacing:4) {
                        HStack {Text(frequency(index));Spacer();Text(String(format:"%+.0f дБ",library.equalizerSettings.normalized.gains[index]))}.font(.caption.monospacedDigit())
                        Slider(value:Binding(get:{Double(library.equalizerSettings.normalized.gains[index])},set:{value in var settings=library.equalizerSettings.normalized;settings.gains[index]=Float(value);library.setEqualizer(settings)}),in:-12...12,step:1).accessibilityLabel(frequency(index))
                    }
                }
            }
            if let error=library.error {Text(error).foregroundStyle(.red).accessibilityIdentifier("music-error")}
        }.navigationTitle("Эквалайзер")
    }
    private func frequency(_ index:Int) -> String {
        let value=Int(MusicEQSettings.frequencies[index])
        return value>=1000 ? String(format:"%.0f кГц",Double(value)/1000) : "\(value) Гц"
    }
}
struct MusicLyricsView:View {
    @State private var library=AudioLibrary.shared
    @State private var lyrics:MusicLyrics?
    @State private var loading=false
    @State private var message:String?
    @State private var importing=false
    @State private var follow=true
    @State private var lookup:Task<Void,Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var active:Int? {lyrics?.activeIndex(at:library.elapsed)}
    var body:some View {
        VStack(spacing:0) {
            if let track=library.current {
                VStack(spacing:6) {
                    Text(track.title).font(.headline).lineLimit(2)
                    HStack {
                        Button("Импорт LRC") {importing=true}
                        Spacer()
                        Button("Найти в LRCLIB") {find(track)}.disabled(loading || track.artist?.isEmpty != false)
                    }.font(.subheadline)
                    Text("По кнопке поиска в LRCLIB отправляются название и исполнитель.").font(.caption).foregroundStyle(.secondary)
                    if loading {ProgressView()}
                    if let message {Text(message).font(.caption).foregroundStyle(.red)}
                }.padding()
                lyricsContent
                if !follow {Button("К текущей строке") {follow=true}.padding(.bottom,12)}
            } else {ContentUnavailableView("Нет выбранного трека",systemImage:"music.note")}
        }.navigationTitle("Текст песни")
        .task(id:library.currentID) {
            lookup?.cancel();loading=false;message=nil;follow=true
            lyrics=library.current.flatMap {library.lyrics(for:$0)}
        }
        .onDisappear {lookup?.cancel()}
        .fileImporter(isPresented:$importing,allowedContentTypes:[.plainText,.data]) {result in
            do {
                let url=try result.get(),scope=url.startAccessingSecurityScopedResource();defer {if scope {url.stopAccessingSecurityScopedResource()}}
                guard let track=library.current,(try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=2_000_000 else {throw AppError.network("Файл текста должен быть меньше 2 МБ.")}
                let data=try Data(contentsOf:url)
                guard let text=String(data:data,encoding:.utf8) ?? String(data:data,encoding:.utf16) else {throw AppError.decoding}
                let parsed=MusicLyrics.parse(text);lyrics=parsed;library.saveLyrics(parsed,for:track);message=nil
            } catch {message=error.localizedDescription}
        }
    }
    @ViewBuilder private var lyricsContent:some View {
        if let lyrics {
            if lyrics.lines.isEmpty {ScrollView {Text(lyrics.text).frame(maxWidth:.infinity,alignment:.leading).padding().textSelection(.enabled)}}
            else {
                ScrollViewReader {proxy in
                    ScrollView {
                        LazyVStack(alignment:.leading,spacing:22) {
                            ForEach(Array(lyrics.lines.enumerated()),id:\.element.id) {entry in
                                Button {library.seek(entry.element.time)} label:{
                                    Text(entry.element.text).font(.title2.weight(entry.offset==active ? .bold : .medium))
                                        .foregroundStyle(entry.offset==active ? Color.primary : Color.secondary)
                                        .frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,6)
                                }.buttonStyle(.plain).id(entry.offset)
                            }
                        }.padding()
                    }.simultaneousGesture(DragGesture().onChanged {_ in follow=false})
                    .onChange(of:active) {_,index in if follow,let index {withAnimation(reduceMotion ? nil : .easeInOut(duration:0.2)) {proxy.scrollTo(index,anchor:.center)}}}
                    .onChange(of:follow) {_,value in if value,let active {proxy.scrollTo(active,anchor:.center)}}
                }
            }
        } else if !loading {ContentUnavailableView("Текст не добавлен",systemImage:"quote.bubble",description:Text("Импортируйте LRC или найдите текст в LRCLIB."))}
    }
    private func find(_ track:LocalAudioTrack) {
        lookup?.cancel();loading=true;message=nil
        let duration=library.duration
        lookup=Task {
            defer {if library.currentID==track.id {loading=false}}
            do {
                let result=try await MusicLyricsLookup.fetch(track:track,duration:duration)
                try Task.checkCancellation();guard library.currentID==track.id else {return}
                lyrics=result;library.saveLyrics(result,for:track)
            } catch is CancellationError {} catch {if library.currentID==track.id {message=error.localizedDescription}}
        }
    }
}
struct MusicMiniPlayer:View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let open:()->Void
    @State private var library=AudioLibrary.shared
    var body:some View {
        HStack(spacing:12) {
            Button(action:open) {
                HStack(spacing:10) {
                    MusicArtwork(track:library.current).frame(width:38,height:38)
                    VStack(alignment:.leading) {
                        Text(library.current?.title ?? "").font(.subheadline.weight(.semibold)).lineLimit(1)
                        if !typeSize.isAccessibilitySize {Text(library.current?.subtitle ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)}
                    }
                    Spacer(minLength:0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Открыть плеер").accessibilityIdentifier("music-mini-player-open")
            Button {if library.playing {library.pause()} else {library.resume()}} label:{Image(systemName:library.playing ? "pause.fill" : "play.fill").frame(width:44,height:44)}.accessibilityLabel(library.playing ? "Пауза" : "Воспроизвести")
            Button {library.next()} label:{Image(systemName:"forward.fill").frame(width:44,height:44)}.accessibilityLabel("Следующий трек")
        }.padding(.horizontal,14).padding(.vertical,5)
        // The system accessory has a fixed height. The complete player remains unbounded.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
struct MusicMiniPlayerModifier:ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var library=AudioLibrary.shared
    @State private var presented=false
    private var visible:Bool {library.current != nil && !library.playerPresented}
    @ViewBuilder func body(content:Content) -> some View {
        adapted(content).sheet(isPresented:$presented) {
            NavigationStack {AudioPlayerView().toolbar {ToolbarItem(placement:.cancellationAction) {Button("Закрыть") {presented=false}}}}.dynamicTypeSize(typeSize)
        }
    }
    @ViewBuilder private func adapted(_ content:Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 27.0,*) {
            content.tabViewBottomAccessory(isEnabled:visible) {MusicMiniPlayer {presented=true}}
        } else {legacy(content)}
        #else
        legacy(content)
        #endif
    }
    private func legacy(_ content:Content) -> some View {
        content.safeAreaInset(edge:.bottom) {if visible {MusicMiniPlayer {presented=true}.background(.regularMaterial)}}
    }
}
