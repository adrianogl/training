import ConnectIQ
import Foundation
import Insights
import UIKit

@MainActor
final class WatchLink: NSObject {
    static let shared = WatchLink()

    private var devices: [IQDevice] = []
    private let log = JSONFileStore<WatchLinkRecord>(url: URL.documentsDirectory.appending(path: WatchLinkConstants.logFile))

    func start() {
        ConnectIQ.sharedInstance().initialize(withUrlScheme: WatchLinkConstants.urlScheme, uiOverrideDelegate: self, stateRestorationIdentifier: WatchLinkConstants.restorationId)
        devices = Self.storedDevices()
        register()
    }

    func handles(_ url: URL) -> Bool {
        if url.scheme == WatchLinkConstants.urlScheme {
            receiveSelection(url)
            return true
        }
        guard url.host() == WatchLinkConstants.commandHost else { return false }
        switch url.pathComponents.last {
        case WatchLinkConstants.pingPath: ping()
        case WatchLinkConstants.clearPath: try? log.mutate { $0.removeAll(); return true }
        default: ConnectIQ.sharedInstance().showDeviceSelection()
        }
        return true
    }

    func ping() {
        let sentAt = Int(Date().timeIntervalSince1970 * 1_000)
        for device in devices {
            let name = device.friendlyName ?? ""
            ConnectIQ.sharedInstance().sendMessage([WatchLinkConstants.pingKey: sentAt], to: app(for: device), progress: nil) { result in
                let value = result.rawValue
                Task { @MainActor in
                    self.record(.sent, detail: "ping \(name) result=\(value)")
                }
            }
        }
    }

    private func receiveSelection(_ url: URL) {
        let selected = (ConnectIQ.sharedInstance().parseDeviceSelectionResponse(from: url) as? [IQDevice]) ?? []
        guard !selected.isEmpty else { return }
        ConnectIQ.sharedInstance().unregister(forAllDeviceEvents: self)
        ConnectIQ.sharedInstance().unregister(forAllAppMessages: self)
        devices = selected
        Self.store(selected)
        record(.devices, detail: selected.map { "\($0.friendlyName ?? "") \($0.modelName ?? "")" }.joined(separator: ", "))
        register()
    }

    private func register() {
        for device in devices {
            ConnectIQ.sharedInstance().register(forDeviceEvents: device, delegate: self)
            ConnectIQ.sharedInstance().register(forAppMessages: app(for: device), delegate: self)
        }
    }

    private func app(for device: IQDevice) -> IQApp {
        IQApp(uuid: WatchLinkConstants.appId, store: WatchLinkConstants.appId, device: device)
    }

    private func receive(_ data: Data, at receivedAt: Date) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            record(.failure, detail: String(decoding: data, as: UTF8.self))
            return
        }
        if let sentAt = object[WatchLinkConstants.pongKey] as? Int {
            var entry = WatchLinkRecord(at: receivedAt, appState: Self.appState, kind: .pong, detail: "")
            entry.roundTripMs = Int(receivedAt.timeIntervalSince1970 * 1_000) - sentAt
            append(entry)
            return
        }
        if let startedAt = object[WatchLinkConstants.startedKey] as? Int {
            started(at: Date(timeIntervalSince1970: TimeInterval(startedAt)), title: object[WatchLinkConstants.titleKey] as? String, receivedAt: receivedAt)
            return
        }
        guard let raw = object[WatchLinkConstants.eventsKey],
              let eventsData = try? JSONSerialization.data(withJSONObject: raw),
              let events = try? LiveStrengthQueue.decodeWatchEvents(eventsData) else {
            record(.failure, detail: String(decoding: data, as: UTF8.self))
            return
        }
        var entry = WatchLinkRecord(at: receivedAt, appState: Self.appState, kind: .events, detail: "\(events.count)")
        entry.eventIds = events.map(\.id)
        entry.delaySeconds = events.compactMap { event in
            guard case let .setDone(_, result) = event.action, let start = result.start else { return nil }
            let concluded = start.addingTimeInterval(result.durationSeconds ?? 0)
            return receivedAt.timeIntervalSince(concluded)
        }
        append(entry)
    }

    private func started(at startedAt: Date, title: String?, receivedAt: Date) {
        var entry = WatchLinkRecord(at: receivedAt, appState: Self.appState, kind: .started, detail: title ?? "")
        entry.delaySeconds = [receivedAt.timeIntervalSince(startedAt)]
        append(entry)
        guard UIApplication.shared.applicationState != .active,
              receivedAt.timeIntervalSince(startedAt) < WatchLinkConstants.startedMaxAge else { return }
        Task {
            await UserNotificationScheduler().schedule(
                id: WatchLinkConstants.startedNotificationId,
                title: WatchLinkConstants.startedNotificationTitle,
                text: [title, WatchLinkConstants.startedNotificationText].compactMap { $0 }.joined(separator: " · "),
                link: DeepLinkConstants.trainerStrength,
                at: nil
            )
        }
    }

    private func record(_ kind: WatchLinkRecordKind, detail: String) {
        append(WatchLinkRecord(at: Date(), appState: Self.appState, kind: kind, detail: detail))
    }

    private func append(_ entry: WatchLinkRecord) {
        try? log.mutate { $0.append(entry); return true }
    }

    private static var appState: String {
        switch UIApplication.shared.applicationState {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }

    private static func storedDevices() -> [IQDevice] {
        guard let data = UserDefaults.standard.data(forKey: WatchLinkConstants.devicesKey) else { return [] }
        let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver?.requiresSecureCoding = false
        return (unarchiver?.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? [IQDevice]) ?? []
    }

    private static func store(_ devices: [IQDevice]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: devices, requiringSecureCoding: false) else { return }
        UserDefaults.standard.set(data, forKey: WatchLinkConstants.devicesKey)
    }
}

extension WatchLink: IQUIOverrideDelegate, IQDeviceEventDelegate, IQAppMessageDelegate {
    nonisolated func needsToInstallConnectMobile() {
        Task { @MainActor in self.record(.failure, detail: "Garmin Connect não instalado") }
    }

    nonisolated func deviceStatusChanged(_ device: IQDevice!, status: IQDeviceStatus) {
        let name = device?.friendlyName ?? ""
        let value = status.rawValue
        Task { @MainActor in self.record(.status, detail: "\(name) status=\(value)") }
    }

    nonisolated func receivedMessage(_ message: Any!, from app: IQApp!) {
        let receivedAt = Date()
        guard let message, JSONSerialization.isValidJSONObject(message),
              let data = try? JSONSerialization.data(withJSONObject: message) else {
            Task { @MainActor in self.record(.failure, detail: "mensagem inválida") }
            return
        }
        if let reply = Self.acknowledgement(for: message), let app {
            ConnectIQ.sharedInstance().sendMessage(reply, to: app, progress: nil, completion: nil)
        }
        Task { @MainActor in self.receive(data, at: receivedAt) }
    }

    nonisolated private static func acknowledgement(for message: Any) -> [String: Int]? {
        guard let object = message as? [String: Any] else { return nil }
        if object[WatchLinkConstants.startedKey] != nil {
            return [WatchLinkConstants.ackStartedKey: 1]
        }
        guard let events = object[WatchLinkConstants.eventsKey] as? [[String: Any]] else { return nil }
        let last = events.compactMap { $0[WatchLinkConstants.sequenceKey] as? Int }.max()
        return last.map { [WatchLinkConstants.ackKey: $0] }
    }
}
