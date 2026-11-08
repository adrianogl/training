import SwiftUI
import UIKit
import WorkoutAnalysis

@MainActor
enum ShareRenderer {
    static func render(_ content: ShareContent, template: ShareTemplate, scale: CGFloat) -> UIImage {
        let renderer = ImageRenderer(content: ShareCardView(content: content, template: template))
        renderer.scale = scale
        renderer.isOpaque = template.hasBackground
        renderer.proposedSize = ProposedViewSize(width: ShareConstants.canvasWidth, height: template.canvasHeight)
        return renderer.uiImage ?? UIImage()
    }
}
