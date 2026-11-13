import SwiftUI

struct ReadinessRuler: View {
    let score: Int?
    var showsLabels = false

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [BrandColors.rest, BrandColors.form, BrandColors.accent], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                    ForEach([TodayConstants.moderateThreshold, TodayConstants.hardThreshold], id: \.self) { threshold in
                        Rectangle()
                            .fill(BrandColors.background.opacity(0.7))
                            .frame(width: 1.5, height: 6)
                            .offset(x: width * Double(threshold) / 100)
                    }
                    if let score {
                        Capsule()
                            .fill(BrandColors.text)
                            .frame(width: 3, height: 14)
                            .offset(x: min(max(width * Double(score) / 100 - 1.5, 0), width - 3))
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)
            if showsLabels {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        Text(TodayConstants.rulerRest).position(x: width * 0.2, y: 6)
                        Text("\(TodayConstants.moderateThreshold)").position(x: width * 0.4, y: 6)
                        Text(TodayConstants.rulerModerate).position(x: width * 0.55, y: 6)
                        Text("\(TodayConstants.hardThreshold)").position(x: width * 0.7, y: 6)
                        Text(TodayConstants.rulerHard).position(x: width * 0.85, y: 6)
                    }
                }
                .frame(height: 12)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
            }
        }
    }

    static func color(for score: Int) -> Color {
        if score < TodayConstants.moderateThreshold { return BrandColors.rest }
        if score < TodayConstants.hardThreshold { return BrandColors.form }
        return BrandColors.accent
    }
}
