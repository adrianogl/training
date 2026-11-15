import SwiftUI

struct SessionRootView: View {
    let session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsIntro = ProcessInfo.processInfo.environment[AppConstants.testHostEnvironmentVariable] == nil

    var body: some View {
        Group {
            if let model = session.model {
                RootView()
                    .environment(model)
                    .modelContainer(model.container)
                    .defaultAppStorage(model.scope.defaults)
                    .id(model.scope.id)
            } else {
                AccountGateView(model: session.account)
            }
        }
        .overlay {
            if showsIntro {
                IntroView().transition(.opacity)
            }
        }
        .onChange(of: session.model?.scope.id) { _, id in
            guard id != nil, scenePhase == .active else { return }
            session.model?.activate()
        }
        .task {
            guard showsIntro else { return }
            try? await Task.sleep(for: reduceMotion ? AppConstants.introReducedMotionDuration : AppConstants.introDuration)
            withAnimation(.easeOut(duration: AppConstants.introFadeSeconds)) { showsIntro = false }
        }
    }
}
