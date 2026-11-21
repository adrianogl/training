import Foundation

enum SettingsVersionText {
    static let title = "Versão"
    static let installed = "Instalada"
    static let latest = "Última"
    static let notesFormat = "Novidades da %@"
    static let updateFormat = "%@ · instale pelo Mac"
    static let bullet = "•"

    static func installedValue(version: String, build: String) -> String {
        build.isEmpty ? version : "\(version) (\(build))"
    }

    static func latestValue(_ summary: AppVersionSummary) -> String? {
        guard let latest = summary.latest else { return nil }
        return summary.hasUpdate ? String(format: updateFormat, latest) : latest
    }
}
