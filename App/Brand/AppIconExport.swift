#if DEBUG
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum AppIconExport {
    static func png() -> Data? {
        let side = ShareConstants.appIconPixels
        let renderer = ImageRenderer(content: AppIconArt(side: side).environment(\.colorScheme, .dark))
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

    static func launchIconPNG() -> Data? {
        let side = BrandConstants.launchIconPoints * BrandConstants.launchIconScale
        let art = AIIcon(size: side * BrandConstants.launchIconArtRatio)
            .frame(width: side, height: side)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: art)
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.uiImage?.pngData()
    }
}

private struct AppIconArt: View {
    let side: CGFloat

    var body: some View {
        ZStack {
            BrandColors.iconBase
            RadialGradient(
                colors: [BrandColors.iconAccent.opacity(BrandConstants.iconGlowOpacity), BrandColors.iconBase],
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0,
                endRadius: side * 0.7
            )
            Text(BrandConstants.logoHighlight)
                .font(.system(size: side * BrandConstants.iconFontRatio, weight: .black))
                .foregroundStyle(BrandColors.iconAccent)
        }
        .frame(width: side, height: side)
    }
}
#endif
