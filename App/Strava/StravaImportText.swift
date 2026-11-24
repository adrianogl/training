import Foundation
import RemoteSync
import TrainingCore
import WorkoutAnalysis

enum StravaImportText {
    static let title = "Corridas sem o relógio"
    static let intro = "Encontradas no Strava, sem par no Garmin. Só entram as que você importar."
    static let footer = "A importada conta no volume, na carga, no treinador e na nota, como uma corrida do Garmin. Ignorada não volta para a lista."
    static let importButton = "Importar"
    static let ignoreButton = "Ignorar"
    static let importing = "Importando…"
    static let notificationTitle = "Corrida no Strava sem o relógio"

    static func importAll(_ count: Int) -> String {
        count == 2 ? "Importar as 2" : "Importar as \(count)"
    }

    static func imported(_ count: Int) -> String {
        count == 1 ? "1 corrida importada." : "\(count) corridas importadas."
    }

    static func notificationBody(_ run: StravaRunCandidate) -> String {
        "\(day(run)) · \(distance(run)) · \(WorkoutFormat.clock(run.movingSeconds)). Importar para o trAIning?"
    }

    static func day(_ run: StravaRunCandidate) -> String {
        Day(iso: run.localDayISO).map { "\(TrainerText.weekdayShort($0)) \(TrainerText.dayMonth($0))" } ?? run.localDayISO
    }
    static let emptyTitle = "Nenhuma corrida para importar"
    static let emptySymbol = "figure.run"
    static let failedTitle = "Não buscou no Strava"
    static let empty = "Nenhuma corrida do Strava sem par no Garmin nos últimos 12 meses."
    static let loading = "Buscando no Strava…"
    static let retryLater = "O Strava limitou as consultas. Tente de novo em alguns minutos."
    static let failed = "Não deu para buscar no Strava agora."
    static let noHeartRate = "sem FC"
    static let gps = "GPS"
    static let noGps = "sem GPS"

    static func runTitle(_ run: StravaRunCandidate) -> String {
        run.name.isEmpty ? day(run) : "\(day(run)) · \(run.name)"
    }

    static func distance(_ run: StravaRunCandidate) -> String {
        TrainerText.distance(run.distanceMeters)
    }

    static func detail(_ run: StravaRunCandidate) -> [String] {
        var parts = [WorkoutFormat.clock(run.movingSeconds)]
        if run.distanceMeters > 0 { parts.append("\(WorkoutFormat.clock(run.movingSeconds / run.distanceMeters * 1_000))/km") }
        parts.append(run.averageHeartRate.map { "FC \(Int($0.rounded()))" } ?? noHeartRate)
        parts.append(run.hasGps ? gps : noGps)
        return parts
    }
}
