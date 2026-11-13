import LocalAuthentication

struct DeviceOwnerAuthenticator: DeviceOwnerAuthenticating {
    func authenticate(reason: String) async -> DeviceOwnerResult {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return .unavailable }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true ? .granted : .denied
    }
}
