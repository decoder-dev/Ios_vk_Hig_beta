import Foundation
import AVFoundation
import MediaPlayer
import Observation

@MainActor
@Observable
final class AudioLibrary {
    static let shared=AudioLibrary(directory:musicUITestDirectory())
    private(set) var tracks:[LocalAudioTrack]=[]
    private(set) var playlists:[MusicPlaylist]=[]
    private(set) var activeQueue:[LocalAudioTrack]=[]
    private(set) var queueIndex=0
    private(set) var activeAccountID:Int64?
    private(set) var playing=false
    private(set) var buffering=false
    private(set) var elapsed=0.0
    private(set) var duration=0.0
    private(set) var shuffle=false
    var repeatOne=false {didSet {savePreferences()}}
    private(set) var equalizerSettings=MusicEQSettings()
    private(set) var importing=false
    private(set) var downloading=Set<String>()
    var playerPresented=false
    var error:String?
    @ObservationIgnored private let directory:URL
    @ObservationIgnored private let playbackEnabled:Bool
    @ObservationIgnored private let player=AVPlayer()
    @ObservationIgnored private let equalizer=LocalMusicEqualizer()
    @ObservationIgnored private var equalizerActive=false
    @ObservationIgnored private var originalQueue:[LocalAudioTrack]=[]
    @ObservationIgnored private var revision=UUID()
    @ObservationIgnored private var downloadRevision=UUID()
    @ObservationIgnored private var downloadTasks:[String:Task<Void,Never>]=[:]
    @ObservationIgnored private var timer:Timer?
    @ObservationIgnored private var observers:[NSObjectProtocol]=[]
    @ObservationIgnored private var itemStatus:NSKeyValueObservation?
    @ObservationIgnored private var wantedPlayback=false
    @ObservationIgnored private var resumeAfterInterruption=false
    @ObservationIgnored private var lastSavedSecond = -1
    @ObservationIgnored private var equalizerStarted=Date.distantPast
    @ObservationIgnored private let fetchDownload:(URL) async throws -> (URL,HTTPURLResponse)

