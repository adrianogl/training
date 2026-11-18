import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct DesignSystemSnapshotTests {
    @Test func elementsRender() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let catalog = VStack(alignment: .leading, spacing: 14) {
            DSSectionTitle("Botões")
            Button("Enviar ao relógio") {}.buttonStyle(.ds(.primary))
            Button("Gerar treino de força") {}.buttonStyle(.ds(.secondary))
            HStack {
                Button("Ver todas as metas") {}.buttonStyle(.ds(.text))
                Spacer()
                Button("Apagar meta") {}.buttonStyle(.ds(.destructive))
            }
            DSSectionTitle("Chips")
            HStack(spacing: 6) {
                DSChip(text: "Planejado")
                DSChip(text: "Novo", tone: .accent, style: .solid)
                DSChip(text: "No ritmo", tone: .accent)
                DSChip(text: "Atrasada", tone: .attention)
                DSChip(text: "Sobrecarga", tone: .danger)
            }
            HStack(spacing: 6) {
                DSChip(text: "Força", tone: .strength)
                DSChip(text: "Prova A", tone: .race)
                DSChip(text: "Forma", tone: .fitness)
                DSChip(text: "Claude", tone: .claude)
            }
            DSSectionTitle("Avisos")
            DSNotice(tone: .success, title: "Ciclo concluído", text: "Meia de Floripa em 1:42:10, 2 min abaixo da meta.", trailing: CardLinkBadge())
            DSNotice(tone: .attention, title: "Carga alta", text: "Aguda 38% acima da crônica. Faça a rodagem leve hoje.")
            DSNotice(tone: .error, text: "Garmin desconectado. Entre de novo em Ajustes › Garmin.")
            DSNotice(tone: .info, title: "Noite sem dados", text: "O relógio não registrou o sono.")
            DSSectionTitle("Estados")
            VStack(alignment: .leading) {
                DSCardLabel("Provas")
                DSEmptyState(symbol: "flag.checkered", title: "Nenhuma prova cadastrada", text: "Cadastre a próxima prova para ver a previsão e a estratégia.", actionTitle: "Nova prova") {}
            }
            .brandCard()
            DSErrorState(title: "Não conectou ao Garmin", text: "Confira a internet e tente de novo.") {}
                .brandCard()
        }
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: catalog.padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "ds-elements-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
    }
}
