import Insights
import SwiftUI
import TrainingCore

struct TrainerRequestView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var shortcut: TrainerRequestCategory?
    @State private var text = ""
    @State private var from = Date.now
    @State private var hasUntil = false
    @State private var until = Date.now.addingTimeInterval(TrainerConstants.defaultRequestSeconds)
    @State private var result: TrainerVersion?

    init(prefill: TrainerRequestPrefill? = nil) {
        _shortcut = State(initialValue: prefill?.category)
        _text = State(initialValue: prefill?.text ?? "")
    }

    private var model: TrainerModel { app.trainer }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let result {
                        resultContent(result)
                    } else {
                        form
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(TrainerText.requestTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result == nil ? TrainerText.cancel : TrainerText.done) { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || shortcut != nil
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(TrainerText.requestWhy).padding(.vertical, 0)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(TrainerConstants.shortcuts) { item in
                            chip(item)
                        }
                    }
                }
                TextField(TrainerText.requestPlaceholder, text: $text, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(10)
                    .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BrandColors.accent.opacity(0.45), lineWidth: 1))
            }
            .brandCard()
            VStack(alignment: .leading, spacing: 8) {
                DatePicker(TrainerText.requestFrom, selection: $from, displayedComponents: .date).font(.footnote)
                Toggle(TrainerText.requestUntilToggle, isOn: $hasUntil).font(.footnote)
                if hasUntil {
                    DatePicker(TrainerText.requestUntil, selection: $until, in: from..., displayedComponents: .date).font(.footnote)
                }
            }
            .environment(\.locale, TrainerConstants.locale)
            .brandCard()
            Button(model.isWorking ? TrainerText.requestWorking : TrainerText.requestSubmit) { submit() }
                .buttonStyle(TrainerPrimaryButtonStyle())
                .disabled(!canSubmit || model.isWorking)
                .opacity(canSubmit ? 1 : 0.5)
        }
    }

    private func chip(_ item: TrainerRequestShortcut) -> some View {
        let selected = shortcut == item.category
        return Button {
            if selected {
                shortcut = nil
            } else {
                shortcut = item.category
                if text.isEmpty { text = item.prefix }
            }
        } label: {
            Text(item.title)
                .font(.footnote)
                .foregroundStyle(selected ? BrandColors.accent : BrandColors.text.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? BrandColors.accentGlow : BrandColors.track, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? BrandColors.accent.opacity(0.5) : BrandColors.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func resultContent(_ version: TrainerVersion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TrainerText.requestResult).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            TrainerVersionCard(version: version)
        }
    }

    private func submit() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = model.resolvedCategory(shortcut: shortcut, text: body)
        let request = TrainerRequest(
            category: category,
            text: body,
            from: Day.today(now: from),
            until: hasUntil ? Day.today(now: until) : nil
        )
        Task { result = await model.request(request) }
    }
}
