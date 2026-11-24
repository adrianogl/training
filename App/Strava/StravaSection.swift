import SwiftUI

struct StravaSection: View {
    let model: StravaModel
    @State private var confirmsDisconnect = false

    private typealias C = StravaConstants

    var body: some View {
        Section {
            if model.status.connected {
                LabeledContent(C.sectionTitle) {
                    Text(model.status.athleteName.isEmpty ? C.connectedAnonymous : String(format: C.connectedFormat, model.status.athleteName))
                        .foregroundStyle(BrandColors.accent)
                        .multilineTextAlignment(.trailing)
                }
                Toggle(C.toggleTitle, isOn: Binding(
                    get: { model.status.enabled },
                    set: { value in Task { await model.setEnabled(value) } }
                ))
                LabeledContent(C.formatTitle) { Text(C.formatName).foregroundStyle(BrandColors.dim) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(C.exampleTitle).font(.caption).foregroundStyle(BrandColors.dim)
                    Text(C.example).font(.footnote).foregroundStyle(BrandColors.text)
                }
                NavigationLink(StravaImportText.title) { StravaImportView(model: model) }
                Button(C.disconnect, role: .destructive) { confirmsDisconnect = true }
                    .disabled(model.phase == .working)
                    .confirmationDialog(C.disconnectTitle, isPresented: $confirmsDisconnect, titleVisibility: .visible) {
                        Button(C.disconnect, role: .destructive) { Task { await model.disconnect() } }
                        Button(C.cancel, role: .cancel) {}
                    } message: {
                        Text(C.disconnectMessage)
                    }
            } else {
                Button(model.phase == .working ? C.connecting : C.connect) { Task { await model.connect() } }
                    .disabled(model.phase == .working)
            }
            if let message = model.message {
                DSNotice(tone: .error, text: message)
            }
        } header: {
            DSSectionTitle(C.formTitle)
        } footer: {
            Text(C.footer)
        }
    }
}
