import SwiftUI
import AVKit
import SafariServices

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

/// S31 — music library (honest unavailable + fixture library browse).
struct MusicLibraryView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.capabilities.status(for: .music) == .unavailable {
                List {
                    Section {
                        VKUnavailableState(
                            title: "Музыка недоступна",
                            details: "VK не предоставил этому приложению доступ к музыкальным потокам."
                        )
                        .listRowBackground(Color.clear)
                    }
                    Section("S31 · Fixture library (no playback)") {
                        ForEach(CatalogFixtures.playlists) { playlist in
                            NavigationLink(value: AppRoute.playlist(playlist.id)) {
                                Label("\(playlist.title) · \(playlist.trackCount)", systemImage: "music.note.list")
                            }
                        }
                        NavigationLink(value: AppRoute.audioPlayer) {
                            Label("Просмотр плеера", systemImage: "play.circle")
                        }
                    }
                }
                .navigationTitle("Музыка")
                .withAppRoutes()
            } else {
                Text("Unexpected music capability")
            }
        }
    }
}

/// S32 — audio player shell.
struct AudioPlayerView: View {
    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 16)
                .fill(VKStyle.cell)
                .frame(width: 220, height: 220)
                .overlay { Image(systemName: "music.note").font(.system(size: 48)) }
            Text("Демонстрационная композиция").font(.title2.bold())
            Text("S32 · Seek/AirPlay only with licensed streams").font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 32) {
                Button {} label: { Image(systemName: "backward.fill").frame(width: 44, height: 44) }
                    .disabled(true)
                Button {} label: { Image(systemName: "play.fill").font(.title).frame(width: 56, height: 56) }
                    .disabled(true)
                    .accessibilityLabel("Play disabled — no licensed stream")
                Button {} label: { Image(systemName: "forward.fill").frame(width: 44, height: 44) }
                    .disabled(true)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Плеер")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// S33 — playlist.
struct PlaylistView: View {
    let playlistID: Int64

    var body: some View {
        FixtureScreen(
            title: "Плейлист",
            screenID: "S33",
            emptyTitle: "Плейлист пуст",
            emptySymbol: "music.note.list",
            emptyDetails: "Audio methods gated.",
            isEmpty: { $0.isEmpty },
            loadValue: {
                _ = playlistID
                CatalogFixtures.tracks
            }
        ) { tracks in
            List(tracks) { track in
                HStack {
                    VStack(alignment: .leading) {
                        Text(track.title)
                        Text(track.artist).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(track.durationLabel).font(.caption).foregroundStyle(.secondary)
                    Image(systemName: "play.slash").foregroundStyle(.tertiary)
                }
                .accessibilityLabel("\(track.title), playback disabled")
            }
        }
    }
}
