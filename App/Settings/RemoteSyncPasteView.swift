import SwiftUI

struct RemoteSyncPasteView: View {
    typealias C = RemoteSyncSettingsConstants
    let model: RemoteSyncModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                TextField(C.pastePlaceholder, text: $text, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let error = model.pasteError ?? (text.isEmpty ? nil : RemoteSyncModel.check(text)) {
                    Text(error).font(.footnote).foregroundStyle(BrandColors.danger)
                }
            } footer: {
                Text(C.pasteHint)
            }
            Section {
                LabeledContent(C.localRacesLabel, value: "\(model.localCounts().races)")
                LabeledContent(C.mergeLabel, value: C.mergeValue)
            } header: {
                Text(C.pasteSection)
            } footer: {
                Text(C.mergeNote)
            }
            Section {
                Button {
                    Task {
                        if await model.connect(text) { dismiss() }
                    }
                } label: {
                    Text(model.isWorking ? C.connecting : C.connect)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(BrandColors.onAccent)
                .disabled(model.isWorking || RemoteSyncModel.check(text) != nil)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .navigationTitle(C.pasteTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: text) { model.clearPasteError() }
    }
}
