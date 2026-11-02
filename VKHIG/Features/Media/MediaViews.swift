import SwiftUI

/// S26 — photo albums.
struct PhotoAlbumsView: View {
    var body: some View {
        FixtureScreen(
            title: "Альбомы",
            screenID: "S26",
            emptyTitle: "No albums",
            emptySymbol: "rectangle.stack",
            emptyDetails: "photos.getAlbums when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.albums }
        ) { albums in
            List(albums) { album in
                NavigationLink(value: AppRoute.photos) {
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
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        FixtureScreen(
            title: "Фотографии",
            screenID: "S27",
            emptyTitle: "No photos",
            emptySymbol: "photo",
            emptyDetails: "photos.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.photos }
        ) { photos in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(photos) { photo in
                        NavigationLink(value: AppRoute.photoViewer(photo.id)) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(VKStyle.cell)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    Text("\(photo.id)").font(.caption2).foregroundStyle(.secondary)
                                }
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
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.35))
                .overlay {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                        Text("Photo \(photoID)")
                        Text("S28 · fixture placeholder — no remote bitmap")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                }
                .padding(24)
                .scaleEffect(scale)
                .gesture(MagnifyGesture().onChanged { scale = $0.magnification })
        }
        .navigationTitle("Фото")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "Photo \(photoID) fixture") {
                    Image(systemName: "square.and.arrow.up")
                        .frame(minWidth: 44, minHeight: 44)
                }
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
            emptyTitle: "No videos",
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

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.black)
                VStack(spacing: 8) {
                    Image(systemName: "play.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                    Text("Playback gated")
                        .foregroundStyle(.white)
                    Text("S30 · AVKit only when official URL + rights exist")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .frame(height: 220)
            .padding()
            Text("Video id \(videoID)")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .background(VKStyle.groupedCanvas)
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.inline)
    }
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
                            title: "Music streaming unavailable",
                            details: "Official audio rights are not confirmed for this app. Fixture track list is for UI layout only — play is disabled."
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
                            Label("Player shell", systemImage: "play.circle")
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
            Text("Fixture track").font(.title2.bold())
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
            emptyTitle: "Empty playlist",
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
