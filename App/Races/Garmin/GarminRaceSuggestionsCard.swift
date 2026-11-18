import GarminAPI
import SwiftUI

struct GarminRaceSuggestionsCard: View {
    private typealias C = GarminRaceConstants
    let state: GarminRaceSuggestions
    let onAdd: (GarminRaceEvent) -> Void
    let onIgnore: (GarminRaceEvent) -> Void
    let onApply: (GarminRaceChange) -> Void
    let onKeep: (GarminRaceChange) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !state.suggestions.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(state.suggestions.count == 1 ? C.suggestionTitleOne : String(format: C.suggestionTitleFormat, state.suggestions.count))
                        .font(.headline)
                        .foregroundStyle(BrandColors.text)
                    Spacer()
                    Text(C.source).font(.caption).foregroundStyle(BrandColors.dim)
                }
                ForEach(Array(state.suggestions.enumerated()), id: \.element.id) { index, event in
                    if index > 0 { Divider().overlay(BrandColors.line) }
                    suggestion(event)
                }
            }
            if !state.changes.isEmpty {
                if !state.suggestions.isEmpty { Divider().overlay(BrandColors.line) }
                Text(C.changesTitle).font(.headline).foregroundStyle(BrandColors.text)
                ForEach(state.changes) { item in changeRow(item) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func suggestion(_ event: GarminRaceEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
            Text(GarminRaceSuggestionBuilder.meta(event)).font(.caption).foregroundStyle(BrandColors.dim)
            if event.courseId == nil {
                Text(C.noCourse).font(.caption).foregroundStyle(BrandColors.attention)
            }
            buttons(primary: C.add, { onAdd(event) }, secondary: C.ignore, { onIgnore(event) })
        }
    }

    private func changeRow(_ change: GarminRaceChange) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(change.raceName).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
            ForEach(change.lines, id: \.self) { line in
                Text(line).font(.caption).foregroundStyle(BrandColors.attention)
            }
            buttons(primary: C.apply, { onApply(change) }, secondary: C.keep, { onKeep(change) })
        }
    }

    private func buttons(primary: String, _ primaryAction: @escaping () -> Void, secondary: String, _ secondaryAction: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(primary, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .tint(BrandColors.accentFill)
                .foregroundStyle(BrandColors.onAccent)
            Button(secondary, action: secondaryAction)
                .buttonStyle(.bordered)
                .tint(BrandColors.dim)
                .foregroundStyle(BrandColors.text)
        }
        .font(.subheadline.weight(.semibold))
    }
}
