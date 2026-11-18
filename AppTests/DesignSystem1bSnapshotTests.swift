import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct DesignSystem1bSnapshotTests {
    @Test func elementsRender() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let catalog = VStack(alignment: .leading, spacing: 12) {
            DSScreenHeader(title: "Provas") {
                DSChip(text: "Sincronizado agora", tone: .neutral)
            } trailing: {
                DSAddButton(label: "Nova prova") {}
            }
            DSSectionTitle("Números")
            HStack(spacing: 8) {
                DSStat(value: "11,3", label: "km")
                DSStat(value: "4:47", label: "pace /km")
                DSStat(value: "158", label: "FC média", color: BrandColors.attention)
            }
            .brandCard()
            HStack(spacing: 8) {
                DSStat(value: "32", label: "km na semana", boxed: true)
                DSStat(value: "3/5", label: "treinos", boxed: true)
            }
            HStack(spacing: 12) {
                DSDelta(text: "+1 em 30 dias", trend: .better)
                DSDelta(text: "-0,4 km/sem", trend: .worse)
                DSDelta(text: "estável", trend: .same)
            }
            DSSectionTitle("Barras e legendas")
            VStack(alignment: .leading, spacing: 10) {
                DSProgressBar(value: 0.72)
                DSProgressBar(value: 0.55, height: 8, marker: 0.8)
                DSProgressBar(value: 0.3, color: BrandColors.attention)
                HStack(spacing: 10) {
                    DSLegendItem(text: "pace", color: BrandColors.accentFill)
                    DSLegendItem(text: "plano", color: BrandColors.dim, mark: .dashed)
                    DSLegendItem(text: "70+", color: BrandColors.ready, mark: .square)
                }
            }
            .brandCard()
            DSSectionTitle("Filtros e linhas")
            HStack(spacing: 6) {
                DSFilterChip(title: "Todos", isSelected: true) {}
                DSFilterChip(title: "Longão") {}
                DSFilterChip(title: "Tiros") {}
            }
            VStack(spacing: 12) {
                DSRow(title: "Força", subtitle: "2 sessões · seg e qui", accessory: .link)
                Divider()
                DSRow(title: "Ajustes do plano", subtitle: "Força 2x · longão em blocos", accessory: .disclosure(expanded: false))
                Divider()
                DSRow(title: "Meta semanal", accessory: .link) { Text("40 km").font(.caption).foregroundStyle(BrandColors.dim) }
            }
            .brandCard()
            DSAIMark(text: "texto gerado no aparelho")
        }
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: catalog.padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "ds-1b-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
    }
}
