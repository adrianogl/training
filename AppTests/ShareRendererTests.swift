import FITReader
import Foundation
import Testing
import UIKit
import WorkoutAnalysis
@testable import trAIning

@MainActor @Suite struct ShareRendererTests {
    private let content = ShareContent(
        title: "Intervalado 6 × 800 m · 3 nov",
        values: [
            ShareValue(field: .distance, value: "9,8 km", label: "distância"),
            ShareValue(field: .time, value: "52:40", label: "tempo"),
        ],
        route: [Coordinate(lat: -23.5, lon: -46.6), Coordinate(lat: -23.51, lon: -46.62), Coordinate(lat: -23.52, lon: -46.6)],
        blockBars: nil,
        readingLine: nil
    )

    @Test func rendererTransparentHasAlpha() throws {
        let transparent = ShareRenderer.render(content, template: .transparent, scale: 1)
        let stories = ShareRenderer.render(content, template: .storiesDark, scale: 1)
        #expect(try cornerAlpha(transparent) == 0)
        #expect(try cornerAlpha(stories) == 255)
        #expect(stories.size == CGSize(width: ShareConstants.canvasWidth, height: ShareConstants.storiesHeight))
    }

    @Test func pngKeepsTransparency() throws {
        let image = ShareRenderer.render(content, template: .strip, scale: 1)
        let data = try #require(ShareImage(image: image).data)
        let decoded = try #require(UIImage(data: data))
        #expect(try cornerAlpha(decoded) == 0)
    }

    @Test func appIconIsOpaqueSquare() throws {
        let data = try #require(AppIconExport.png())
        let image = try #require(UIImage(data: data))
        let cgImage = try #require(image.cgImage)
        #expect(cgImage.width == Int(ShareConstants.appIconPixels))
        #expect(cgImage.height == Int(ShareConstants.appIconPixels))
        #expect([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(cgImage.alphaInfo))
        if let target = ProcessInfo.processInfo.environment[ShareConstants.appIconExportEnvironmentVariable] {
            try data.write(to: URL(fileURLWithPath: target))
        }
    }

    private func cornerAlpha(_ image: UIImage) throws -> UInt8 {
        let cgImage = try #require(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return pixel[3]
    }
}
