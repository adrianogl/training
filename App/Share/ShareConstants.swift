import CoreGraphics
import WorkoutAnalysis

enum ShareConstants {
    static let canvasWidth: CGFloat = 360
    static let storiesHeight: CGFloat = 640
    static let blocksHeight: CGFloat = 360
    static let exportScale: CGFloat = 3
    static let appIconPixels: CGFloat = 1024
    static let appIconArtRatio: CGFloat = 0.74
    static let appIconGlowRatio: CGFloat = 0.07
    static let appIconHaloOpacity = 0.22
    static let appIconExportEnvironmentVariable = "TRAINING_EXPORT_APP_ICON"

    static let templateDefaultsKey = "shareTemplate"
    static let fieldsDefaultsKey = "shareFields"
    static let exportFolder = "share-export"
    static let fileName = "trAIning.png"
    static let previewTitle = "Treino no trAIning"

    static let storyPadding: CGFloat = 26
    static let blocksPadding: CGFloat = 22
    static let stripHorizontalPadding: CGFloat = 16
    static let stripVerticalPadding: CGFloat = 14
    static let titleFontSize: CGFloat = 16
    static let heroFontSize: CGFloat = 58
    static let statFontSize: CGFloat = 32
    static let blocksStatFontSize: CGFloat = 29
    static let statLabelFontSize: CGFloat = 12
    static let statLabelTracking: CGFloat = 1
    static let readingFontSize: CGFloat = 15
    static let statRowSpacing: CGFloat = 13
    static let statColumnSpacing: CGFloat = 11
    static let storyColumns = 2
    static let blocksColumns = 3
    static let stickerLogoFontSize: CGFloat = 20
    static let stripLogoFontSize: CGFloat = 13
    static let stripFontSize: CGFloat = 20
    static let stripLabelFontSize: CGFloat = 9
    static let stripSpacing: CGFloat = 10
    static let stripRouteSize: CGFloat = 44
    static let stripRouteLineWidth: CGFloat = 2.5
    static let storyRouteLineWidth: CGFloat = 7
    static let stickerRouteLineWidth: CGFloat = 8
    static let routeMarkerSize: CGFloat = 16
    static let routeInset: CGFloat = 12
    static let barsHeight: CGFloat = 84
    static let barSpacing: CGFloat = 4
    static let barCornerRadius: CGFloat = 3
    static let shadowRadius: CGFloat = 3
    static let backgroundGlowOpacity = 0.14
    static let backgroundGlowRadius: CGFloat = 400

    static let previewStoryWidth: CGFloat = 216
    static let previewBlocksWidth: CGFloat = 250
    static let previewStripWidth: CGFloat = 300
    static let previewCornerRadius: CGFloat = 20
    static let checkerSquare: CGFloat = 8
    static let buttonCornerRadius: CGFloat = 14
    static let buttonPadding: CGFloat = 13
    static let buttonFontSize: CGFloat = 15

    static let templateTitles: [ShareTemplate: String] = [
        .storiesDark: "Stories",
        .transparent: "Sem fundo",
        .blocks: "Blocos",
        .strip: "Faixa",
    ]

    static let fieldTitles: [ShareField: String] = [
        .route: "Percurso",
        .title: "Nome do treino e data",
        .distance: "Distância",
        .time: "Tempo",
        .avgPace: "Pace médio",
        .avgHeartRate: "FC média",
        .activePace: "Pace dos tiros",
        .elevation: "Desnível",
        .readingLine: "Frase da leitura",
    ]
}
