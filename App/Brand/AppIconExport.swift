#if DEBUG
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum AppIconExport {
    static func png() -> Data? {
        let side = ShareConstants.appIconPixels
        let renderer = ImageRenderer(content: AppIconArt(side: side))
        renderer.scale = 1
        renderer.isOpaque = true
        guard let rendered = renderer.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }
        context.draw(rendered, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let opaque = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, opaque, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

private struct AppIconArt: View {
    let side: CGFloat

    var body: some View {
        ZStack {
            BrandColors.background
            RadialGradient(
                colors: [BrandColors.accent.opacity(ShareConstants.appIconHaloOpacity), .clear],
                center: .center,
                startRadius: 0,
                endRadius: side * 0.6
            )
            AIIcon(size: side * ShareConstants.appIconArtRatio)
                .shadow(color: BrandColors.accent.opacity(BrandConstants.iconGlowOpacity), radius: side * ShareConstants.appIconGlowRatio)
        }
        .frame(width: side, height: side)
    }
}
#endif
