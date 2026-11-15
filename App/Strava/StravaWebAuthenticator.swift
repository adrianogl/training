import AuthenticationServices
import UIKit

@MainActor final class StravaWebAuthenticator: NSObject, StravaWebAuthenticating, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(StravaConstants.callbackScheme)) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: error ?? URLError(.cancelled))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            session.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        if let window = windows.first(where: \.isKeyWindow) ?? windows.first { return window }
        return ASPresentationAnchor(windowScene: scenes[0])
    }
}
