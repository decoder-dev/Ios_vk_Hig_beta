import SwiftUI
import AVKit
import SafariServices
import MediaPlayer
import Observation
import UniformTypeIdentifiers

/// S26 — photo albums.
struct PhotoAlbumsView: View {
    var body: some View {
        FixtureScreen(
            title: "Альбомы",
            screenID: "S26",
            emptyTitle: "Нет альбомов",
            emptySymbol: "rectangle.stack",
            emptyDetails: "photos.getAlbums when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.albums }
        ) { albums in
            List(albums) { album in
                NavigationLink(value: AppRoute.albumPhotos(album.id)) {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VKStyle.cell)
                            .frame(width: 56, height: 56)
                            .overlay { Image(systemName: "photo") }
                        VStack(alignment: .leading) {
                            Text(album.title)
                            Text("\(album.count) фото").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .withAppRoutes()
        }
    }
}

/// S27 — photos grid.
struct PhotosGridView: View {
    var albumID: Int64? = nil
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        FixtureScreen(
            title: "Фотографии",
            screenID: "S27",
            resourceID:albumID,
            emptyTitle: "Нет фотографий",
            emptySymbol: "photo",
            emptyDetails: "photos.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.photos }
        ) { photos in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(photos) { photo in
                        NavigationLink(value: AppRoute.photoViewer(photo.id)) {
                            AsyncImage(url:photo.url) { image in image.resizable().scaledToFill() } placeholder: { Rectangle().fill(VKStyle.cell).overlay { Image(systemName:"photo") } }
                                .frame(height:110).clipped().accessibilityLabel(photo.caption.isEmpty ? "Фотография" : photo.caption)
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                    }
                }
                .padding(4)
            }
            .withAppRoutes()
        }
    }
}

/// S28 — photo viewer.
struct PhotoViewerView: View {
    let photoID: Int64
    @Environment(AppEnvironment.self) private var env
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url:env.catalog.photos[photoID]?.url) { image in image.resizable().scaledToFit() } placeholder: {
                VStack { Image(systemName:"photo"); Text(env.isLiveVKSession ? "Фотография недоступна" : "Демонстрационный просмотр") }.foregroundStyle(.white)
            }
            .scaleEffect(scale)
            .gesture(MagnifyGesture().onChanged { scale = min(5,max(1,$0.magnification)) })
            .onTapGesture(count:2) { scale = scale == 1 ? 2 : 1 }
        }
        .navigationTitle("Фото")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = env.catalog.photos[photoID]?.url { ShareLink(item:url) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(minWidth: 44, minHeight: 44)
                } }
            }
        }
    }
}

/// S29 — video list.
struct VideoListView: View {
    var body: some View {
        FixtureScreen(
            title: "Видео",
            screenID: "S29",
            emptyTitle: "Нет видео",
            emptySymbol: "play.rectangle",
            emptyDetails: "video.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.videos }
        ) { videos in
            List(videos) { video in
                NavigationLink(value: AppRoute.videoPlayer(video.id)) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VKStyle.cell)
                            .frame(width: 96, height: 56)
                            .overlay { Image(systemName: "play.fill") }
                        VStack(alignment: .leading) {
                            Text(video.title)
                            Text("\(video.author) · \(video.durationLabel)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .withAppRoutes()
        }
    }
}

/// S30 — video player stub (no illegal stream).
struct VideoPlayerView: View {
    let videoID: Int64
    @Environment(AppEnvironment.self) private var env
    @State private var player: AVPlayer?
    @State private var showOfficialPlayer = false
    var body: some View {
        Group {
            if let player { VideoPlayer(player:player).onDisappear { player.pause() } }
            else if let url = env.catalog.videos[videoID]?.playerURL {
                VStack(spacing:20) {
                    Label("Просмотр видео",systemImage:"play.rectangle").font(.title2)
                    Button("Открыть официальный плеер VK") { showOfficialPlayer = true }.buttonStyle(.borderedProminent)
                }.sheet(isPresented:$showOfficialPlayer) { OfficialWebPlayer(url:url) }
            } else { ContentUnavailableView("Видео недоступно",systemImage:"play.slash",description:Text("VK не предоставил ссылку для воспроизведения.")) }
        }
        .navigationTitle("Видео")
        .task { if let url = env.catalog.videos[videoID]?.streamURL { player = AVPlayer(url:url) } }
    }
}
struct OfficialWebPlayer: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context:Context) -> SFSafariViewController { SFSafariViewController(url:url) }
    func updateUIViewController(_ controller:SFSafariViewController,context:Context) {}
}

struct LocalAudioTrack: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var url: URL
}

