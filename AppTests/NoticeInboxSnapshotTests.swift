import SwiftUI
import Testing
import UIKit
@testable import trAIning

@MainActor
@Suite struct NoticeInboxSnapshotTests {
    private func sampleInbox() -> NoticeInboxModel {
        let now = Date.now
        let store = NoticeInboxStore(defaults: UserDefaults(suiteName: "NoticeInboxSnapshotTests.\(UUID().uuidString)")!, now: { now })
        store.record(id: "plan-old", title: "Plano atualizado", text: "Limiar de 19/11 fora do alvo", link: DeepLinkConstants.trainerChanges, at: now.addingTimeInterval(-5 * 86_400))
        store.record(id: "workout", title: "Rodagem 12 km · nota 95", text: "12,3 km a 4:52 /km", link: DeepLink.workoutURL(1), at: now.addingTimeInterval(-6 * 86_400))
        store.markAllRead()
        store.record(id: "claude", title: "2 treinos de força do Claude", text: "Prontos para revisar e aplicar no Treinador.", link: DeepLinkConstants.trainerStrength, at: now.addingTimeInterval(-3_600))
        store.record(id: "strava", title: "Strava desconectado", text: "Entre de novo em Ajustes para continuar enviando as corridas.", link: DeepLinkConstants.settings, at: now.addingTimeInterval(-1_800))
        store.record(id: "plan", title: "Plano atualizado", text: "Semana leve antecipada: HRV, FC de repouso e sono fora do seu normal.", link: DeepLinkConstants.trainerChanges, at: now.addingTimeInterval(-600))
        return NoticeInboxModel(store: store)
    }

    private func render<V: View>(_ view: V, size: CGSize, name: String, dir: String) async throws {
        let host = UIHostingController(rootView: view)
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(800))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try image.pngData()?.write(to: URL(filePath: dir).appending(path: name))
        window.isHidden = true
    }

    @Test func bellAndSheet() async throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let inbox = sampleInbox()
        let header = VStack {
            DSScreenHeader(title: "Treinos") {
                EmptyView()
            } trailing: {
                Button {} label: { Label("Plano", systemImage: "list.bullet.clipboard").font(.subheadline.weight(.semibold)) }
                    .buttonStyle(.bordered).tint(BrandColors.accent).controlSize(.small)
            }
            Spacer()
        }
        .padding(.horizontal, BrandConstants.screenPadding)
        .padding(.top, 60)
        .background(BrandBackground())
        .environment(inbox)
        .environment(\.horizontalSizeClass, .compact)
        try await render(header.environment(\.colorScheme, .dark), size: CGSize(width: 440, height: 260), name: "avisos-sino-escuro.png", dir: dir)
        try await render(NoticeInboxView(inbox: inbox).environment(\.colorScheme, .dark), size: CGSize(width: 440, height: 956), name: "avisos-sheet-escuro.png", dir: dir)
        try await render(NoticeInboxView(inbox: inbox).environment(\.colorScheme, .light), size: CGSize(width: 700, height: 900), name: "avisos-sheet-claro.png", dir: dir)
        try await render(NoticeInboxView(inbox: NoticeInboxModel(store: NoticeInboxStore(defaults: UserDefaults(suiteName: "empty.\(UUID().uuidString)")!))).environment(\.colorScheme, .dark), size: CGSize(width: 440, height: 500), name: "avisos-vazio.png", dir: dir)
    }
}
