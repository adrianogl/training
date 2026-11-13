import CryptoKit
import Foundation
import Storage
import Testing
@testable import RemoteSync

@Suite struct RemoteKeysTests {
    private static let vectorSyncKey = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"

    @Test func derivesFixedVector() throws {
        let keys = try RemoteKeys(syncKey: Self.vectorSyncKey)

        #expect(keys.bearer == "M9jNxgbJ9wEyyyGJTzrDGTbjcEa8kudkDe3tjwXqEco")
        let payload = keys.payload.withUnsafeBytes { Data($0) }
        #expect(payload.map { String(format: "%02x", $0) }.joined() == "4a8af778fa48f689da2e6c006fc6ca5a80e40b30b5751bca4b8090bec7d1c170")
    }

    @Test func generatedKeyIsBase64URLWithoutPadding() throws {
        let key = RemoteKeys.generateSyncKey()

        #expect(key.count == 43)
        #expect(!key.contains("=") && !key.contains("+") && !key.contains("/"))
        #expect(key != RemoteKeys.generateSyncKey())
        #expect(try RemoteKeys(syncKey: key).bearer.count == 43)
    }

    @Test func acceptsSurroundingWhitespace() throws {
        #expect(try RemoteKeys(syncKey: "  \(Self.vectorSyncKey)\n").bearer == "M9jNxgbJ9wEyyyGJTzrDGTbjcEa8kudkDe3tjwXqEco")
    }

    @Test func rejectsInvalidKeys() {
        for text in ["", "abc", Self.vectorSyncKey + "AA", "!!!!", String(Self.vectorSyncKey.dropLast())] {
            #expect(throws: RemoteSyncError.invalidSyncKey) { try RemoteKeys(syncKey: text) }
        }
    }
}

@Suite struct RemotePayloadTests {
    private let keys = try! RemoteKeys(syncKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")

    @Test func raceRoundTrips() throws {
        let race = RaceRecord(
            name: "Meia sintética", day: "2026-12-01", distance: 21_097.5, startTime: "07:00", goalSeconds: 6_300,
            priority: .a, city: "Cidade", gpxData: Data([1, 2, 3]), resultActivityId: 77, manuallyUnlinked: true,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000.25)
        )

        let sealed = try RemotePayload.seal(race: race, key: keys.payload)
        let opened = try RemotePayload.openRace(sealed, id: race.id.uuidString, key: keys.payload)

        #expect(opened == RaceTransferItem(race))
        #expect(!sealed.contains("sintética"))
        #expect(Data(base64Encoded: sealed) != nil)
    }

    @Test func decisionRoundTrips() throws {
        let decision = RaceDecisionRecord(activityId: 123, decision: .notRace)

        let sealed = try RemotePayload.seal(decision: decision, key: keys.payload)

        #expect(try RemotePayload.openDecision(sealed, id: "123", key: keys.payload) == RemoteDecisionPayload(activityId: 123, decision: "notRace"))
    }

    @Test func sameRecordSealsDifferently() throws {
        let decision = RaceDecisionRecord(activityId: 1, decision: .race)

        #expect(try RemotePayload.seal(decision: decision, key: keys.payload) != RemotePayload.seal(decision: decision, key: keys.payload))
    }