@MainActor
@Observable
final class AudioLibrary {
    static let shared = AudioLibrary()
    var tracks: [LocalAudioTrack] = []
    var currentID: String?
    var playing = false
    var elapsed = 0.0
    var duration = 0.0
    var shuffle = false
    var repeatOne = false
    var error: String?
    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var itemStatus:NSKeyValueObservation?
    @ObservationIgnored private var interruption:NSObjectProtocol?
    @ObservationIgnored private var routeChange:NSObjectProtocol?
    @ObservationIgnored private var timer: Any?
    @ObservationIgnored private var ended: NSObjectProtocol?
    @ObservationIgnored private var failed: NSObjectProtocol?
    private var directory: URL { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("AudioLibrary",isDirectory:true) }
    var current: LocalAudioTrack? { tracks.first {$0.id == currentID} }
    private init() {
        tracks = (try? JSONDecoder().decode([LocalAudioTrack].self,from:Data(contentsOf:directory.appendingPathComponent("index.json")))) ?? []
        timer = player.addPeriodicTimeObserver(forInterval:CMTime(seconds:0.5,preferredTimescale:600),queue:.main) { [weak self] time in
            Task { @MainActor in
                guard let self else {return}
                self.elapsed = max(0,time.seconds.isFinite ? time.seconds : 0)
                let length = self.player.currentItem?.duration.seconds ?? 0
                self.duration = length.isFinite ? max(0,length) : 0
                self.playing = self.player.rate > 0
                self.updateNowPlaying()
            }
        }
        ended = NotificationCenter.default.addObserver(forName:.AVPlayerItemDidPlayToEndTime,object:nil,queue:.main) { [weak self] note in
            Task { @MainActor in guard let self,let item=note.object as? AVPlayerItem,item === self.player.currentItem else {return};if self.repeatOne {self.seek(0);self.player.play()} else {self.next()} }
        }
        failed = NotificationCenter.default.addObserver(forName:.AVPlayerItemFailedToPlayToEndTime,object:nil,queue:.main) { [weak self] note in
            Task { @MainActor in guard let self,let item=note.object as? AVPlayerItem,item === self.player.currentItem else {return};self.error="Не удалось воспроизвести аудиофайл.";self.playing=false }
        }
        interruption=NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) { [weak self] _ in
            Task {@MainActor in self?.pause()}
        }
        routeChange=NotificationCenter.default.addObserver(forName:AVAudioSession.routeChangeNotification,object:nil,queue:.main) { [weak self] note in
            let reason=note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason==AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {Task {@MainActor in self?.pause()}}
        }
        let commands=MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in Task {@MainActor in self?.resume()};return .success }
        commands.pauseCommand.addTarget { [weak self] _ in Task {@MainActor in self?.pause()};return .success }
        commands.nextTrackCommand.addTarget { [weak self] _ in Task {@MainActor in self?.next()};return .success }
        commands.previousTrackCommand.addTarget { [weak self] _ in Task {@MainActor in self?.previous()};return .success }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event=event as? MPChangePlaybackPositionCommandEvent else {return .commandFailed}
            let position=event.positionTime;Task {@MainActor in self?.seek(position)};return .success
        }
    }
    func importFiles(_ urls:[URL]) {
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            for url in urls {
                let access=url.startAccessingSecurityScopedResource();defer {if access {url.stopAccessingSecurityScopedResource()}}
                let id=UUID().uuidString,destination=directory.appendingPathComponent(id).appendingPathExtension(url.pathExtension)
                try FileManager.default.copyItem(at:url,to:destination)
                tracks.append(LocalAudioTrack(id:id,title:url.deletingPathExtension().lastPathComponent,url:destination))
            }
            try JSONEncoder().encode(tracks).write(to:directory.appendingPathComponent("index.json"),options:.atomic)
        } catch {self.error=error.localizedDescription}
    }
    func remove(at offsets:IndexSet) {
        for index in offsets {
            let track=tracks[index]
            if track.id == currentID {pause();player.replaceCurrentItem(with:nil);currentID=nil;elapsed=0;duration=0;MPNowPlayingInfoCenter.default().nowPlayingInfo=nil}
            try? FileManager.default.removeItem(at:track.url)
        }
        tracks.remove(atOffsets:offsets)
        do {try JSONEncoder().encode(tracks).write(to:directory.appendingPathComponent("index.json"),options:.atomic)} catch {self.error=error.localizedDescription}
    }
    func play(_ track:LocalAudioTrack) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,mode:.default)
            try AVAudioSession.sharedInstance().setActive(true)
            currentID=track.id;elapsed=0;duration=0;error=nil
            let item=AVPlayerItem(url:track.url)
            itemStatus=item.observe(\.status,options:[.new]) { [weak self] observed,_ in
                guard observed.status == .failed else {return}
                Task {@MainActor in self?.error="Аудиофайл недоступен или его формат не поддерживается";self?.pause()}
            }
            player.replaceCurrentItem(with:item);resume()
        } catch {self.error=error.localizedDescription}
    }
    func resume() {
        guard current != nil else {return}
        do {try AVAudioSession.sharedInstance().setActive(true);player.play();playing=true;updateNowPlaying()}
        catch {self.error=error.localizedDescription}
    }
    func pause() {player.pause();playing=false;updateNowPlaying()}
    func seek(_ value:Double) {player.seek(to:CMTime(seconds:max(0,value),preferredTimescale:600));elapsed=max(0,value)}
    func next() {
        guard !tracks.isEmpty else {return}
        if shuffle {play(tracks.filter {$0.id != currentID}.randomElement() ?? tracks[0]);return}
        let index=tracks.firstIndex {$0.id == currentID} ?? -1
        if index+1 < tracks.count {play(tracks[index+1])} else {pause();seek(0)}
    }
    func previous() {guard !tracks.isEmpty else {return};if elapsed > 3 {seek(0);return};play(tracks[max(0,(tracks.firstIndex {$0.id == currentID} ?? 0)-1)])}
    private func updateNowPlaying() {
        guard let current else {return}
        MPNowPlayingInfoCenter.default().nowPlayingInfo=[MPMediaItemPropertyTitle:current.title,MPMediaItemPropertyPlaybackDuration:duration,MPNowPlayingInfoPropertyElapsedPlaybackTime:elapsed,MPNowPlayingInfoPropertyPlaybackRate:playing ? 1.0 : 0.0]
    }
}

