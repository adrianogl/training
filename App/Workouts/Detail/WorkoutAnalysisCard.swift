import SwiftUI

struct WorkoutAnalysisCard: View {
    let summary: WorkoutAnalysisSummary
    @State private var showsAll = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = WorkoutDetailConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(C.analysisTitle).padding(.top, 0).padding(.bottom, 0)
            if !summary.feedback.isEmpty || summary.next != nil {
                feedback
                Divider().overlay(BrandColors.line)
            }
            if summary.entries.isEmpty {
                Text(C.analysisNone).font(.subheadline).foregroundStyle(BrandColors.dim)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider().overlay(BrandColors.line) }
                    row(entry).padding(.vertical, 10)
                }
            }
            if hiddenCount > 0 || showsAll && summary.entries.count > C.visibleAnalysisEntries {
                Button(showsAll ? C.showLess : String(format: C.showMoreFormat, hiddenCount)) {
                    withAnimation(.snappy) { showsAll.toggle() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.accent)
                .buttonStyle(.plain)
            }
        }
        .brandCard()
    }

    private var visibleEntries: [AnalysisEntry] {
        showsAll ? summary.entries : Array(summary.entries.prefix(C.visibleAnalysisEntries))
    }

    private var hiddenCount: Int {
        showsAll ? 0 : max(summary.entries.count - C.visibleAnalysisEntries, 0)
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(summary.feedback.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.body)
                    .foregroundStyle(BrandColors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let next = summary.next {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    pill(C.nextTag, foreground: BrandColors.dim, background: BrandColors.track)
                    Text(next)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: C.feedbackMaxWidth, alignment: .leading)
    }

    @ViewBuilder
    private func row(_ entry: AnalysisEntry) -> some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 12) {
                tag(entry.tag).frame(width: C.tagColumnWidth, alignment: .leading)
                content(entry)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                tag(entry.tag)
                content(entry)
            }
        }
    }

    private func content(_ entry: AnalysisEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.text)
                .fixedSize(horizontal: false, vertical: true)
            if let evidence = entry.evidence {
                Text(evidence)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandColors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text(entry.why)
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func tag(_ tag: AnalysisTag) -> some View {
        switch tag {
        case .fix: pill(C.tagFix, foreground: BrandColors.rest, background: BrandColors.rest.opacity(0.14))
        case .good: pill(C.tagGood, foreground: BrandColors.accent, background: BrandColors.accentFill.opacity(0.16))
        case .expected: pill(C.tagExpected, foreground: BrandColors.dim, background: BrandColors.track)
        }
    }

    private func pill(_ text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
    }
}
