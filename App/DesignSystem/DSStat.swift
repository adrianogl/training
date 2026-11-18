import SwiftUI

enum DSStatSize {
    case regular, large

    var fontSize: CGFloat {
        switch self {
        case .regular: DSStatConstants.regularSize
        case .large: DSStatConstants.largeSize
        }
    }
}

struct DSStat: View {
    let value: String?
    let label: String
    var color: Color = BrandColors.text
    var size: DSStatSize = .regular
    var boxed = false

    var body: some View {
        if let value {
            content(value)
        }
    }

    private func content(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(BrandFonts.number(size.fontSize))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(DSStatConstants.minimumScale)
            Text(label)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(boxed ? DSSpacing.s3 : 0)
        .background {
            if boxed { RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous).fill(BrandColors.track) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

enum DSTrend {
    case better, worse, same
}

struct DSDelta: View {
    let text: String
    let trend: DSTrend

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Self.color(trend))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    static func color(_ trend: DSTrend) -> Color {
        switch trend {
        case .better: BrandColors.accent
        case .worse: BrandColors.attention
        case .same: BrandColors.dim
        }
    }
}