    var current:LocalAudioTrack? {activeQueue.indices.contains(queueIndex) ? activeQueue[queueIndex] : nil}
    var currentID:String? {current?.id}
    var upcoming:[LocalAudioTrack] {current==nil ? [] : Array(activeQueue.dropFirst(queueIndex+1))}
    var visibleTracks:[LocalAudioTrack] {tracks.filter {$0.accountID==nil || $0.accountID==activeAccountID}}
    var visiblePlaylists:[MusicPlaylist] {playlists.filter {$0.accountID==nil || $0.accountID==activeAccountID}}
    var cacheBytes:Int64 {visibleTracks.filter {$0.accountID != nil}.reduce(0) {$0+max(0,$1.byteCount ?? 0)}}
    var canEqualize:Bool {
        current?.url.isFileURL == true && !AVAudioSession.sharedInstance().currentRoute.outputs.contains {$0.portType == .airPlay}
    }
    init(directory:URL?=nil,playbackEnabled:Bool=true,fetchDownload:((URL) async throws -> (URL,HTTPURLResponse))?=nil) {
        self.directory=directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("AudioLibrary",isDirectory:true)
        self.playbackEnabled=playbackEnabled
        self.fetchDownload=fetchDownload ?? Self.downloadFile
        try? FileManager.default.createDirectory(at:self.directory,withIntermediateDirectories:true)
        let saved:[LocalAudioTrack]=read([LocalAudioTrack].self,name:"index.json") ?? []
        tracks=saved.compactMap {item in
            guard item.url.isFileURL,let url=containedURL(item.url.lastPathComponent),FileManager.default.fileExists(atPath:url.path) else {return nil}
            var value=item;value.url=url
            value.byteCount=(try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize).map(Int64.init)
            if let art=value.artworkURL,art.isFileURL {value.artworkURL=containedURL(art.lastPathComponent)}
            return value
        }
        playlists=read([MusicPlaylist].self,name:"playlists.json") ?? []
        let preferences=read(MusicPreferences.self,name:"preferences.json") ?? MusicPreferences()
        shuffle=preferences.shuffle;repeatOne=preferences.repeatOne;equalizerSettings=preferences.equalizer.normalized
        restoreQueue()
        if playbackEnabled {installSystemIntegration()}
    }
    private func containedURL(_ name:String) -> URL? {
        guard !name.isEmpty,name != ".",name != "..",!name.contains("/"),!["index.json","preferences.json","playlists.json"].contains(name) else {return nil}
        let url=directory.appendingPathComponent(name)
        guard url.resolvingSymlinksInPath().deletingLastPathComponent()==directory.resolvingSymlinksInPath() else {return nil}
        return url
    }
    private func read<T:Decodable>(_ type:T.Type,name:String) -> T? {
        for suffix in ["",".backup"] {
            if let data=try? Data(contentsOf:directory.appendingPathComponent(name+suffix)),
               let value=try? JSONDecoder().decode(type,from:data) {return value}
        }
        return nil
    }
    private func write<T:Codable>(_ value:T,name:String) {
        do {
            let url=directory.appendingPathComponent(name),data=try JSONEncoder().encode(value)
            if let old=try? Data(contentsOf:url),(try? JSONDecoder().decode(T.self,from:old)) != nil {
                try old.write(to:url.appendingPathExtension("backup"),options:.atomic)
            }
            try data.write(to:url,options:.atomic)
        } catch {self.error="Не удалось сохранить медиатеку: "+error.localizedDescription}
    }
    private func saveIndex() {write(tracks,name:"index.json")}
    private func savePreferences() {write(MusicPreferences(shuffle:shuffle,repeatOne:repeatOne,equalizer:equalizerSettings),name:"preferences.json")}
    private var queueFile:String {"queue-\(activeAccountID.map(String.init) ?? "local").json"}
    private func saveQueue() {
        let localIDs=activeQueue.filter(\.url.isFileURL).map(\.id)
        write(MusicQueueSnapshot(ids:localIDs,currentID:currentID,position:elapsed.isFinite ? max(0,elapsed) : 0),name:queueFile)
    }
    private func restoreQueue() {
        guard current==nil,let snapshot=read(MusicQueueSnapshot.self,name:queueFile) else {return}
        let available=Dictionary(visibleTracks.map {($0.id,$0)},uniquingKeysWith:{a,_ in a})
        var seen=Set<String>();activeQueue=snapshot.ids.compactMap {seen.insert($0).inserted ? available[$0] : nil}
        originalQueue=activeQueue
        queueIndex=activeQueue.firstIndex {$0.id==snapshot.currentID} ?? 0
        elapsed=snapshot.position.isFinite ? max(0,snapshot.position) : 0
        duration=max(0,current?.duration ?? 0)
        if duration>0 {elapsed=min(elapsed,duration)}
        // Restore selection, never start playback on app launch.
    }
    func setAccount(_ id:Int64?) {
        guard activeAccountID != id else {return}
        if activeAccountID != nil {resetRemoteSession()}
        activeAccountID=id
        if current==nil {restoreQueue()}
    }
    func resetRemoteSession() {
        saveQueue()
        downloadRevision=UUID();downloadTasks.values.forEach {$0.cancel()};downloadTasks=[:];downloading=[]
        let selected=currentID
        activeQueue=activeQueue.filter {$0.accountID==nil};originalQueue=activeQueue
        if let selected,let index=activeQueue.firstIndex(where:{$0.id==selected}) {queueIndex=index}
        else {stop();activeQueue=[];queueIndex=0}
        activeAccountID=nil
    }
    func importFiles(_ urls:[URL]) async {
        guard !importing else {return};importing=true;defer {importing=false}
        guard urls.count<=100 else {error="За один раз можно добавить до 100 файлов.";return}
        for url in urls {
            let access=url.startAccessingSecurityScopedResource();defer {if access {url.stopAccessingSecurityScopedResource()}}
            var destination:URL?
            do {
                try Task.checkCancellation()
                let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                guard size>0,Int64(size)<=MusicPolicy.maximumFileBytes else {throw AppError.network("Размер аудиофайла — до 250 МБ.")}
                let id=UUID().uuidString,ext=url.pathExtension.lowercased()
                guard ext.isEmpty || ext.range(of:"^[a-z0-9]{1,8}$",options:.regularExpression) != nil else {throw AppError.decoding}
                let target=directory.appendingPathComponent(id).appendingPathExtension(ext)
                destination=target;try FileManager.default.copyItem(at:url,to:target)
                var track=LocalAudioTrack(id:id,title:url.deletingPathExtension().lastPathComponent,url:target,byteCount:Int64(size))
                let asset=AVURLAsset(url:target)
                if let seconds=try? await asset.load(.duration).seconds,seconds.isFinite {track.duration=max(0,seconds)}
                for item in (try? await asset.load(.commonMetadata)) ?? [] {
                    if item.commonKey == .commonKeyTitle,let value=try? await item.load(.stringValue),!value.isEmpty {track.title=value}
                    if item.commonKey == .commonKeyArtist,let value=try? await item.load(.stringValue) {track.artist=value}
                    if item.commonKey == .commonKeyAlbumName,let value=try? await item.load(.stringValue) {track.album=value}
                }
                tracks.append(track);saveIndex()
            } catch {
                if let destination {try? FileManager.default.removeItem(at:destination)}
                self.error=error is CancellationError ? "Импорт отменён." : error.localizedDescription
            }
        }
    }
    func remove(at offsets:IndexSet) {
        let visible=visibleTracks
        for index in offsets where visible.indices.contains(index) {remove(visible[index])}
    }
    func remove(_ track:LocalAudioTrack) {
        guard let stored=tracks.first(where:{$0.id==track.id}),stored.accountID==nil || stored.accountID==activeAccountID else {return}
        if currentID==track.id {stop()}
        let selected=currentID
        activeQueue.removeAll {$0.id==track.id};originalQueue.removeAll {$0.id==track.id}
        queueIndex=selected.flatMap {id in activeQueue.firstIndex {$0.id==id}} ?? 0
        if let url=containedURL(stored.url.lastPathComponent) {try? FileManager.default.removeItem(at:url)}
        tracks.removeAll {$0.id==track.id}
        for index in playlists.indices {playlists[index].trackIDs.removeAll {$0==track.id}}
        saveIndex();write(playlists,name:"playlists.json");saveQueue()
    }
    func createPlaylist(_ title:String) {
        let name=title.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else {error="Укажите название плейлиста.";return}
        playlists.append(MusicPlaylist(title:String(name.prefix(120)),accountID:activeAccountID));write(playlists,name:"playlists.json")
    }
    func add(_ track:LocalAudioTrack,to playlist:MusicPlaylist) {
        guard visibleTracks.contains(where:{$0.id==track.id}),let index=playlists.firstIndex(where:{$0.id==playlist.id}),
              playlists[index].accountID==nil || playlists[index].accountID==activeAccountID else {return}
        // Account-specific tracks cannot enter a playlist visible after logout.
        guard track.accountID==nil || playlists[index].accountID==track.accountID else {error="Для треков VK создайте плейлист внутри своего аккаунта.";return}
        if !playlists[index].trackIDs.contains(track.id) {playlists[index].trackIDs.append(track.id)}
        write(playlists,name:"playlists.json")
    }
    func playlistTracks(_ playlist:MusicPlaylist) -> [LocalAudioTrack] {
        guard playlist.accountID==nil || playlist.accountID==activeAccountID else {return []}
        let map=Dictionary(visibleTracks.map {($0.id,$0)},uniquingKeysWith:{a,_ in a})
        return playlist.trackIDs.compactMap {map[$0]}
    }
    func removePlaylist(_ playlist:MusicPlaylist) {
        playlists.removeAll {$0.id==playlist.id && ($0.accountID==nil || $0.accountID==activeAccountID)}
        write(playlists,name:"playlists.json")
    }
    func removePlaylistTracks(_ playlist:MusicPlaylist,offsets:IndexSet) {
        guard let index=playlists.firstIndex(where:{$0.id==playlist.id}),playlist.accountID==nil || playlist.accountID==activeAccountID else {return}
        let ids=playlistTracks(playlist).enumerated().filter {offsets.contains($0.offset)}.map {$0.element.id}
        playlists[index].trackIDs.removeAll {ids.contains($0)};write(playlists,name:"playlists.json")
    }
    private func resolved(_ track:LocalAudioTrack) -> LocalAudioTrack {
        if !track.url.isFileURL,let cached=visibleTracks.first(where:{$0.sourceID==track.id && $0.accountID==activeAccountID}) {return cached}
        return track
    }
    func play(_ track:LocalAudioTrack) {playQueue(visibleTracks.contains(where:{$0.id==track.id}) ? visibleTracks : [track],startingAt:track.id)}
    func playRemote(_ track:LocalAudioTrack,queue:[LocalAudioTrack]) {
        guard let account=activeAccountID ?? VKIDAuthCoordinator.shared.userID else {error="Войдите в VK для воспроизведения каталога.";return}
        if activeAccountID==nil {setAccount(account)}
        let items=queue.map {item -> LocalAudioTrack in var value=item;value.accountID=account;return resolved(value)}
        let selected=items.first {$0.sourceID==track.id || $0.id==track.id}
        playQueue(items,startingAt:selected?.id ?? track.id)
    }
    func playQueue(_ items:[LocalAudioTrack],startingAt id:String) {
        var seen=Set<String>()
        let safe=items.filter {($0.accountID==nil || $0.accountID==activeAccountID) && ($0.url.isFileURL || MusicPolicy.safeRemote($0.url) != nil) && seen.insert($0.id).inserted}
        guard let index=safe.firstIndex(where:{$0.id==id}) else {error="Трек недоступен.";return}
        originalQueue=safe
        if shuffle {activeQueue=[safe[index]]+safe.enumerated().filter {$0.offset != index}.map(\.element).shuffled();queueIndex=0}
        else {activeQueue=safe;queueIndex=index}
        loadCurrent();saveQueue()
    }
    func selectQueue(_ index:Int) {guard activeQueue.indices.contains(index) else {return};queueIndex=index;loadCurrent();saveQueue()}
    func enqueue(_ track:LocalAudioTrack,next:Bool=false) {
        guard (track.accountID==nil || track.accountID==activeAccountID),track.url.isFileURL || MusicPolicy.safeRemote(track.url) != nil else {return}
        if current==nil {activeQueue=[track];originalQueue=activeQueue;queueIndex=0;duration=track.duration ?? 0;saveQueue();return}
        guard currentID != track.id else {return}
        let selected=currentID
        activeQueue.removeAll {$0.id==track.id}
        queueIndex=activeQueue.firstIndex {$0.id==selected} ?? 0
        activeQueue.insert(track,at:next ? queueIndex+1 : activeQueue.endIndex)
        originalQueue=activeQueue;saveQueue()
    }
    func moveUpcoming(_ offsets:IndexSet,to destination:Int) {
        activeQueue=MusicPolicy.moveUpcoming(activeQueue,current:queueIndex,offsets:offsets,destination:destination)
        originalQueue=activeQueue;shuffle=false;savePreferences();saveQueue()
    }
    func removeUpcoming(_ offsets:IndexSet) {
        let ids=upcoming.enumerated().filter {offsets.contains($0.offset)}.map {$0.element.id}
        activeQueue.removeAll {ids.contains($0.id)};originalQueue=activeQueue;saveQueue()
    }
    func clearUpcoming() {activeQueue=Array(activeQueue.prefix(queueIndex+1));originalQueue=activeQueue;saveQueue()}
    func setShuffle(_ value:Bool) {
        guard shuffle != value else {return}
        shuffle=value
        if current != nil {
            let head=Array(activeQueue.prefix(queueIndex+1)),tail=upcoming
            if value {activeQueue=head+tail.shuffled()}
            else {
                let remaining=Dictionary(tail.map {($0.id,$0)},uniquingKeysWith:{a,_ in a})
                let ordered=originalQueue.compactMap {remaining[$0.id]}
                let known=Set(ordered.map(\.id));activeQueue=head+ordered+tail.filter {!known.contains($0.id)}
            }
        }
        savePreferences();saveQueue()
    }
    private func loadCurrent(position:Double=0,autoplay:Bool=true) {
        guard let track=current else {return}
        revision=UUID();let ticket=revision
        player.pause();player.replaceCurrentItem(with:nil);itemStatus=nil;equalizer.stop();equalizerActive=false
        elapsed=position.isFinite ? max(0,position) : 0;duration=max(0,track.duration ?? 0);error=nil;buffering=false
        wantedPlayback=autoplay;playing=autoplay;resumeAfterInterruption=false
        guard playbackEnabled else {return}
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,mode:.default)
            // AVAudioEngine needs an active audio route even when the selected file is paused.
            if autoplay || (equalizerSettings.enabled && canEqualize) {try AVAudioSession.sharedInstance().setActive(true)}
            if equalizerSettings.enabled && canEqualize {
                do {
                    try equalizer.load(track.url,position:elapsed,autoplay:autoplay,settings:equalizerSettings) {[weak self] in self?.finished()}
                    equalizerActive=true;equalizerStarted=Date();duration=equalizer.duration
                    updateNowPlaying();return
                } catch {equalizerSettings.enabled=false;savePreferences();self.error="Эквалайзер выключен: "+error.localizedDescription}
            }
            let item=AVPlayerItem(url:track.url)
            itemStatus=item.observe(\.status,options:[.new]) {[weak self] item,_ in
                guard item.status == .failed else {return}
                Task {@MainActor in guard let self,self.revision==ticket else {return};self.error="Поток недоступен. Обновите каталог VK или выберите другой файл.";self.pause()}
            }
            player.replaceCurrentItem(with:item)
            if elapsed>0 {player.seek(to:CMTime(seconds:elapsed,preferredTimescale:600))}
            if autoplay {player.play()}
            updateNowPlaying()
        } catch {self.error=error.localizedDescription;wantedPlayback=false;playing=false}
    }
    func retryPlayback() {loadCurrent(position:elapsed)}
    private func finished() {if repeatOne {seek(0);resume()} else {next()}}
    func resume() {
        guard current != nil else {return}
        if playbackEnabled {
            if player.currentItem==nil && !equalizerActive {loadCurrent(position:elapsed);return}
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                if equalizerActive {try equalizer.resume()} else {if duration>0 && elapsed>=duration-0.05 {seek(0)};player.play()}
            } catch {self.error=error.localizedDescription;return}
        }
        wantedPlayback=true;playing=true;resumeAfterInterruption=false;updateNowPlaying()
    }
    func pause(userInitiated:Bool=true) {
        if equalizerActive {elapsed=equalizer.position;equalizer.pause()} else {player.pause()}
        wantedPlayback=false;playing=false;buffering=false
        if userInitiated {resumeAfterInterruption=false}
        saveQueue();updateNowPlaying()
    }
    private func stop() {pause();player.replaceCurrentItem(with:nil);equalizer.stop();equalizerActive=false;elapsed=0;duration=0;if playbackEnabled {MPNowPlayingInfoCenter.default().nowPlayingInfo=nil}}
    func seek(_ value:Double) {
        guard value.isFinite,current != nil else {return}
        elapsed=min(duration>0 ? duration : Double.greatestFiniteMagnitude,max(0,value))
        if playbackEnabled {if equalizerActive {equalizer.seek(elapsed,playing:wantedPlayback)} else {player.seek(to:CMTime(seconds:elapsed,preferredTimescale:600))}}
        saveQueue();updateNowPlaying()
    }
    func next() {guard current != nil else {return};if queueIndex+1<activeQueue.count {queueIndex+=1;loadCurrent();saveQueue()} else {pause();seek(0)}}
    func previous() {if elapsed>3 {seek(0)} else if queueIndex>0 {queueIndex-=1;loadCurrent();saveQueue()} else {seek(0)}}
    func setEqualizer(_ settings:MusicEQSettings) {
        let value=settings.normalized
        if value.enabled && !canEqualize {error="Эквалайзер доступен для локальных файлов на iPhone. Онлайн-потоки и AirPlay воспроизводятся без него.";return}
        let switching=value.enabled != equalizerSettings.enabled
        equalizerSettings=value;savePreferences()
        if equalizerActive && !switching {equalizer.apply(value)}
        else if switching,current != nil {let position=elapsed,autoplay=wantedPlayback;loadCurrent(position:position,autoplay:autoplay)}
    }
    func lyrics(for track:LocalAudioTrack) -> MusicLyrics? {read(MusicLyrics.self,name:lyricsFile(track))}
    func saveLyrics(_ lyrics:MusicLyrics,for track:LocalAudioTrack) {
        guard track.accountID==nil || track.accountID==activeAccountID else {return}
        write(lyrics,name:lyricsFile(track))
    }
    private func lyricsFile(_ track:LocalAudioTrack) -> String {
        "lyrics-\(BookmarkItem.stableID("\(track.accountID ?? 0):\(track.sourceID ?? track.id)")).json"
    }
    func cached(_ track:VKAudioTrack) -> Bool {visibleTracks.contains {$0.sourceID==track.id && $0.accountID==activeAccountID}}
    func cancelDownload(_ id:String) {downloadTasks[id]?.cancel()}
    func download(_ track:VKAudioTrack) {
        guard let account=activeAccountID,let url=MusicPolicy.safeRemote(track.url),!downloading.contains(track.id),!cached(track) else {return}
        if url.pathExtension.lowercased()=="m3u8" {error="Этот HLS-поток доступен только онлайн в текущей версии.";return}
        let ticket=downloadRevision;downloading.insert(track.id)
        downloadTasks[track.id]=Task {
            defer {if ticket==downloadRevision {downloading.remove(track.id);downloadTasks[track.id]=nil}}
            var temporary:URL?
            defer {if let temporary {try? FileManager.default.removeItem(at:temporary)}}
            do {
                let (temp,response)=try await fetchDownload(url);temporary=temp
                try Task.checkCancellation()
                guard ticket==downloadRevision,account==activeAccountID else {return}
                guard response.statusCode==200,MusicPolicy.safeRemote(response.url) != nil else {throw AppError.network("Не удалось скачать файл. Обновите каталог и повторите.")}
                let ext=try MusicPolicy.downloadExtension(url,mime:response.mimeType)
                let size=try temp.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                let total=tracks.filter {$0.accountID != nil}.reduce(Int64(0)) {$0+max(0,$1.byteCount ?? 0)}
                guard size>0,Int64(size)<=MusicPolicy.maximumFileBytes,total+Int64(size)<=MusicPolicy.maximumCacheBytes else {throw AppError.network("Лимит скачанных треков — 500 МБ, одного файла — 250 МБ. Удалите ненужные загрузки.")}
                let destination=directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
                try FileManager.default.moveItem(at:temp,to:destination);temporary=nil
                var resource=URLResourceValues();resource.isExcludedFromBackup=true;var localURL=destination;try? localURL.setResourceValues(resource)
                let item=LocalAudioTrack(id:"offline_\(account)_\(track.id)",title:track.title,url:destination,artist:track.artist,album:track.album,duration:Double(track.duration),accountID:account,sourceID:track.id,byteCount:Int64(size))
                tracks.append(item);saveIndex()
            } catch is CancellationError {} catch {if !Task.isCancelled && ticket==downloadRevision {self.error=error.localizedDescription}}
        }
    }
    private static func downloadFile(_ url:URL) async throws -> (URL,HTTPURLResponse) {
        let config=URLSessionConfiguration.ephemeral;config.httpShouldSetCookies=false;config.httpCookieStorage=nil;config.timeoutIntervalForRequest=30;config.timeoutIntervalForResource=180
        let session=URLSession(configuration:config,delegate:MusicHTTPSDelegate(),delegateQueue:nil)
        defer {session.finishTasksAndInvalidate()}
        let (temporary,response)=try await session.download(from:url)
        guard let response=response as? HTTPURLResponse else {try? FileManager.default.removeItem(at:temporary);throw AppError.decoding}
        return (temporary,response)
    }
    private func tick() {
        guard current != nil,equalizerActive || player.currentItem != nil else {return}
        if equalizerActive {elapsed=equalizer.position;duration=equalizer.duration}
        else {
            let time=player.currentTime().seconds,length=player.currentItem?.duration.seconds ?? 0
            if time.isFinite {elapsed=max(0,time)}
            if length.isFinite,length>0 {duration=length}
            buffering=wantedPlayback && player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        }
        let second=Int(min(1_000_000,max(0,elapsed)))
        if second/10 != lastSavedSecond/10 {lastSavedSecond=second;saveQueue()}
        updateNowPlaying()
    }
    private func installSystemIntegration() {
        let clock=Timer(timeInterval:0.5,repeats:true) {[weak self] _ in Task {@MainActor in self?.tick()}}
        clock.tolerance=0.2;RunLoop.main.add(clock,forMode:.common);timer=clock
        let center=NotificationCenter.default
        observers.append(center.addObserver(forName:.AVPlayerItemDidPlayToEndTime,object:nil,queue:.main) {[weak self] note in
            Task {@MainActor in guard let self,let item=note.object as? AVPlayerItem,item === self.player.currentItem else {return};self.finished()}
        })
        observers.append(center.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) {[weak self] note in
            let type=note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options=note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task {@MainActor in
                guard let self else {return}
                if type==AVAudioSession.InterruptionType.began.rawValue {self.resumeAfterInterruption=self.wantedPlayback;self.pause(userInitiated:false)}
                else if self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue:options).contains(.shouldResume) {self.resume()}
            }
        })
        observers.append(center.addObserver(forName:AVAudioSession.routeChangeNotification,object:nil,queue:.main) {[weak self] note in
            let reason=note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason==AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {Task {@MainActor in self?.pause()}}
        })
        observers.append(center.addObserver(forName:.AVAudioEngineConfigurationChange,object:nil,queue:.main) {[weak self] _ in
            Task {@MainActor in
                guard let self,self.equalizerActive,Date().timeIntervalSince(self.equalizerStarted)>1 else {return}
                self.pause();self.equalizerSettings.enabled=false;self.savePreferences();self.loadCurrent(position:self.elapsed,autoplay:false)
                self.error="Аудиоустройство изменилось. Эквалайзер выключен; нажмите «Воспроизвести» для продолжения."
            }
        })
        let commands=MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget {[weak self] _ in Task {@MainActor in self?.resume()};return .success}
        commands.pauseCommand.addTarget {[weak self] _ in Task {@MainActor in self?.pause()};return .success}
        commands.nextTrackCommand.addTarget {[weak self] _ in Task {@MainActor in self?.next()};return .success}
        commands.previousTrackCommand.addTarget {[weak self] _ in Task {@MainActor in self?.previous()};return .success}
        commands.changePlaybackPositionCommand.addTarget {[weak self] event in
            guard let event=event as? MPChangePlaybackPositionCommandEvent else {return .commandFailed}
            let position=event.positionTime;Task {@MainActor in self?.seek(position)};return .success
        }
    }
    private func updateNowPlaying() {
        guard playbackEnabled,let current else {return}
        var info:[String:Any]=[MPMediaItemPropertyTitle:current.title,MPMediaItemPropertyArtist:current.artist ?? "",MPMediaItemPropertyPlaybackDuration:duration,MPNowPlayingInfoPropertyElapsedPlaybackTime:elapsed,MPNowPlayingInfoPropertyPlaybackRate:playing ? 1.0 : 0.0]
        if let album=current.album {info[MPMediaItemPropertyAlbumTitle]=album}
        MPNowPlayingInfoCenter.default().nowPlayingInfo=info
    }
    deinit {
        timer?.invalidate()
        for observer in observers {NotificationCenter.default.removeObserver(observer)}
    }
}

