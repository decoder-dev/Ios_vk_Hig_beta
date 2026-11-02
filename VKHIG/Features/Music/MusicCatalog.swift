import Foundation
import Observation

@MainActor
@Observable
final class VKMusicCatalogModel {
    var tracks:[VKAudioTrack]=[]
    var loading=false
    var more=true
    var error:String?
    private var offset=0
    private var generation=UUID()
    private let request:(String,[String:String]) async throws -> VKJSON
    init(request:((String,[String:String]) async throws -> VKJSON)?=nil) {self.request=request ?? {try await VKCatalogService.shared.request($0,$1)}}
    func load(reset:Bool=true,grants:Set<String>) async {
        guard grants.contains("audio") else {error="VK не выдал музыкальные права этому приложению.";return}
        guard !loading else {return};loading=true;error=nil
        if reset {generation=UUID()}
        let ticket=generation
        defer {loading=false}
        do {
            let start=reset ? 0 : offset
            let response=try await request("audio.get",["count":"100","offset":String(start)])
            try Task.checkCancellation();guard ticket==generation else {return}
            let page=Self.map(response),rawCount=response.list.count
            var next=reset ? [] : tracks;var ids=Set(next.map(\.id));next+=page.filter {ids.insert($0.id).inserted}
            tracks=next
            // Like PrivateMusic2: skip malformed/ad objects without replaying their raw page.
            offset=start+rawCount
            if case .null=response["count"] {more=rawCount==100}
            else {more=rawCount>0 && Int64(offset)<response["count"].int}
        } catch is CancellationError {} catch {self.error=error.localizedDescription}
    }
    static func map(_ response:VKJSON) -> [VKAudioTrack] {
        response.list.compactMap {j in
            guard j["id"].int>0 else {return nil}
            let thumb=j["album"]["thumb"]
            let artwork=["photo_600","photo_300","photo_135"].compactMap {MusicPolicy.safeRemote(thumb[$0].url)}.first
            return VKAudioTrack(id:"audio\(j["owner_id"].int)_\(j["id"].int)",title:j["title"].string,artist:j["artist"].string,duration:max(0,Int(j["duration"].int)),url:MusicPolicy.safeRemote(j["url"].url),album:j["album"]["title"].string,artworkURL:artwork)
        }
    }
}
