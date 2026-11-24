import Foundation

enum WatchLinkConstants {
    static let urlScheme = "training-ciq"
    static let appId = UUID(uuidString: "15ee2aed-cd4c-457b-a6e0-cb1bc629a995")!
    static let commandHost = "relogio"
    static let pingPath = "ping"
    static let clearPath = "limpar"
    static let devicesKey = "watchLink.devices"
    static let sentPlansKey = "watchLink.sentPlans"
    static let daysToSend = 2
    static let logFile = "watch-link-log.json"
    static let eventsKey = "events"
    static let pingKey = "ping"
    static let pongKey = "pong"
    static let startedKey = "started"
    static let titleKey = "title"
    static let versionKey = "version"
    static let planKey = "plan"
    static let resyncKey = "resync"
    static let needPlansKey = "needPlans"
    static let needPlansNotification = Notification.Name("watchLink.needPlans")
    static let statusKey = "status"
    static let commandKey = "command"
    static let setWeightKind = "setWeight"
    static let exerciseIdKey = "exerciseId"
    static let weightKey = "weight"
    static let bodyweightKey = "bodyweight"
    static let nextOnlyKey = "nextOnly"
    static let ackKey = "ack"
    static let ackStartedKey = "ackStarted"
    static let finishedKey = "finished"
    static let savedKey = "saved"
    static let durationKey = "durationSeconds"
    static let averageHeartRateKey = "averageHeartRate"
    static let ackFinishedKey = "ackFinished"
    static let sequenceKey = "sequence"
    static let restorationId = "dev.aglv.training.connectiq"
    static let startedMaxAge: TimeInterval = 30 * 60
    static let startedNotificationId = "forca-ao-vivo-inicio"
    static let startedNotificationTitle = "Treino de força começou"
    static let startedNotificationText = "Toque para acompanhar no iPhone."
}
