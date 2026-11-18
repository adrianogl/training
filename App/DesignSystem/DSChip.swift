import SwiftUI

enum DSTone {
    case neutral, accent, attention, danger, strength, race, fitness, claude

    var color: Color {
        switch self {
        case .neutral: BrandColors.dim
        case .accent: BrandColors.accent
        case .attention: BrandColors.attention
        case .danger: BrandColors.danger
        case .strength: BrandColors.strength
        case .race: BrandColors.race
        case .fitness: BrandColors.fitness
        case .claude: ClaudeConstants.color
        }
    }

    var fill: Color { self == .accent ? BrandColors.accentFill : color }
}

enum DSChipStyle {
    case soft, solid
}

struct DSChip: View {
    let text: String
    var tone: DSTone = .neutral
    var style: DSChipStyle = .soft

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(style == .solid ? BrandColors.onAccent : tone.color)
            .padding(.horizontal, DSChipConstants.horizontalPadding)
            .frame(height: DSChipConstants.height)
            .background(style == .solid ? tone.fill : tone.color.opacity(DSChipConstants.softOpacity), in: Capsule())
            .fixedSize()
    }
}
