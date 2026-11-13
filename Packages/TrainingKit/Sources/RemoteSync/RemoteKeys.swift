import CryptoKit
import Foundation

public struct RemoteKeys: Sendable {
    public let account: Data
    public let payload: SymmetricKey

    public var bearer: String { Base64URL.encode(account) }

    public init(syncKey: String) throws {
        typealias C = RemoteSyncConstants
        let trimmed = syncKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Base64URL.decode(trimmed), raw.count == C.syncKeyByteCount, Base64URL.encode(raw) == trimmed else {
            throw RemoteSyncError.invalidSyncKey
        }
        let input = SymmetricKey(data: raw)
        account = HKDF<SHA256>.deriveKey(inputKeyMaterial: input, salt: C.hkdfSalt, info: C.accountInfo, outputByteCount: C.derivedKeyByteCount)
            .withUnsafeBytes { Data($0) }
        payload = HKDF<SHA256>.deriveKey(inputKeyMaterial: input, salt: C.hkdfSalt, info: C.payloadInfo, outputByteCount: C.derivedKeyByteCount)
    }

    public static func generateSyncKey() -> String {
        Base64URL.encode(SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) })
    }
}
