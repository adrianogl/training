import SwiftUI

@main
struct TrainingApp: App {
    @State private var model = AppModel.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .preferredColorScheme(.dark)
                .tint(BrandColors.accent)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active where model.autoSyncEnabled:
                Task { await model.syncNow() }
            case .background:
                model.cancelSync()
            default:
                break
            }
        }
    }
}
