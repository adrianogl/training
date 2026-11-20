import Insights
import SwiftUI
import UIKit

@MainActor enum ExerciseImageLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let path = Bundle.main.path(forResource: name, ofType: nil, inDirectory: ExerciseDetailConstants.imagesFolder),
              let image = UIImage(contentsOfFile: path)
        else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}

struct ExerciseMediaView: View {
    let media: ExerciseMedia
    var animates = true
    var fills = false
    var drawingProgress: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if media.source == .drawing, let pattern = media.pattern {
            Group {
                if let drawingProgress {
                    ExercisePatternFigure(pattern: pattern, progress: drawingProgress)
                } else {
                    ExercisePatternFigure(pattern: pattern)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandColors.card)
        } else if media.frames.count > 1, animates, !reduceMotion {
            TimelineView(.periodic(from: .now, by: ExerciseDetailConstants.frameSeconds)) { context in
                let step = Int(context.date.timeIntervalSinceReferenceDate / ExerciseDetailConstants.frameSeconds)
                photo(media.frames[step % media.frames.count])
            }
        } else {
            photo(media.frames.first)
        }
    }

    private func photo(_ name: String?) -> some View {
        Group {
            if let image = name.flatMap(ExerciseImageLoader.image) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: fills ? .fill : .fit)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .accessibilityLabel(ExerciseDetailText.photoLabel)
    }
}

struct ExerciseMediaCarousel: View {
    @Bindable var model: ExerciseDetailModel

    var body: some View {
        VStack(spacing: DSSpacing.s2) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(model.media) { item in
                        ExerciseMediaView(media: item)
                            .aspectRatio(ExerciseDetailConstants.mediaAspect, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: ExerciseDetailConstants.mediaCorner, style: .continuous))
                            .overlay {
                                if item.source == .drawing {
                                    RoundedRectangle(cornerRadius: ExerciseDetailConstants.mediaCorner, style: .continuous)
                                        .strokeBorder(BrandColors.cardBorder, lineWidth: 1)
                                }
                            }
                            .containerRelativeFrame(.horizontal)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $model.currentId)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ExerciseDetailText.carouselLabel)
            .accessibilityValue(ExerciseDetailText.carouselValue(model))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: model.showNext()
                case .decrement: model.showPrevious()
                @unknown default: break
                }
            }
            if model.media.count > 1 {
                HStack(spacing: DSSpacing.s2 - 2) {
                    ForEach(Array(model.media.enumerated()), id: \.element.id) { index, _ in
                        Circle()
                            .fill(index == model.currentIndex ? BrandColors.text : BrandColors.track)
                            .frame(width: ExerciseDetailConstants.dotSize, height: ExerciseDetailConstants.dotSize)
                    }
                }
                .accessibilityHidden(true)
            }
            if let current = model.current {
                HStack(alignment: .firstTextBaseline) {
                    Text(ExerciseDetailText.credit(current, pattern: model.pattern))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                    Spacer(minLength: DSSpacing.s2)
                    if model.media.count > 1 {
                        Text(ExerciseDetailText.page(model.currentIndex, of: model.media.count))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BrandColors.dim)
                    }
                }
                .padding(.horizontal, DSSpacing.s1)
            }
        }
    }
}

struct ExerciseThumbnail: View {
    let key: ExerciseKey
    let pattern: MovementPattern?
    @Environment(\.exerciseFeedbackStore) private var feedbackStore

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ExerciseDetailConstants.thumbnailCorner, style: .continuous)
        Group {
            if let media = firstMedia {
                if media.source == .drawing, let pattern = media.pattern {
                    ExercisePatternFigure(pattern: pattern, progress: 1)
                        .scaleEffect(ExerciseDetailConstants.thumbnailDrawingScale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(BrandColors.track)
                } else if let image = media.frames.first.flatMap(ExerciseImageLoader.image) {
                    Image(uiImage: image).resizable().scaledToFill().background(Color.white)
                } else {
                    BrandColors.track
                }
            } else {
                BrandColors.track
            }
        }
        .frame(width: ExerciseDetailConstants.thumbnailSize, height: ExerciseDetailConstants.thumbnailSize)
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private var firstMedia: ExerciseMedia? {
        let catalog = ExerciseMediaCatalog.shared
        if let preferred = feedbackStore?.preferredMediaId(for: key), let media = catalog.media(withId: preferred) { return media }
        return catalog.media(for: key, fallback: pattern).first
    }
}
