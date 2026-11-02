# Music adaptation

Behavioral reference: decoder-dev/PrivateMusic2, commit 68d10a9.
Reviewed the library, player/queue, lyrics, offline, equalizer and authentication flows.
The owner authorized using that repository for this client.

VKHIG uses its existing SwiftUI architecture and Apple audio frameworks. No donor Rust/C binary,
third-party DSP or cookie/token extraction is included. In particular, PrivateMusic2's web-cookie
exchange and unofficial client identity are not used. VK ID and actual granted audio scope remain
the only catalog entry point.

Implemented:
- Local audio import with title/artist/album metadata, local playlists and library filtering.
- Full player, global mini-player, queue editing, next/previous, shuffle, repeat, seek.
- Local queue selection/position restored paused; remote signed stream URLs are not persisted.
- AVPlayer background playback, AirPlay, Now Playing, lock-screen transport controls.
- Account-isolated offline files from VK-provided HTTPS direct audio streams; download cancellation,
  250 MB/file and 500 MB total cache limits, logout cancellation and hidden other-account files.
- Local LRC/TXT import; multi-timestamp/offset parsing, active lines, tap-to-seek, manual scroll and
  Reduce Motion. User-initiated LRCLIB lookup sends only artist/title, with duration checks for sync.
- Real ten-band AVAudioUnitEQ for local/downloaded files, presets and headroom compensation.

Limits:
- VK catalog needs actual application audio approval and licensed streams. A donor does not grant it.
- Search filters the local library and already loaded catalog pages; it is not global VK search.
- Playlists are local, not server-side VK playlists.
- HLS plays online through AVPlayer; offline HLS is not implemented.
- Online streams and AirPlay use normal playback without equalization.
- Physical-device audio routes, interruptions and live VK acceptance still need verification.
- Calls deferred by user; push notifications remain disabled.

Debug UI tests use an isolated, silent generated WAV library only with both --uitesting and
--music-fixture arguments. Production libraries and accounts are untouched.
