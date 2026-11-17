import Foundation
import Testing
@testable import trAIning

@Suite struct FreshInstallTests {
    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: "fresh-install-\(UUID().uuidString)")!
    }

    private static func folder(withFile: Bool) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "support-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        if withFile { try Data().write(to: url.appending(path: "Accounts")) }
        return url
    }

    @Test func newInstallClearsTheKeychainOnce() throws {
        let defaults = Self.defaults()
        let support = try Self.folder(withFile: false)
        var cleared = 0

        FreshInstall.clearLeftoverKeychain(defaults: defaults, support: support) { cleared += 1 }
        FreshInstall.clearLeftoverKeychain(defaults: defaults, support: support) { cleared += 1 }

        #expect(cleared == 1)
    }

    @Test func updateOfAnExistingInstallKeepsTheKeychain() throws {
        var cleared = 0

        FreshInstall.clearLeftoverKeychain(defaults: Self.defaults(), support: try Self.folder(withFile: true)) { cleared += 1 }

        #expect(cleared == 0)
    }
}
