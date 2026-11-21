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
        let notes = notes(in: release, after: installed, upTo: release.versao_app)
        return AppUpdate(latest: release.versao, installed: installed, notes: Array(notes.prefix(AppUpdateConstants.maxNotes)))
    }

    static func notes(in release: AppRelease, after previous: String, upTo version: String) -> [String] {
        let entries = release.historico ?? [AppReleaseNotes(versao: release.versao_app, notas: release.notas)]
        let notes = entries
            .filter { !isNewer($0.versao, than: version) && (previous.isEmpty || isNewer($0.versao, than: previous)) }
            .sorted { isNewer($0.versao, than: $1.versao) }
            .flatMap(\.notas)
        return notes.reduce(into: []) { unique, note in
            if !unique.contains(note) { unique.append(note) }
        }
    }

    static func summary(release: AppRelease?, installed: String) -> AppVersionSummary {
        guard let release else {
            return AppVersionSummary(installed: installed, latest: nil, hasUpdate: false, notesVersion: nil, notes: [])
        }
        let hasUpdate = isNewer(release.versao_app, than: installed)
        let ceiling = hasUpdate ? release.versao_app : installed
        let entries = release.historico ?? [AppReleaseNotes(versao: release.versao_app, notas: release.notas)]
        let entry = entries
            .filter { !isNewer($0.versao, than: ceiling) && !$0.notas.isEmpty }
            .max { isNewer($1.versao, than: $0.versao) }
        return AppVersionSummary(
            installed: installed, latest: release.versao_app, hasUpdate: hasUpdate,
            notesVersion: entry?.versao, notes: entry?.notas ?? []
        )
    }

    static func bundledRelease(_ bundle: Bundle = .main) -> AppRelease? {
        bundle.url(forResource: AppUpdateConstants.bundledResource, withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(AppRelease.self, from: $0) }
    }
}
