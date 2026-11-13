import SwiftUI
import WorkoutAnalysis

struct ShareEditorView: View {
    let input: WorkoutShareInput
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ShareConstants.templateDefaultsKey) private var template: ShareTemplate = .storiesDark
    @AppStorage(ShareConstants.fieldsDefaultsKey) private var fieldsText = ShareField.encode(ShareField.defaultEnabled)
    @State private var image: UIImage?

    private var enabled: Set<ShareField> { ShareField.decode(fieldsText) }
    private var content: ShareContent { shareContent(record: input, enabled: enabled, template: template) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("Modelo", selection: $template) {
                        ForEach(ShareTemplate.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    preview
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    SectionLabel("Mostrar")
                    toggles
                    shareButton
                        .padding(.top, 16)
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.bottom, 32)
            }
            .background(BrandBackground())
            .navigationTitle("Compartilhar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pronto") { dismiss() }
                        .tint(BrandColors.accent)
                }
            }
        }
        .task(id: "\(template.rawValue)|\(fieldsText)") {
            image = ShareRenderer.render(content, template: template, scale: ShareConstants.exportScale)
            #if DEBUG
            ShareDebugExport.runIfRequested(input: input, enabled: enabled)
            #endif
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: template.previewWidth)
                .background {
                    if template.isSticker {
                        CheckerboardView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: ShareConstants.previewCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ShareConstants.previewCornerRadius, style: .continuous)
                        .strokeBorder(BrandColors.line, lineWidth: 1)
                }
                .accessibilityLabel("Prévia da imagem")
        } else {
            ProgressView()
        }
    }

    private var toggles: some View {
        let fields = availableShareFields(input)
        return VStack(spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.element) { index, field in
                Toggle(ShareConstants.fieldTitles[field] ?? field.rawValue, isOn: binding(field))
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.text)
                    .tint(BrandColors.accent)
                    .padding(.vertical, 6)
                if index < fields.count - 1 {
                    Divider().overlay(BrandColors.line)
                }
            }
        }
        .brandCard()
    }

    @ViewBuilder
    private var shareButton: some View {
        if let image {
            ShareLink(
                item: ShareImage(image: image),
                preview: SharePreview(ShareConstants.previewTitle, image: Image(uiImage: image))
            ) {
                Text("Compartilhar imagem")
                    .font(.system(size: ShareConstants.buttonFontSize, weight: .bold))
                    .foregroundStyle(BrandColors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(ShareConstants.buttonPadding)
                    .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: ShareConstants.buttonCornerRadius, style: .continuous))
            }
        }
    }

    private func binding(_ field: ShareField) -> Binding<Bool> {
        Binding(
            get: { enabled.contains(field) },
            set: { isOn in
                var fields = enabled
                if isOn { fields.insert(field) } else { fields.remove(field) }
                fieldsText = ShareField.encode(fields)
            }
        )
    }
}
