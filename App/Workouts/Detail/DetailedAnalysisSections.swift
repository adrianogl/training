import Insights
import SwiftUI

struct DetailedKPIRow: View {
    let tiles: [DetailedKPITile]

    private typealias C = DetailedScreenConstants

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(tiles) { tile in
                DSStat(
                    value: tile.value,
                    label: tile.caption + (tile.average.map { " · " + String(format: C.averageFormat, $0) } ?? ""),
                    color: tile.isWorse ? BrandColors.attention : BrandColors.text
                )
            }
        }
    }
}

struct DetailedFindingsCard: View {
    let findings: [DetailedFinding]

    private typealias C = DetailedScreenConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(findings.enumerated()), id: \.element.id) { index, finding in
                if index > 0 { Divider().overlay(BrandColors.line) }
                HStack(alignment: .top, spacing: 8) {
                    glyph(finding.tone)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        Text(finding.text).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .brandCard()
    }

    private func glyph(_ tone: DetailedTone) -> some View {
        let style: (symbol: String, color: Color) = switch tone {
        case .fix: (C.fixSymbol, BrandColors.attention)
        case .good: (C.goodSymbol, BrandColors.accent)
        case .info: (C.infoSymbol, BrandColors.fitness)
        }
        return Image(systemName: style.symbol)
            .font(.caption.weight(.heavy))
            .foregroundStyle(style.color)
            .frame(width: C.glyphSize, height: C.glyphSize)
            .background(style.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct DetailedRecommendationsCard: View {
    let recommendations: [DetailedRecommendation]

    private typealias C = DetailedScreenConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(BrandColors.onAccent)
                        .frame(width: C.badgeSize, height: C.badgeSize)
                        .background(BrandColors.accentFill, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        Text(item.reason).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .brandCard()
    }
}

struct DetailedCoachCard: View {
    let sections: [DetailedCoachSection]
    let states: [DetailedCoachPart: CoachPartState]

    private typealias C = DetailedScreenConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.part.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    switch states[section.part] ?? .pending {
                    case .pending:
                        GeneratingSkeleton()
                    case .generated(let text):
                        paragraph(text)
                        OnDeviceCaption()
                    case .fallback(let text):
                        paragraph(text)
                    }
                }
            }
        }
        .frame(maxWidth: C.contentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(BrandColors.text)
            .fixedSize(horizontal: false, vertical: true)
    }
}
