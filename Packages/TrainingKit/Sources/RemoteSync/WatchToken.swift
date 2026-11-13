import CryptoKit
import Foundation

public enum WatchToken {
    public static func generate() -> String {
        Base64URL.encode(SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) })
    }

    public static func hash(_ token: String) -> String? {
        guard let raw = Base64URL.decode(token), raw.count == RemoteSyncConstants.syncKeyByteCount, Base64URL.encode(raw) == token else {
            return nil
        }
        return SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
    }
}
