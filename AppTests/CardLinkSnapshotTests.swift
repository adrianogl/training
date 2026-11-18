import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct CardLinkSnapshotTests {
    @Test func linkCardsRender() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let sample = VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Prontidão").padding(.top, 0).padding(.bottom, 0)
                Text("78").font(BrandFonts.number(34)).foregroundStyle(BrandColors.text)
                Text("Pronto para treino de qualidade.").font(.footnote).foregroundStyle(BrandColors.dim)
                CardLinkFooter(title: CardLinkConstants.details)
            }
            .brandCard()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("sáb, 22 de nov.").font(.caption).foregroundStyle(BrandColors.dim)
                    Text("Live! Run XP").font(.headline).foregroundStyle(BrandColors.text)
                }
                Spacer()
                Text("10 km").font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
                CardLinkBadge()
            }
            .brandCard()
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Carga").padding(.top, 0).padding(.bottom, 0)
                Text("Aguda 1.111 · estável").font(.footnote).foregroundStyle(BrandColors.dim)
            }
            .brandCard()
            HStack {
                Text("Bloco 2 · 5×1 km").font(.subheadline).foregroundStyle(BrandColors.text)
                Spacer()
                CardDisclosure(expanded: false)
            }
            .brandCard()
        }
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: sample.padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "card-link-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
    }
}
