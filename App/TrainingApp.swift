import SwiftUI
import UserNotifications

@main
struct TrainingApp: App {
    @State private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppConstants.appearanceDefaultsKey) private var appearance = AppearanceOption.system.rawValue

    init() {
        let session = AppSession.live()
        _session = State(initialValue: session)
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        BackgroundSync.register { session.model }
    }

    var body: some Scene {
        WindowGroup {
            SessionRootView(session: session)
                .preferredColorScheme(AppearanceOption(rawValue: appearance)?.colorScheme)
                .tint(BrandColors.accent)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                session.model?.activate()
            case .background:
                session.model?.enteredBackground()
            default:
                break
            }
        }
    }
}
