import Foundation

struct AppBuildInfo: Equatable {
    let version: String
    let build: String
    let commit: String?
    let builtAt: Date?

    init(version: String, build: String, commit: String?, builtAt: Date?) {
        self.version = version
        self.build = build
        self.commit = commit
        self.builtAt = builtAt
    }

    init(bundle: Bundle = .main) {
        typealias C = AppBuildInfoConstants
        let info = bundle.infoDictionary ?? [:]
        let commit = info[C.commitKey] as? String
        self.init(
            version: info[C.versionKey] as? String ?? "",
            build: info[C.buildKey] as? String ?? "",
            commit: commit?.isEmpty == false ? commit : nil,
            builtAt: (info[C.builtAtKey] as? String).flatMap { try? Date($0, strategy: .iso8601) }
                ?? bundle.executableURL.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        )
    }

    func footerLine(timeZone: TimeZone = .current) -> String? {
        let parts = [commit.map { String(format: AppBuildInfoConstants.commitFormat, $0) }, builtLine(timeZone: timeZone)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: AppBuildInfoConstants.separator)
    }

    func builtLine(timeZone: TimeZone = .current) -> String? {
        guard let builtAt else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.day, .month, .hour, .minute], from: builtAt)
        return String(format: AppBuildInfoConstants.builtFormat, parts.day ?? 0, parts.month ?? 0, parts.hour ?? 0, parts.minute ?? 0)
    }
}
