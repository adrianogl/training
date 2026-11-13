import UIKit
import UniformTypeIdentifiers

struct SystemKeyClipboard: KeyClipboard {
    func copy(_ key: String) {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: key]], options: Self.options(now: .now))
    }

    static func options(now: Date) -> [UIPasteboard.OptionsKey: Any] {
        [.localOnly: true, .expirationDate: now.addingTimeInterval(RemoteSyncSettingsConstants.clipboardLifetime)]
    }
}
