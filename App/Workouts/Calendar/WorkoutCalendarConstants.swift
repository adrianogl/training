import CoreGraphics
import Foundation

enum WorkoutCalendarConstants {
    static let modeKey = "workouts.listMode"
    static let modeNames: [WorkoutListMode: String] = [.week: "Semana", .calendar: "Mês", .list: "Feitos"]
    static let planButton = "Plano"
    static let weekdayLetters = ["D", "S", "T", "Q", "Q", "S", "S"]
    static let monthFormat = "LLLL 'de' yyyy"
    static let dayTitleFormat = "EEEE, d 'de' MMMM"
    static let previousSymbol = "chevron.left"
    static let nextSymbol = "chevron.right"
    static let previousMonth = "Mês anterior"
    static let nextMonth = "Próximo mês"
    static let legendRun = "corrida"
    static let legendPlanned = "corrida planejada"
    static let legendStrength = "força"
    static let legendMFIT = "MFIT"
    static let monthLabel = "Mês"
    static let runLabel = "Corrida"
    static let strengthLabel = "Força"
    static let runSummaryFormat = "%@ km · %d treinos"
    static let strengthSummaryFormat = "%d sessões"
    static let emptyDay = "Nenhum treino neste dia."
    static let dotSize: CGFloat = 6
    static let dotSpacing: CGFloat = 3
    static let cellSpacing: CGFloat = 4
    static let cellRadius: CGFloat = 12
    static let cellVerticalPadding: CGFloat = 6
    static let todayBorder: CGFloat = 2
    static let outsideOpacity = 0.35
    static let kilometersSize: CGFloat = 10
    static let navButtonSize: CGFloat = 44
}
