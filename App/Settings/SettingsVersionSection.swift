import SwiftUI

struct SettingsVersionSection: View {
    let summary: AppVersionSummary
    let build: String

    private typealias T = SettingsVersionText

    var body: some View {
        Section {
            row(T.installed, T.installedValue(version: summary.installed, build: build), highlighted: false)
            if let latest = T.latestValue(summary) {
                row(T.latest, latest, highlighted: summary.hasUpdate)
            }
            if let version = summary.notesVersion, !summary.notes.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.s2) {
                    Text(String(format: T.notesFormat, version)).font(.footnote).foregroundStyle(BrandColors.dim)
                    ForEach(summary.notes, id: \.self) { note in
                        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s2) {
                            Text(T.bullet).foregroundStyle(BrandColors.dim)
                            Text(note).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.vertical, DSSpacing.s1)
                .listRowBackground(BrandColors.card)
            }
        } header: {
            DSSectionTitle(T.title)
        }
    }

    private func row(_ label: String, _ value: String, highlighted: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(BrandColors.text)
            Spacer()
            Text(value)
                .foregroundStyle(highlighted ? BrandColors.attention : BrandColors.dim)
                .fontWeight(highlighted ? .semibold : .regular)
                .multilineTextAlignment(.trailing)
        }
        .listRowBackground(BrandColors.card)
    }
}
