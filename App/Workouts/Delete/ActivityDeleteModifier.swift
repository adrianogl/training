import SwiftUI

private typealias C = ActivityExclusionConstants

struct ActivityDeleteModifier: ViewModifier {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let activityId: Int64
    @Binding var isPresented: Bool
    @State private var failure: String?
    @State private var deleting = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog(C.confirmTitle, isPresented: $isPresented, titleVisibility: .visible) {
                Button(C.deleteTitle, role: .destructive) {
                    deleting = true
                    Task {
                        let result = await app.deleteActivity(activityId)
                        deleting = false
                        if let result { failure = result } else { dismiss() }
                    }
                }
                Button(C.cancel, role: .cancel) {}
            } message: {
                Text(app.isOwnActivity(activityId) ? C.confirmGarmin : C.confirmApp)
            }
            .alert(C.deleteTitle, isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .disabled(deleting)
    }
}

struct ActivityDeleteButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button(role: .destructive) { isPresented = true } label: {
            Label(C.deleteTitle, systemImage: C.deleteSymbol)
        }
    }
}

extension View {
    func activityDeletion(_ activityId: Int64, isPresented: Binding<Bool>) -> some View {
        modifier(ActivityDeleteModifier(activityId: activityId, isPresented: isPresented))
    }
}
