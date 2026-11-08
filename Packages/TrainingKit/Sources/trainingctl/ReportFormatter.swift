import Foundation
import Reports

enum ReportFormatter {
    static func lines(_ report: TrainingReport) -> [String] {
        var lines = [
            "Dias: \(report.days)",
            "Atividades: \(report.activities)",
            "Hoje: \(report.today.iso)",
            "Prontidão hoje: \(readiness(report))",
            "VO2max suavizado: \(dated(report.vo2max, digits: 1))",
            "Fitness hoje: \(number(report.fitness, digits: 1))",
            "Fadiga hoje: \(number(report.fatigue, digits: 1))",
            "Forma hoje: \(number(report.form, digits: 1))",
            "A:C: \(number(report.acuteChronic, digits: 2))",
        ]
        lines += report.predictions.map { "Previsão \($0.label): \(duration($0.seconds))" }
        lines.append("Durabilidade (desacoplamento %): \(dated(report.durability, digits: 1))")
        lines.append("Força em subida: \(dated(report.hillStrength, digits: 1))")
        return lines
    }

    private static func readiness(_ report: TrainingReport) -> String {
        guard let score = report.readinessScore else { return CLIConstants.missing }
        return report.readinessPartial ? "\(score) (parcial)" : "\(score)"
    }

    private static func number(_ value: Double?, digits: Int) -> String {
        guard let value, value.isFinite else { return CLIConstants.missing }
        return value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "pt_BR")).grouping(.never))
    }

    private static func dated(_ value: DatedValue?, digits: Int) -> String {
        guard let value, value.value.isFinite else { return CLIConstants.missing }
        return "\(number(value.value, digits: digits)) (\(value.day.iso))"
    }

    private static func duration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return CLIConstants.missing }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }
}
