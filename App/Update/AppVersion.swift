import Foundation

enum AppVersion {
    static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }

    static func isNewer(_ candidate: String, than installed: String) -> Bool {
        let lhs = parts(candidate)
        let rhs = parts(installed)
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    static func update(for release: AppRelease, installed: String) -> AppUpdate? {
        guard isNewer(release.versao_app, than: installed) else { return nil }
        return AppUpdate(latest: release.versao, installed: installed, notes: Array(release.notas.prefix(AppUpdateConstants.maxNotes)))
    }
}