struct MusicLibraryView: View {
    @State private var library=AudioLibrary.shared
    @State private var importing=false
    var body: some View {
        List {
            Section("Мои аудиофайлы") {
                Button("Добавить из Файлов",systemImage:"plus") {importing=true}
                ForEach(library.tracks) {track in
                    Button {library.play(track)} label:{Label(track.title,systemImage:library.currentID == track.id ? "speaker.wave.2" : "music.note")}
                }.onDelete {library.remove(at:$0)}
                if library.tracks.isEmpty {Text("Добавьте аудиофайлы для воспроизведения в приложении.").foregroundStyle(.secondary)}
                NavigationLink("Открыть плеер",value:AppRoute.audioPlayer)
            }
            Section("VK Музыка") {
                Link("Открыть каталог VK",destination:URL(string:"https://vk.com/music")!)
                Text("Каталог и потоки VK подключаются после предоставления музыкального API приложению.").font(.footnote).foregroundStyle(.secondary)
            }
            if let error=library.error {Text(error).foregroundStyle(.red)}
        }.navigationTitle("Музыка").withAppRoutes()
        .fileImporter(isPresented:$importing,allowedContentTypes:[.audio],allowsMultipleSelection:true) {result in
            switch result {case .success(let urls):library.importFiles(urls);case .failure(let error):library.error=error.localizedDescription}
        }
    }
}

struct AudioPlayerView: View {
    @State private var library=AudioLibrary.shared
    var body: some View {
        VStack(spacing:24) {
            Image(systemName:"music.note").font(.system(size:80)).frame(height:160)
            Text(library.current?.title ?? "Выберите аудиофайл").font(.title2.bold()).multilineTextAlignment(.center)
            Slider(value:Binding(get:{library.elapsed},set:{library.seek($0)}),in:0...max(1,library.duration)).disabled(library.current == nil).accessibilityLabel("Позиция воспроизведения")
            HStack {Text(time(library.elapsed));Spacer();Text(time(library.duration))}.font(.caption.monospacedDigit())
            HStack(spacing:32) {
                Button {library.previous()} label:{Image(systemName:"backward.fill").frame(width:44,height:44)}.accessibilityLabel("Предыдущий трек")
                Button {if library.playing {library.pause()} else {library.resume()}} label:{Image(systemName:library.playing ? "pause.fill" : "play.fill").font(.title).frame(width:56,height:56)}.accessibilityLabel(library.playing ? "Пауза" : "Воспроизвести")
                Button {library.next()} label:{Image(systemName:"forward.fill").frame(width:44,height:44)}.accessibilityLabel("Следующий трек")
            }.disabled(library.current == nil)
            Toggle("Перемешивать",isOn:$library.shuffle)
            Toggle("Повторять трек",isOn:$library.repeatOne)
            AudioRoutePicker().frame(width:44,height:44).accessibilityLabel("AirPlay")
            if let error=library.error {Text(error).font(.footnote).foregroundStyle(.red)}
            Spacer()
        }.padding().navigationTitle("Плеер").navigationBarTitleDisplayMode(.inline)
    }
    private func time(_ seconds:Double) -> String {let value=Int(seconds);return String(format:"%d:%02d",value/60,value%60)}
}
struct AudioRoutePicker:UIViewRepresentable {
    func makeUIView(context:Context) -> AVRoutePickerView {AVRoutePickerView()}
    func updateUIView(_ view:AVRoutePickerView,context:Context) {}
}
struct PlaylistView: View {
    let playlistID:Int64
    var body:some View {MusicLibraryView()}
}
