import CoreGraphics
import WorkoutAnalysis

extension ShareTemplate {
    var title: String {
        ShareConstants.templateTitles[self] ?? rawValue
    }

    var canvasHeight: CGFloat? {
        switch self {
        case .storiesDark, .transparent: ShareConstants.storiesHeight
        case .blocks: ShareConstants.blocksHeight
        case .strip: nil
        }
    }

    var previewWidth: CGFloat {
        switch self {
        case .storiesDark, .transparent: ShareConstants.previewStoryWidth
        case .blocks: ShareConstants.previewBlocksWidth
        case .strip: ShareConstants.previewStripWidth
        }
    }

    var isSticker: Bool {
        !hasBackground
    }
}
