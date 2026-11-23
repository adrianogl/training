import Foundation

enum WatchLinkConstants {
    static let urlScheme = "training-ciq"
    static let appId = UUID(uuidString: "15ee2aed-cd4c-457b-a6e0-cb1bc629a995")!
    static let commandHost = "relogio"
    static let pingPath = "ping"
    static let clearPath = "limpar"
    static let devicesKey = "watchLink.devices"
    static let logFile = "watch-link-log.json"
    static let eventsKey = "events"
    static let pingKey = "ping"
    static let pongKey = "pong"
}
