import SwiftUI
import UIKit

struct ClaudeSettingsSection: View {
    let model: RemoteSyncModel
    @State private var token: String?
    @State private var copied: String?

    var body: some View {
        Section {
            Text(ClaudeText.settingsIntro).font(.footnote).foregroundStyle(BrandColors.dim)
            if model.status == .off {
                Text(ClaudeText.needsSync).font(.footnote).foregroundStyle(BrandColors.attention)
            }
            if let token {
                snippet(ClaudeText.codeTitle, ClaudeText.codeCommand(token: token), button: ClaudeText.copyCommand)
                snippet(ClaudeText.desktopTitle, ClaudeText.desktopConfig(token: token), button: ClaudeText.copyConfig)
                Text(ClaudeText.tokenOnce).font(.caption).foregroundStyle(BrandColors.attention)
            } else if let created = model.mcpTokenCreatedAt {
                Text(String(format: ClaudeText.activeSinceFormat, created.formatted(date: .abbreviated, time: .shortened)))
                    .font(.footnote).foregroundStyle(BrandColors.text)
            } else {
                Text(ClaudeText.noToken).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            Button(model.mcpTokenCreatedAt == nil ? ClaudeText.generateToken : ClaudeText.regenerateToken) {
                Task { token = await model.generateMcpToken() }
            }
            .disabled(model.isWorking || model.status == .off)
            if model.mcpTokenCreatedAt != nil {
                Button(ClaudeText.revokeToken, role: .destructive) {
                    Task {
                        await model.revokeMcpToken()
                        token = nil
                    }
                }
                .disabled(model.isWorking)
            }
            if let error = model.mcpError {
                Text(error).font(.footnote).foregroundStyle(BrandColors.danger)
            }
        }
    }

    private func snippet(_ title: String, _ text: String, button: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(BrandColors.dim)
            Text(text).font(.system(.caption2, design: .monospaced)).foregroundStyle(BrandColors.text).textSelection(.enabled)
            Button(copied == title ? ClaudeText.copiedShort : button) {
                UIPasteboard.general.string = text
                copied = title
            }
            .font(.footnote.weight(.semibold))
        }
    }
}
