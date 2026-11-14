import CoreGraphics
import Foundation
import WorkoutAnalysis

enum ShareStudioConstants {
    static let formatDefaultsKey = "shareStudioFormat"
    static let aspectDefaultsKey = "shareStudioAspect"
    static let coloringDefaultsKey = "shareStudioColoring"
    static let hidesEndsDefaultsKey = "shareStudioHidesEnds"

    static let privacyTrimMeters = 200.0
    static let privacyMinimumDistance = 1_000.0
    static let paceLowPercentile = 0.1
    static let paceHighPercentile = 0.9
    static let minimumSpeedSpan = 0.3
    static let drawPointLimit = 450
    static let minimumSeriesBars = 2
    static let minimumEvolutionPoints = 2

    static let width: CGFloat = 360
    static let heights: [ShareAspect: CGFloat] = [.story: 640, .portrait: 450, .square: 360]
    static let previewWidths: [ShareAspect: CGFloat] = [.story: 220, .portrait: 260, .square: 280]

    static let animationSeconds = 4.0
    static let holdSeconds = 1.2
    static let gifFramesPerSecond = 15.0
    static let videoFramesPerSecond: Int32 = 30
    static let gifScale: CGFloat = 1.5
    static let videoScale: CGFloat = 3
    static let imageScale: CGFloat = 3
    static let gifFileName = "trAIning.gif"
    static let videoFileName = "trAIning.mp4"
    static let imageFileName = "trAIning.png"

    static let formatTitles: [ShareFormat: String] = [
        .animatedRoute: "Percurso animado",
        .animatedSquare: "Mapa quadrado",
        .photo: "Sobre foto",
        .series: "Série",
        .evolution: "Evolução",
        .sticker: "Adesivo",
        .card: "Cartão",
        .blocks: "Blocos",
        .strip: "Faixa",
    ]
    static let formatSymbols: [ShareFormat: String] = [
        .animatedRoute: "point.bottomleft.forward.to.point.topright.scurvepath",
        .animatedSquare: "square.on.square",
        .photo: "photo",
        .series: "chart.bar.fill",
        .evolution: "chart.line.uptrend.xyaxis",
        .sticker: "sparkles.rectangle.stack",
        .card: "rectangle.portrait",
        .blocks: "square.grid.3x1.below.line.grid.1x2",
        .strip: "rectangle.split.3x1",
    ]
    static let aspectTitles: [ShareAspect: String] = [.story: "9:16", .portrait: "4:5", .square: "1:1"]
    static let coloringTitles: [RouteColoring: String] = [.pace: "Pace", .zone: "Zona", .solid: "Uma cor"]

    static let formatLabel = "Formato"
    static let aspectLabel = "Proporção"
    static let coloringLabel = "Cor do percurso"
    static let hidesEndsLabel = "Esconder começo e fim"
    static let hidesEndsFooter = "Corta 200 m do início e do fim do percurso, para não mostrar onde você mora."
    static let fieldsLabel = "Mostrar"
    static let choosePhoto = "Escolher foto"
    static let changePhoto = "Trocar foto"
    static let shareVideo = "Compartilhar vídeo"
    static let shareGif = "Compartilhar GIF"
    static let shareImage = "Compartilhar imagem"
    static let copySticker = "Copiar adesivo"
    static let copiedSticker = "Adesivo copiado. Cole no Stories."
    static let generating = "Gerando…"
    static let exportFailed = "Não consegui gerar o arquivo."
    static let seriesInTargetFormat = "%d de %d no alvo"
    static let seriesTargetFormat = "alvo %@–%@"
    static let evolutionTitleFormat = "Mesmo treino · %d vezes"
    static let evolutionFasterFormat = "−%d s/km"
    static let evolutionSlowerFormat = "+%d s/km"
    static let evolutionSubtitleFormat = "no pace desde %@"
    static let evolutionHeartFormat = ", com FC %d bpm %@"
    static let racePrefix = "prova"
    static let raceVsGoal = "da meta"
    static let raceVsEve = "da previsão da véspera"
    static let raceHalvesFormat = "Primeira metade a %@/km, segunda a %@/km."
    static let raceShareTitle = "Compartilhar prova"
    static let lower = "menor"
    static let higher = "maior"
    static let paceUnit = "/km"
    static let distanceUnit = "km"
    static let statLabels: [ShareField: String] = [.time: "tempo", .avgPace: "pace", .activePace: "pace nos blocos", .avgHeartRate: "FC média"]
}
