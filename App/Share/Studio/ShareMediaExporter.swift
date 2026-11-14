import AVFoundation
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum ShareExportError: Error {
    case render, gif, video
}

@MainActor
enum ShareMediaExporter {
    private typealias C = ShareStudioConstants

    static func image(source: ShareSource, settings: ShareSettings, photo: UIImage?, progress: Double = 1, scale: CGFloat = C.imageScale) -> UIImage? {
        let size = ShareStudioCard.size(settings)
        let renderer = ImageRenderer(content: ShareStudioCard(source: source, settings: settings, progress: progress, photo: photo))
        renderer.scale = scale
        renderer.isOpaque = ShareStudioCard.isOpaque(settings)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height > 0 ? size.height : nil)
        return renderer.uiImage
    }

    static func imageFile(source: ShareSource, settings: ShareSettings, photo: UIImage?) throws -> URL {
        guard let data = image(source: source, settings: settings, photo: photo)?.pngData() else { throw ShareExportError.render }
        let url = fileURL(C.imageFileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func gif(source: ShareSource, settings: ShareSettings, photo: UIImage?) async throws -> URL {
        let progresses = frameProgresses(framesPerSecond: C.gifFramesPerSecond)
        let url = fileURL(C.gifFileName)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, progresses.count, nil) else {
            throw ShareExportError.gif
        }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / C.gifFramesPerSecond]] as CFDictionary
        for progress in progresses {
            guard let frame = image(source: source, settings: settings, photo: photo, progress: progress, scale: C.gifScale)?.cgImage else {
                throw ShareExportError.render
            }
            CGImageDestinationAddImage(destination, frame, frameProperties)
            await Task.yield()
        }
        guard CGImageDestinationFinalize(destination) else { throw ShareExportError.gif }
        return url
    }

    static func video(source: ShareSource, settings: ShareSettings, photo: UIImage?) async throws -> URL {
        let canvas = ShareStudioCard.size(settings)
        let width = Int(canvas.width * C.videoScale) / 2 * 2
        let height = Int(canvas.height * C.videoScale) / 2 * 2
        let url = fileURL(C.videoFileName)
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw ShareExportError.video }
        writer.add(input)
        guard writer.startWriting() else { throw ShareExportError.video }
        writer.startSession(atSourceTime: .zero)
        let progresses = frameProgresses(framesPerSecond: Double(C.videoFramesPerSecond))
        for (index, progress) in progresses.enumerated() {
            guard let frame = image(source: source, settings: settings, photo: photo, progress: progress, scale: C.videoScale)?.cgImage,
                  let buffer = pixelBuffer(frame, pool: adaptor.pixelBufferPool, width: width, height: height) else {
                throw ShareExportError.render
            }
            while !input.isReadyForMoreMediaData { await Task.yield() }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: C.videoFramesPerSecond))
            await Task.yield()
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ShareExportError.video }
        return url
    }

    static func frameProgresses(framesPerSecond: Double) -> [Double] {
        let moving = Int(C.animationSeconds * framesPerSecond)
        let holding = Int(C.holdSeconds * framesPerSecond)
        let animated = (0..<moving).map { index -> Double in
            let linear = Double(index) / Double(max(moving - 1, 1))
            return 1 - pow(1 - linear, 2)
        }
        return animated + Array(repeating: 1, count: holding)
    }

    private static func pixelBuffer(_ image: CGImage, pool: CVPixelBufferPool?, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        } else {
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32ARGB, nil, &buffer)
        }
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private static func fileURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: name)
    }
}