    @Test func tamperedPayloadThrows() throws {
        let sealed = try RemotePayload.seal(decision: RaceDecisionRecord(activityId: 1, decision: .race), key: keys.payload)
        var bytes = try #require(Data(base64Encoded: sealed))
        bytes[bytes.count - 1] ^= 0x01

        #expect(throws: RemoteSyncError.tamperedPayload) {
            try RemotePayload.openDecision(bytes.base64EncodedString(), id: "1", key: keys.payload)
        }
        #expect(throws: RemoteSyncError.tamperedPayload) {
            try RemotePayload.openDecision("não é base64", id: "1", key: keys.payload)
        }
    }

    @Test func payloadMovedToAnotherRecordThrows() throws {
        let race = RaceRecord(name: "Prova", day: "2026-12-01", distance: 10_000)
        let sealedRace = try RemotePayload.seal(race: race, key: keys.payload)
        let sealedDecision = try RemotePayload.seal(decision: RaceDecisionRecord(activityId: 1, decision: .race), key: keys.payload)

        #expect(throws: RemoteSyncError.tamperedPayload) {
            try RemotePayload.openRace(sealedRace, id: UUID().uuidString, key: keys.payload)
        }
        #expect(throws: RemoteSyncError.tamperedPayload) {
            try RemotePayload.openDecision(sealedDecision, id: "2", key: keys.payload)
        }
    }

    @Test func wrongKeyThrows() throws {
        let sealed = try RemotePayload.seal(decision: RaceDecisionRecord(activityId: 1, decision: .race), key: keys.payload)
        let other = try RemoteKeys(syncKey: RemoteKeys.generateSyncKey())

        #expect(throws: RemoteSyncError.tamperedPayload) {
            try RemotePayload.openDecision(sealed, id: "1", key: other.payload)
        }
    }
}

@Suite struct RemoteMergeTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func newerRemoteReplacesLocal() {
        #expect(RemoteMerge.action(remoteUpdatedAt: base.addingTimeInterval(0.002), remoteDeleted: false, localUpdatedAt: base) == .replace)
    }

    @Test func newerRemoteTombstoneDeletesLocal() {
        #expect(RemoteMerge.action(remoteUpdatedAt: base.addingTimeInterval(1), remoteDeleted: true, localUpdatedAt: base) == .delete)
    }

    @Test func olderOrEqualRemoteKeepsLocal() {
        #expect(RemoteMerge.action(remoteUpdatedAt: base.addingTimeInterval(-1), remoteDeleted: false, localUpdatedAt: base) == .keepLocal)
        #expect(RemoteMerge.action(remoteUpdatedAt: base, remoteDeleted: true, localUpdatedAt: base) == .keepLocal)
    }

    @Test func sameMillisecondIsATie() {
        let local = base.addingTimeInterval(0.0001)
        #expect(RemoteMerge.action(remoteUpdatedAt: base, remoteDeleted: false, localUpdatedAt: local) == .keepLocal)
    }

    @Test func missingLocalInsertsOrIgnoresTombstone() {
        #expect(RemoteMerge.action(remoteUpdatedAt: base, remoteDeleted: false, localUpdatedAt: nil) == .insert)
        #expect(RemoteMerge.action(remoteUpdatedAt: base, remoteDeleted: true, localUpdatedAt: nil) == .ignore)
    }
}

@Suite struct RemoteTimestampTests {
    @Test func encodesUTCWithMilliseconds() {
        #expect(RemoteTimestamp.string(from: Date(timeIntervalSince1970: 1_800_000_000.1234)) == "2027-01-15T08:00:00.123Z")
        #expect(RemoteTimestamp.string(from: Date(timeIntervalSince1970: 1_800_000_000)) == "2027-01-15T08:00:00.000Z")
    }

    @Test func parsesWithAndWithoutFraction() throws {
        let withFraction = try #require(RemoteTimestamp.date(from: "2027-01-15T08:00:00.123Z"))
        #expect(RemoteTimestamp.milliseconds(withFraction) == 1_800_000_000_123)
        let plain = try #require(RemoteTimestamp.date(from: "2027-01-15T08:00:00Z"))
        #expect(RemoteTimestamp.milliseconds(plain) == 1_800_000_000_000)
        #expect(RemoteTimestamp.date(from: "ontem") == nil)
    }

    @Test func recordJSONUsesContractShape() throws {
        let record = RemoteRecord(kind: .race, id: "A", updatedAt: Date(timeIntervalSince1970: 1_800_000_000.5), deleted: true, payload: nil)

        let json = try #require(String(data: try RemoteJSON.encoder().encode(record), encoding: .utf8))

        #expect(json == #"{"deleted":true,"id":"A","kind":"race","payload":null,"updatedAt":"2027-01-15T08:00:00.500Z"}"#)
    }
}
