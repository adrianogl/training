import SwiftUI
import WorkoutAnalysis

struct ShareFrame<Content: View>: View {
    let template: ShareTemplate
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if template != .strip {
                logo
            }
            content
            if template == .strip {
                logo.padding(.top, 8)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(width: ShareConstants.canvasWidth, height: template.canvasHeight, alignment: .topLeading)
        .background {
            if template.hasBackground {
                ShareBackground()
            }
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var logo: some View {
        switch template {
        case .storiesDark:
            Logo(showsTagline: true)
        case .blocks:
            Logo(showsTagline: false)
        case .transparent:
            Logo(showsTagline: false, showsIcon: false, fontSize: ShareConstants.stickerLogoFontSize)
                .shadow(color: BrandColors.stickerShadow, radius: ShareConstants.shadowRadius, y: 1)
        case .strip:
            Logo(showsTagline: false, showsIcon: false, fontSize: ShareConstants.stripLogoFontSize)
                .shadow(color: BrandColors.stickerShadow, radius: ShareConstants.shadowRadius, y: 1)
        }
    }

    private var horizontalPadding: CGFloat {
        switch template {
        case .storiesDark, .transparent: ShareConstants.storyPadding
        case .blocks: ShareConstants.blocksPadding
        case .strip: ShareConstants.stripHorizontalPadding
        }
    }

    private var verticalPadding: CGFloat {
        template == .strip ? ShareConstants.stripVerticalPadding : horizontalPadding
    }
}
