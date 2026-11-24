import SwiftUI

struct SessionRootView: View {
    let session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsIntro = ProcessInfo.processInfo.environment[AppConstants.testHostEnvironmentVariable] == nil && IntroPolicy.shows()

    var body: some View {
        Group {
            if let model = session.model {
                RootView()
                    .environment(model)
                    .environment(model.notices)
                    .environment(\.exerciseFeedbackStore, model.exerciseFeedback)
                    .environment(\.exerciseNotesStore, model.exerciseNotes)
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
        .onOpenURL { url in
            if let link = AccountLink(url: url) { session.account.pendingLink = link }
        }
        .sheet(item: Bindable(session.account).pendingLink) { link in
            AccountLinkSheet(model: session.account, link: link)
        }
        .onChange(of: session.model?.scope.id) { _, id in
            guard id != nil, scenePhase == .active else { return }
            session.model?.activate(force: true)
        }
        .task {
            guard showsIntro else { return }
            try? await Task.sleep(for: reduceMotion ? AppConstants.introReducedMotionDuration : AppConstants.introDuration)
            withAnimation(.easeOut(duration: AppConstants.introFadeSeconds)) { showsIntro = false }
        }
    }
}