// Isolated, silent WAV fixtures exist only in debug UI-test launches.
// Production library and account caches are never modified by this path.
@MainActor
private func musicUITestDirectory() -> URL? {
    #if DEBUG
    let args=ProcessInfo.processInfo.arguments
    guard args.contains("--uitesting"),args.contains("--music-fixture") else {return nil}
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent("MusicUITestFixture",isDirectory:true)
    try? FileManager.default.removeItem(at:directory)
    do {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        var audio=Data()
        func ascii(_ value:String) {audio.append(contentsOf:value.utf8)}
        func integer<T:FixedWidthInteger>(_ value:T) {var little=value.littleEndian;withUnsafeBytes(of:&little) {audio.append(contentsOf:$0)}}
        let size:UInt32=8000*2*12
        ascii("RIFF");integer(size+36);ascii("WAVEfmt ");integer(UInt32(16));integer(UInt16(1));integer(UInt16(1))
        integer(UInt32(8000));integer(UInt32(16000));integer(UInt16(2));integer(UInt16(16));ascii("data");integer(size)
        audio.append(Data(repeating:0,count:Int(size)))
        let names=["Рассвет","Тихая дорога","После дождя"]
        let tracks=try names.enumerated().map {index,title -> LocalAudioTrack in
            let url=directory.appendingPathComponent("fixture-\(index).wav")
            try audio.write(to:url)
            return LocalAudioTrack(id:"fixture-\(index)",title:title,url:url,artist:"Тестовая медиатека",duration:12)
        }
        try JSONEncoder().encode(tracks).write(to:directory.appendingPathComponent("index.json"))
        try JSONEncoder().encode(MusicQueueSnapshot(ids:tracks.map(\.id),currentID:tracks[0].id,position:0)).write(to:directory.appendingPathComponent("queue-local.json"))
        try JSONEncoder().encode([MusicPlaylist(title:"В дороге",trackIDs:tracks.map(\.id))]).write(to:directory.appendingPathComponent("playlists.json"))
        let lyrics=MusicLyrics.parse("[00:00.00]Тихая тестовая запись\n[00:04.00]Проверка строки и перемотки\n[00:08.00]До нового рассвета")
        let key=BookmarkItem.stableID("0:\(tracks[0].id)")
        try JSONEncoder().encode(lyrics).write(to:directory.appendingPathComponent("lyrics-\(key).json"))
        return directory
    } catch {return directory}
    #else
    return nil
    #endif
}
