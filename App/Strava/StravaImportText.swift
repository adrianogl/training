import Foundation
import RemoteSync
import TrainingCore
import WorkoutAnalysis

enum StravaImportText {
    static let title = "Corridas sem o relógio"
    static let intro = "Encontradas no Strava nos últimos 12 meses, sem par no Garmin."
    static let pending = "A importação chega na próxima versão. Por enquanto, confira a lista."
    static let empty = "Nenhuma corrida do Strava sem par no Garmin nos últimos 12 meses."
    static let loading = "Buscando no Strava…"
    static let retryLater = "O Strava limitou as consultas. Tente de novo em alguns minutos."
    static let failed = "Não deu para buscar no Strava agora."
    static let noHeartRate = "sem FC"
    static let gps = "GPS"
    static let noGps = "sem GPS"

    static func runTitle(_ run: StravaRunCandidate) -> String {
        let day = Day(iso: run.localDayISO).map { "\(TrainerText.weekdayShort($0)) \(TrainerText.dayMonth($0))" } ?? run.localDayISO
        return run.name.isEmpty ? day : "\(day) · \(run.name)"
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
