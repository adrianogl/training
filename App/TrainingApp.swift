import SwiftUI
import UserNotifications

@main
struct TrainingApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppConstants.appearanceDefaultsKey) private var appearance = AppearanceOption.system.rawValue

    init() {
        let model = AppModel.live()
        _model = State(initialValue: model)
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        BackgroundSync.register(model: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .preferredColorScheme(AppearanceOption(rawValue: appearance)?.colorScheme)
                .tint(BrandColors.accent)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active where model.autoSyncEnabled:
                Task { await model.appBecameActive() }
            case .background:
                model.enteredBackground()
            default:
                break
            }
        }
    }
}
