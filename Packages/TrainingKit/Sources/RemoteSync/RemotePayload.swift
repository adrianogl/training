import CryptoKit
import Foundation
import Storage

public enum RemotePayload {
    public static func seal(race: RaceRecord, key: SymmetricKey) throws -> String {
        try seal(race: RaceTransferItem(race), key: key)
    }

    public static func seal(race item: RaceTransferItem, key: SymmetricKey) throws -> String {
        try seal(item, context: context(.race, item.id.uuidString), key: key)
    }

    public static func seal(decision: RaceDecisionRecord, key: SymmetricKey) throws -> String {
        try seal(
            RemoteDecisionPayload(activityId: decision.activityId, decision: decision.decision),
            context: context(.decision, String(decision.activityId)),
            key: key
        )
    }

    public static func openRace(_ text: String, id: String, key: SymmetricKey) throws -> RaceTransferItem {
        try open(text, context: context(.race, id), key: key)
    }

    public static func openDecision(_ text: String, id: String, key: SymmetricKey) throws -> RemoteDecisionPayload {
        try open(text, context: context(.decision, id), key: key)
    }

    private static func context(_ kind: RemoteRecordKind, _ id: String) -> Data {
        Data("\(kind.rawValue):\(id)".utf8)
    }

    private static func seal(_ value: some Encodable, context: Data, key: SymmetricKey) throws -> String {
        let plaintext = try RemoteJSON.encoder().encode(value)
        guard let combined = try AES.GCM.seal(plaintext, using: key, authenticating: context).combined else {
            throw RemoteSyncError.tamperedPayload
        }
        return combined.base64EncodedString()
    }

    private static func open<Value: Decodable>(_ text: String, context: Data, key: SymmetricKey) throws -> Value {
        guard let combined = Data(base64Encoded: text),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let plaintext = try? AES.GCM.open(box, using: key, authenticating: context)
        else { throw RemoteSyncError.tamperedPayload }
        do {
            return try RemoteJSON.decoder().decode(Value.self, from: plaintext)
        } catch {
            throw RemoteSyncError.decoding
        }
    }
}
