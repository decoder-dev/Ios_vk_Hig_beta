import SwiftUI
import AVKit
import SafariServices
import MediaPlayer
import Observation
import UniformTypeIdentifiers

/// S26 — photo albums: two-column cover grid.
struct PhotoAlbumsView: View {
    private let columns = [GridItem(.flexible(), spacing: VKStyle.Spacing.sm), GridItem(.flexible(), spacing: VKStyle.Spacing.sm)]
    var body: some View {
        FixtureScreen(
            title: "Альбомы",
            screenID: "S26",
            emptyTitle: "Нет альбомов",
            emptySymbol: "rectangle.stack",
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.albums }
        ) { albums in
            ScrollView {
                LazyVGrid(columns: columns, spacing: VKStyle.Spacing.md) {
                    ForEach(albums) { album in
                        NavigationLink(value: AppRoute.albumPhotos(album.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        if let url = album.coverURL {
                                            AsyncImage(url: url) { phase in
                                                if let image = phase.image { image.resizable().scaledToFill() }
                                                else { VKMediaPlaceholder(symbol: "photo.on.rectangle", seed: album.title) }
                                            }
                                        } else {
                                            VKMediaPlaceholder(symbol: "photo.on.rectangle", seed: album.title)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.medium, style: .continuous))
                                Text(album.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(VKFormat.plural(album.count, "фотография", "фотографии", "фотографий"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(VKStyle.Size.contentMargin)
            }
            .withAppRoutes()
        }
    }
}

/// S27 — photos grid, board 03: "Все фото / Альбомы" pills and a dense three-column grid.
struct PhotosGridView: View {
    var albumID: Int64? = nil
    @State private var showsAlbums = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        Group {
            if albumID == nil && showsAlbums {
                PhotoAlbumsView()
            } else {
                grid
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if albumID == nil {
                VKPillPicker(chips: [VKChip(value: false, title: "Все фото"), VKChip(value: true, title: "Альбомы")], selection: $showsAlbums)
                    .padding(.horizontal, VKStyle.Size.contentMargin)
                    .padding(.vertical, VKStyle.Spacing.xs)
                    .background(.bar)
            }
        }
    }

    private var grid: some View {
        FixtureScreen(
            title: "Фотографии",
            screenID: "S27",
            resourceID:albumID,
            emptyTitle: "Нет фотографий",
            emptySymbol: "photo",
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.photos }
        ) { photos in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(photos) { photo in
                        NavigationLink(value: AppRoute.photoViewer(photo.id)) {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    AsyncImage(url:photo.url) { phase in
                                        if let image = phase.image { image.resizable().scaledToFill() }
                                        else { VKMediaPlaceholder(seed: "\(photo.id)") }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.thumbnail, style: .continuous))
                                .contentShape(Rectangle())
                                .accessibilityLabel(photo.caption.isEmpty ? "Фотография" : photo.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, VKStyle.Spacing.xs)
                .padding(.vertical, VKStyle.Spacing.xs)
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

/// S29 — video list, board 02: 16:9 previews with play glyph and duration, title and stats.
struct VideoListView: View {
    var body: some View {
        FixtureScreen(
            title: "Видео",
            screenID: "S29",
            emptyTitle: "Нет видео",
            emptySymbol: "play.rectangle",
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.videos }
        ) { videos in
            ScrollView {
                LazyVStack(spacing: VKStyle.Spacing.lg) {
                    ForEach(videos) { video in
                        NavigationLink(value: AppRoute.videoPlayer(video.id)) {
                            VideoCard(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(VKStyle.Size.contentMargin)
            }
            .withAppRoutes()
        }
    }
}

private struct VideoCard: View {
    let video: VideoItem

    private var subtitle: String {
        var parts = [video.author]
        if let views = video.views { parts.append("\(VKFormat.compact(views)) просмотров") }
        if let date = video.dateLabel { parts.append(date) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VKStyle.Spacing.xs) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    if let url = video.previewURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                            else { VKMediaPlaceholder(symbol: "play.rectangle", seed: video.title) }
                        }
                    } else {
                        VKMediaPlaceholder(symbol: "mountain.2.fill", seed: video.title)
                    }
                }
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(video.durationLabel)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.card, style: .continuous))
            Text(video.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Открыть видео")
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

struct PlaylistView: View {
    let playlistID:Int64
    var body:some View {MusicLibraryView()}
}

struct AttachmentPreview:View {
    let attachment:ChatAttachment
    @State private var showing=false
    var body:some View {
        Group {
            switch attachment.kind {
            case .photo,.sticker,.graffiti:
                Button {showing=true} label: {
                    AsyncImage(url:attachment.url) {phase in
                        if let image=phase.image {image.resizable().scaledToFit()}
                        else if phase.error != nil {Label("Не удалось загрузить",systemImage:"photo")}
                        else {ProgressView()}
                    }.frame(maxWidth:280,maxHeight:240)
                    .clipShape(RoundedRectangle(cornerRadius:VKStyle.Radius.bubble,style:.continuous))
                }.buttonStyle(.plain).accessibilityLabel(attachment.title)
            case .audio,.voice,.video:
                Button {showing=true} label:{Label(attachment.title,systemImage:attachment.symbol)}.frame(minHeight:44)
            case .unsupported:
                Text(attachment.title).font(.caption).foregroundStyle(.secondary)
            default:
                Link(destination:attachment.url) {Label(attachment.title,systemImage:attachment.symbol)}.frame(minHeight:44)
            }
        }.sheet(isPresented:$showing) {
            NavigationStack {
                AttachmentViewer(attachment:attachment)
                    .navigationTitle(attachment.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Закрыть") {showing=false}}}
            }
        }
    }
}
private struct AttachmentViewer:View {
    let attachment:ChatAttachment
    @State private var player:AVPlayer?
    @State private var scale:CGFloat=1
    var body:some View {
        Group {
            if let stream=attachment.playbackURL {
                VideoPlayer(player:player).task {player=AVPlayer(url:stream);player?.play()}.onDisappear {player?.pause()}
            } else if attachment.kind == .video {OfficialWebPlayer(url:attachment.url)}
            else {
                AsyncImage(url:attachment.url) {image in image.resizable().scaledToFit().scaleEffect(scale)} placeholder:{ProgressView()}
                    .gesture(MagnifyGesture().onChanged {scale=min(4,max(1,$0.magnification))})
                    .frame(maxWidth:.infinity,maxHeight:.infinity).background(.black)
            }
        }
    }
}
