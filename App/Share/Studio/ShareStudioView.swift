import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WorkoutAnalysis

struct ShareStudioView: View {
    let source: ShareSource
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ShareStudioConstants.formatDefaultsKey) private var format: ShareFormat = .animatedRoute
    @AppStorage(ShareStudioConstants.aspectDefaultsKey) private var aspect: ShareAspect = .story
    @AppStorage(ShareStudioConstants.coloringDefaultsKey) private var coloring: RouteColoring = .pace
    @AppStorage(ShareStudioConstants.hidesEndsDefaultsKey) private var hidesEnds = true
    @AppStorage(ShareConstants.fieldsDefaultsKey) private var fieldsText = ShareField.encode(ShareField.defaultEnabled)
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var staticPreview: UIImage?
    @State private var exporting = false
    @State private var exported: ExportedFile?
    @State private var message: String?

    private typealias C = ShareStudioConstants

    private var formats: [ShareFormat] {
        ShareFormat.allCases.filter { format in
            switch format {
            case .animatedRoute, .animatedSquare, .photo: source.track.count >= 2
            case .series: source.series.count >= C.minimumSeriesBars
            case .evolution: source.evolution.count >= C.minimumEvolutionPoints
            case .sticker, .card, .blocks, .strip: true
            }
        }
    }

    private var current: ShareFormat { formats.contains(format) ? format : formats.first ?? .card }

    private var colorings: [RouteColoring] {
        RouteColoring.allCases.filter { $0 != .zone || !source.zoneFloors.isEmpty }
    }

    private var settings: ShareSettings {
        let usedColoring = colorings.contains(coloring) ? coloring : .pace
        return ShareSettings(format: current, aspect: aspect, coloring: usedColoring, hidesEnds: hidesEnds, fields: ShareField.decode(fieldsText))
    }

    private var isAnimated: Bool { [.animatedRoute, .animatedSquare, .photo].contains(current) }
    private var usesAspect: Bool { [.animatedRoute, .animatedSquare, .photo, .series, .evolution].contains(current) }
    private var usesColoring: Bool { [.animatedRoute, .animatedSquare].contains(current) }
    private var showsRoute: Bool { source.track.count >= 2 && ![.series, .evolution, .blocks].contains(current) }
    private var usesFields: Bool { ![.series, .evolution].contains(current) }
    private var isSticker: Bool { [.sticker, .strip].contains(current) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    formatPicker
                    preview.frame(maxWidth: .infinity)
                    actions
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    options
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.bottom, 32)
            }
            .background(BrandBackground())
            .navigationTitle(ShareConstants.previewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pronto") { dismiss() }.tint(BrandColors.accent)
                }
            }
        }
        .task(id: "\(current.rawValue)|\(aspect.rawValue)|\(hidesEnds)|\(fieldsText)") {
            staticPreview = isAnimated ? nil : ShareMediaExporter.image(source: source, settings: settings, photo: photo, scale: 2)
            #if DEBUG
            ShareDebugExport.runIfRequested(input: source.input, enabled: settings.fields)
            #endif
        }
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                photo = UIImage(data: data)
            }
        }
        .sheet(item: $exported) { file in
            ActivitySheet(items: [file.url]).presentationDetents([.medium, .large])
        }
    }

    private var formatPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(formats) { item in
                    Button {
                        format = item
                        message = nil
                    } label: {
                        Label(C.formatTitles[item] ?? item.rawValue, systemImage: C.formatSymbols[item] ?? "square")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(item == current ? BrandColors.onAccent : BrandColors.text)
                            .background(item == current ? BrandColors.accentFill : BrandColors.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(BrandColors.cardBorder, lineWidth: item == current ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var preview: some View {
        let size = ShareStudioCard.size(settings)
        let width = previewWidth
        Group {
            if isAnimated {
                TimelineView(.animation) { timeline in
                    ShareStudioCard(source: source, settings: settings, progress: loopProgress(timeline.date), photo: photo)
                        .scaleEffect(width / size.width, anchor: .topLeading)
                        .frame(width: width, height: size.height * width / size.width, alignment: .topLeading)
                }
            } else if let staticPreview {
                Image(uiImage: staticPreview).resizable().scaledToFit().frame(width: width)
                    .background { if isSticker { CheckerboardView() } }
            } else {
                ProgressView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ShareConstants.previewCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ShareConstants.previewCornerRadius, style: .continuous).strokeBorder(BrandColors.line, lineWidth: 1))
        .accessibilityLabel(C.formatTitles[current] ?? "")
    }

    private var previewWidth: CGFloat {
        switch current {
        case .card, .sticker: ShareConstants.previewStoryWidth
        case .blocks: ShareConstants.previewBlocksWidth
        case .strip: ShareConstants.previewStripWidth
        default: C.previewWidths[aspect] ?? ShareConstants.previewStoryWidth
        }
    }

    private func loopProgress(_ date: Date) -> Double {
        let cycle = C.animationSeconds + C.holdSeconds
        let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        let linear = min(elapsed / C.animationSeconds, 1)
        return 1 - pow(1 - linear, 2)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if exporting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(C.generating).foregroundStyle(BrandColors.dim)
                }
                .frame(maxWidth: .infinity)
            }
            if isAnimated {
                primary(C.shareVideo) { try await ShareMediaExporter.video(source: source, settings: settings, photo: photo) }
                HStack(spacing: 10) {
                    secondary(C.shareGif) { try await ShareMediaExporter.gif(source: source, settings: settings, photo: photo) }
                    secondary(C.shareImage) { try ShareMediaExporter.imageFile(source: source, settings: settings, photo: photo) }
                }
            } else {
                primary(C.shareImage) { try ShareMediaExporter.imageFile(source: source, settings: settings, photo: photo) }
                if isSticker {
                    Button(C.copySticker) { copySticker() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.accent)
                }
            }
        }
        .disabled(exporting)
    }

    private func primary(_ title: String, make: @escaping () async throws -> URL) -> some View {
        Button { export(make) } label: {
            Text(title)
                .font(.system(size: ShareConstants.buttonFontSize, weight: .bold))
                .foregroundStyle(BrandColors.onAccent)
                .frame(maxWidth: .infinity)
                .padding(ShareConstants.buttonPadding)
                .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: ShareConstants.buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func secondary(_ title: String, make: @escaping () async throws -> URL) -> some View {
        Button { export(make) } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.text)
                .frame(maxWidth: .infinity)
                .padding(ShareConstants.buttonPadding)
                .background(BrandColors.card, in: RoundedRectangle(cornerRadius: ShareConstants.buttonCornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ShareConstants.buttonCornerRadius, style: .continuous).strokeBorder(BrandColors.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func export(_ make: @escaping () async throws -> URL) {
        exporting = true
        message = nil
        Task {
            do {
                exported = ExportedFile(url: try await make())
            } catch {
                message = C.exportFailed
            }
            exporting = false
        }
    }

    private func copySticker() {
        guard let data = ShareMediaExporter.image(source: source, settings: settings, photo: photo)?.pngData() else { return }
        UIPasteboard.general.setData(data, forPasteboardType: UTType.png.identifier)
        message = C.copiedSticker
    }

    @ViewBuilder
    private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            if current == .photo {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photo == nil ? C.choosePhoto : C.changePhoto, systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.accent)
                }
            }
            if usesAspect {
                picker(C.aspectLabel, selection: $aspect, items: ShareAspect.allCases) { C.aspectTitles[$0] ?? "" }
            }
            if usesColoring {
                picker(C.coloringLabel, selection: $coloring, items: colorings) { C.coloringTitles[$0] ?? "" }
            }
            if showsRoute {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(C.hidesEndsLabel, isOn: $hidesEnds).tint(BrandColors.accent)
                    Text(C.hidesEndsFooter).font(.caption).foregroundStyle(BrandColors.dim)
                }
                .brandCard()
            }
            if usesFields {
                SectionLabel(C.fieldsLabel).padding(.top, 0).padding(.bottom, 0)
                toggles
            }
        }
    }

    private func picker<Item: Hashable>(_ title: String, selection: Binding<Item>, items: [Item], label: @escaping (Item) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.dim)
            Picker(title, selection: selection) {
                ForEach(items, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var toggles: some View {
        let fields = availableShareFields(source.input)
        let enabled = ShareField.decode(fieldsText)
        return VStack(spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.element) { index, field in
                Toggle(ShareConstants.fieldTitles[field] ?? field.rawValue, isOn: Binding(
                    get: { enabled.contains(field) },
                    set: { isOn in
                        var updated = enabled
                        if isOn { updated.insert(field) } else { updated.remove(field) }
                        fieldsText = ShareField.encode(updated)
                    }
                ))
                .font(.subheadline)
                .tint(BrandColors.accent)
                .padding(.vertical, 6)
                if index < fields.count - 1 { Divider().overlay(BrandColors.line) }
            }
        }
        .brandCard()
    }
}

struct ExportedFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
