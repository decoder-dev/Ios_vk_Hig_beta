import Foundation
import AVFoundation

// Behavioral reference: decoder-dev/PrivateMusic2 @ 68d10a9.
// Native implementation for VKHIG's existing player and approved API session.
struct LocalAudioTrack: Identifiable, Codable, Equatable, Sendable {
    var id:String
    var title:String
    var url:URL
    var artist:String? = nil
    var album:String? = nil
    var duration:Double? = nil
    var artworkURL:URL? = nil
    var accountID:Int64? = nil
    var sourceID:String? = nil
    var byteCount:Int64? = nil
    var subtitle:String {artist?.isEmpty == false ? artist! : "Аудиофайл"}
}
struct MusicPlaylist:Identifiable,Codable,Equatable {
    var id=UUID().uuidString
    var title:String
    var trackIDs:[String]=[]
    var accountID:Int64?
}
struct MusicQueueSnapshot:Codable {
    var ids:[String]
    var currentID:String?
    var position:Double
}
struct MusicPreferences:Codable {
    var shuffle=false
    var repeatOne=false
    var equalizer=MusicEQSettings()
}
struct MusicEQSettings:Codable,Equatable {
    static let frequencies:[Float]=[31,62,125,250,500,1000,2000,4000,8000,16000]
    var enabled=false
    var gains=[Float](repeating:0,count:10)
    var preamp:Float=0
    var normalized:MusicEQSettings {
        var value=self
        value.gains=(0..<10).map {index in
            guard gains.indices.contains(index),gains[index].isFinite else {return 0}
            return min(12,max(-12,gains[index]))
        }
        value.preamp=preamp.isFinite ? min(6,max(-12,preamp)) : 0
        return value
    }
    var safePreamp:Float {min(normalized.preamp,-max(0,normalized.gains.max() ?? 0))}
    static func preset(_ name:String) -> MusicEQSettings {
        var value=MusicEQSettings();value.enabled=true
        if name=="Бас" {value.gains=[6,5,4,2,0,0,-1,-1,0,0]}
        if name=="Голос" {value.gains=[-3,-2,0,2,4,4,3,1,-1,-2]}
        return value
    }
}
enum MusicPolicy {
    static let maximumFileBytes:Int64=250_000_000
    static let maximumCacheBytes:Int64=500_000_000
    static func safeRemote(_ url:URL?) -> URL? {
        guard let url,url.scheme?.lowercased()=="https",url.host?.isEmpty == false,url.user==nil,url.password==nil else {return nil}
        return url
    }
    static func moveUpcoming<T>(_ queue:[T],current:Int,offsets:IndexSet,destination:Int) -> [T] {
        guard queue.indices.contains(current) else {return queue}
        let head=current+1,tail=Array(queue.dropFirst(head))
        guard !offsets.isEmpty,offsets.allSatisfy({tail.indices.contains($0)}),(0...tail.count).contains(destination) else {return queue}
        let selected=offsets.map {tail[$0]}
        var remaining=tail.enumerated().filter {!offsets.contains($0.offset)}.map(\.element)
        remaining.insert(contentsOf:selected,at:destination-offsets.filter {$0<destination}.count)
        return Array(queue.prefix(head))+remaining
    }
    static func time(_ raw:Double) -> String {
        guard raw.isFinite,raw>=0,raw<Double(Int.max) else {return "0:00"}
        let value=Int(raw);return String(format:"%d:%02d",value/60,value%60)
    }
    static func downloadExtension(_ url:URL,mime:String?) throws -> String {
        let mime=(mime ?? "").lowercased(),ext=url.pathExtension.lowercased()
        if ext=="m3u8" || mime.contains("mpegurl") {
            throw AppError.network("Этот HLS-поток доступен для онлайн-прослушивания. Сохранение HLS в этой версии не поддерживается.")
        }
        guard !["text/html","application/json","text/plain"].contains(mime) else {throw AppError.decoding}
        if mime=="audio/mpeg" {return "mp3"}
        if mime=="audio/mp4" || mime=="video/mp4" {return "m4a"}
        guard ["mp3","m4a","aac","wav","aiff","aif","caf","flac"].contains(ext),
              mime.hasPrefix("audio/") || mime=="application/octet-stream" else {throw AppError.network("Сервер не предоставил поддерживаемый аудиофайл.")}
        return ext
    }
}
struct MusicLyricLine:Identifiable,Codable,Equatable {
    var time:Double
    var text:String
    var id:String {"\(time):\(text)"}
}
struct MusicLyrics:Codable,Equatable {
    var text:String
    var lines:[MusicLyricLine]
    var source:String
    static func parse(_ text:String,source:String="Файл LRC") -> MusicLyrics {
        let rows=text.components(separatedBy:.newlines)
        let offset=rows.compactMap {row -> Double? in
            guard row.lowercased().hasPrefix("[offset:"),let end=row.firstIndex(of:"]"),
                  let value=Double(row[row.index(row.startIndex,offsetBy:8)..<end]),value.isFinite,abs(value)<=3_600_000 else {return nil}
            return value/1000
        }.last ?? 0
        var parsed:[MusicLyricLine]=[],seen=Set<String>()
        for row in rows {
            var remainder=row.trimmingCharacters(in:.whitespaces.union(CharacterSet(charactersIn:"\u{feff}"))),times:[Double]=[]
            while remainder.first=="[",let end=remainder.firstIndex(of:"]") {
                let stamp=remainder[remainder.index(after:remainder.startIndex)..<end]
                let parts=stamp.split(separator:":",maxSplits:1)
                guard parts.count==2,let minutes=Double(parts[0]),let seconds=Double(parts[1]),
                      minutes.isFinite,seconds.isFinite,minutes>=0,minutes<=100_000,(0..<60).contains(seconds) else {break}
                times.append(max(0,minutes*60+seconds+offset))
                remainder=String(remainder[remainder.index(after:end)...]).trimmingCharacters(in:.whitespaces)
            }
            guard !times.isEmpty,!remainder.isEmpty else {continue}
            for time in times {
                let line=MusicLyricLine(time:time,text:remainder)
                if seen.insert(line.id).inserted {parsed.append(line)}
            }
        }
        parsed=parsed.enumerated().sorted {$0.element.time == $1.element.time ? $0.offset<$1.offset : $0.element.time<$1.element.time}.map(\.element)
        return MusicLyrics(text:parsed.isEmpty ? text : parsed.map(\.text).joined(separator:"\n"),lines:parsed,source:source)
    }
    func activeIndex(at time:Double) -> Int? {
        guard time.isFinite,!lines.isEmpty,time>=lines[0].time else {return nil}
        var low=0,high=lines.count
        while low<high {let middle=(low+high)/2;if lines[middle].time<=time {low=middle+1} else {high=middle}}
        return low-1
    }
}
struct MusicLyricsCandidate:Decodable {
    let trackName:String
    let artistName:String
    let duration:Double
    let plainLyrics:String?
    let syncedLyrics:String?
}
enum MusicLyricsLookup {
    static func key(_ text:String) -> String {
        text.folding(options:[.diacriticInsensitive,.caseInsensitive],locale:Locale(identifier:"en_US_POSIX"))
            .components(separatedBy:CharacterSet.alphanumerics.inverted).filter {!$0.isEmpty}.joined()
    }
    static func match(_ candidates:[MusicLyricsCandidate],track:LocalAudioTrack,duration:Double) -> MusicLyrics? {
        guard let artist=track.artist,!artist.isEmpty else {return nil}
        let matches=candidates.filter {key($0.trackName)==key(track.title) && key($0.artistName)==key(artist)}
            .sorted {abs($0.duration-duration)<abs($1.duration-duration)}
        for candidate in matches {
            if let synced=candidate.syncedLyrics,!synced.isEmpty,duration.isFinite,duration>0,
               candidate.duration.isFinite,abs(candidate.duration-duration)<=3 {
                let lyrics=MusicLyrics.parse(synced,source:"LRCLIB")
                if !lyrics.lines.isEmpty {return lyrics}
            }
            if let text=candidate.plainLyrics,!text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                return MusicLyrics(text:text,lines:[],source:"LRCLIB")
            }
        }
        return nil
    }
    static func fetch(track:LocalAudioTrack,duration:Double) async throws -> MusicLyrics {
        guard let artist=track.artist,!artist.isEmpty else {throw AppError.network("Укажите исполнителя или импортируйте файл LRC.")}
        var components=URLComponents(string:"https://lrclib.net/api/search")!
        components.queryItems=[URLQueryItem(name:"track_name",value:track.title),URLQueryItem(name:"artist_name",value:artist)]
        var request=URLRequest(url:components.url!);request.timeoutInterval=15
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        request.setValue("VKHIG/0.1",forHTTPHeaderField:"User-Agent")
        let config=URLSessionConfiguration.ephemeral;config.httpShouldSetCookies=false;config.httpCookieStorage=nil
        let session=URLSession(configuration:config);defer {session.finishTasksAndInvalidate()}
        let (data,response)=try await session.data(for:request)
        try Task.checkCancellation()
        guard let response=response as? HTTPURLResponse,response.statusCode==200,data.count<=2_000_000 else {throw AppError.network("Сервис текстов недоступен. Попробуйте позже или импортируйте LRC.")}
        let candidates=try JSONDecoder().decode([MusicLyricsCandidate].self,from:data)
        guard let lyrics=match(candidates,track:track,duration:duration) else {throw AppError.network("Подходящий текст не найден. Можно импортировать файл LRC.")}
        return lyrics
    }
}
@MainActor
final class LocalMusicEqualizer {
    private let engine=AVAudioEngine()
    private let node=AVAudioPlayerNode()
    private let eq=AVAudioUnitEQ(numberOfBands:10)
    private var file:AVAudioFile?
    private var startingFrame:AVAudioFramePosition=0
    private var revision=UUID()
    private var end:(()->Void)?
    var duration:Double {guard let file else {return 0};return Double(file.length)/file.processingFormat.sampleRate}
    var position:Double {
        guard let file else {return 0}
        let frames=node.lastRenderTime.flatMap {node.playerTime(forNodeTime:$0)}?.sampleTime ?? 0
        return min(duration,max(0,Double(startingFrame+frames)/file.processingFormat.sampleRate))
    }
    init() {engine.attach(node);engine.attach(eq)}
    func apply(_ settings:MusicEQSettings) {
        let value=settings.normalized;eq.globalGain=value.safePreamp
        for (index,band) in eq.bands.enumerated() {
            band.filterType = .parametric;band.frequency=min(MusicEQSettings.frequencies[index],Float((file?.processingFormat.sampleRate ?? 44100)*0.45))
            band.bandwidth=1;band.gain=value.gains[index];band.bypass=false
        }
    }
    func load(_ url:URL,position:Double,autoplay:Bool,settings:MusicEQSettings,end:@escaping ()->Void) throws {
        stop()
        let file=try AVAudioFile(forReading:url)
        guard file.processingFormat.sampleRate>0,file.length>0,file.length<=Int64(UInt32.max) else {throw AppError.network("Для этого файла эквалайзер недоступен. Отключите эквалайзер для обычного воспроизведения.")}
        self.file=file;self.end=end
        engine.disconnectNodeOutput(node);engine.disconnectNodeOutput(eq)
        engine.connect(node,to:eq,format:file.processingFormat)
        engine.connect(eq,to:engine.mainMixerNode,format:file.processingFormat)
        apply(settings)
        try engine.start();schedule(position)
        if autoplay {node.play()}
    }
    private func schedule(_ seconds:Double) {
        guard let file else {return}
        revision=UUID();let ticket=revision
        node.stop()
        let time=seconds.isFinite ? min(duration,max(0,seconds)) : 0
        startingFrame=min(file.length,AVAudioFramePosition(time*file.processingFormat.sampleRate))
        let count=file.length-startingFrame
        guard count>0 else {return}
        node.scheduleSegment(file,startingFrame:startingFrame,frameCount:AVAudioFrameCount(count),at:nil,completionCallbackType:.dataPlayedBack) { [weak self] _ in
            Task {@MainActor in guard let self,self.revision==ticket else {return};self.end?()}
        }
    }
    func seek(_ value:Double,playing:Bool) {schedule(value);if playing {node.play()}}
    func pause() {node.pause()}
    func resume() throws {if !engine.isRunning {try engine.start()};if position>=duration-0.05 {schedule(0)};node.play()}
    func stop() {revision=UUID();node.stop();engine.stop();file=nil;end=nil}
}
final class MusicHTTPSDelegate:NSObject,URLSessionDownloadDelegate,@unchecked Sendable {
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL) {}
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64) {
        if totalBytesWritten>MusicPolicy.maximumFileBytes || totalBytesExpectedToWrite>MusicPolicy.maximumFileBytes {downloadTask.cancel()}
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void) {
        completionHandler(MusicPolicy.safeRemote(request.url)==nil ? nil : request)
    }
}

struct VKAudioTrack:Identifiable,Equatable {
    let id:String
    let title:String
    let artist:String
    let duration:Int
    let url:URL?
    var album:String?=nil
    var artworkURL:URL?=nil
    var local:LocalAudioTrack? {
        url.map {LocalAudioTrack(id:id,title:title,url:$0,artist:artist,album:album,duration:Double(duration),artworkURL:artworkURL)}
    }
}
