import Foundation
import CryptoKit

/// MD5 is required by VK's legacy `sig` scheme, not used for anything security-sensitive here.
enum VKMD5 {
    static func hex(_ string: String) -> String {
        Insecure.MD5.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
