import Foundation
import Insights
import Metrics
import Observation
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

@MainActor @Observable final class RaceEditorModel {
    typealias C = RacesConstants

    let raceId: UUID?
    let today: Day
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private var efforts: [Effort] = []
    @ObservationIgnored private let onChange: @MainActor () -> Void
    var name = ""
    var date = Date.now
    var hasStartTime = false
    var startTime = Date.now
    var distanceOption = RaceDistanceOption.half
    var customKm = ""
    var goalText = ""
    var priority = RacePriority.a
    var city = ""
    private(set) var gpxData: Data?
    private(set) var gpxSummary: String?
    private(set) var gpxError: String?
    private(set) var assessment: EditorAssessment?
    private(set) var isLoaded = false

    init(container: ModelContainer, raceId: UUID?, today: Day, onChange: @escaping @MainActor () -> Void = {}) {
        self.container = container
        self.onChange = onChange
        self.raceId = raceId
        self.today = today
        self.date = today.adding(days: C.daysPerWeek * C.blockWeeks).chartDate
    }

    var isNew: Bool { raceId == nil }

    var distance: Double? {
        if distanceOption == .other {
            return Double(customKm.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 * C.metersPerKm : nil }
        }
        return C.distanceMeters[distanceOption]
    }

    var goalSeconds: Double? { Self.parseClock(goalText) }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && distance != nil && (goalText.isEmpty || goalSeconds != nil)
    }

    var evaluationKey: String {
        "\(distance ?? 0)|\(day.iso)|\(goalSeconds ?? 0)"
    }

    private var day: Day { Day.today(now: date) }

    func load() async {
        if let race = fetchRace() {
            name = race.name
            if let day = Day(iso: race.day) { date = day.chartDate }
            if let start = race.startTime, let time = Self.timeFormatter.date(from: start) {
                hasStartTime = true
                startTime = time
            }
            if let option = C.distanceMeters.first(where: { abs($0.value - race.distance) < C.distanceTolerance })?.key {
                distanceOption = option
            } else {
                distanceOption = .other
                customKm = RacesText.km(race.distance / C.metersPerKm)
            }
            goalText = race.goalSeconds.map(WorkoutFormat.clock) ?? ""
            priority = race.priorityLevel
            city = race.city ?? ""
            setGPX(race.gpxData)
        }
        let container = container
        let today = today
        efforts = await Task.detached(priority: .userInitiated) {
            (try? raceEfforts(context: ModelContext(container), today: today)) ?? []
        }.value
        isLoaded = true
    }

    func evaluate() async {
        guard let distance, let goal = goalSeconds else {
            assessment = nil
            return
        }
        let efforts = efforts
        let today = today
        let raceDay = day
        let outlook = await Task.detached(priority: .userInitiated) {
            raceOutlook(distance: distance, raceDay: raceDay, goalSeconds: goal, efforts: efforts, today: today)
        }.value
        guard !Task.isCancelled else { return }
        let reference: (Double, AssessmentReference)? = outlook.raceDay.map { ($0.mid, .raceDayProjection) }
            ?? outlook.today.map { ($0, .todayPrediction) }
        guard let reference else {
            assessment = EditorAssessment(
                targetPaceText: RacesText.goalPaceText(goalSeconds: goal, distance: distance),
                reference: .todayPrediction, referenceSeconds: 0, level: nil, sentence: C.noPredictionForGoal
            )
            return
        }
        assessment = EditorAssessment(
            targetPaceText: RacesText.goalPaceText(goalSeconds: goal, distance: distance),
            reference: reference.1,
            referenceSeconds: reference.0,
            level: assessGoal(goalSeconds: goal, predictionSeconds: reference.0),
            sentence: RacesText.assessmentSentence(goalSeconds: goal, referenceSeconds: reference.0, reference: reference.1) ?? C.noPredictionForGoal
        )
    }

    func importGPX(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            gpxError = C.gpxInvalid
            return
        }
        setGPX(data)
    }

    func removeGPX() {
        gpxData = nil
        gpxSummary = nil
        gpxError = nil
    }

    func save() throws {
        guard let distance else { return }
        let context = container.mainContext
        let race = fetchRace() ?? {
            let created = RaceRecord(name: "", day: "", distance: distance)
            context.insert(created)
            return created
        }()
        let newDay = day.iso
        if race.day != newDay || abs(race.distance - distance) >= C.distanceTolerance {
            race.frozenTargetSeconds = nil
            race.frozenTargetDay = nil
        }
        race.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        race.day = newDay
        race.distance = distance
        race.startTime = hasStartTime ? Self.timeFormatter.string(from: startTime) : nil
        race.goalSeconds = goalSeconds
        race.priorityLevel = priority
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        race.city = trimmedCity.isEmpty ? nil : trimmedCity
        race.gpxData = gpxData
        race.updatedAt = .now
        try context.save()
        onChange()
    }

    func delete() throws {
        guard let race = fetchRace() else { return }
        let now = Date.now
        race.deletedAt = now
        race.updatedAt = now
        try container.mainContext.save()
        onChange()
    }

    nonisolated static func parseClock(_ text: String) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false).map { Int($0) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        let values = parts.compactMap { $0 }
        let tail = values.suffix(2)
        guard tail.allSatisfy({ $0 < 60 }) else { return nil }
        let seconds = values.reduce(0) { $0 * 60 + $1 }
        return seconds > 0 ? Double(seconds) : nil
    }

    private func setGPX(_ data: Data?) {
        gpxError = nil
        guard let data else {
            gpxData = nil
            gpxSummary = nil
            return
        }
        do {
            let profile = try gpxProfile(data)
            gpxData = data
            gpxSummary = String(format: C.gpxLoaded, profile.count, RacesText.km((profile.last?.distance ?? 0) / C.metersPerKm))
        } catch GPXError.noElevation {
            gpxError = C.gpxNoElevation
        } catch {
            gpxError = C.gpxInvalid
        }
    }

    private func fetchRace() -> RaceRecord? {
        guard let raceId else { return nil }
        var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == raceId && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        return try? container.mainContext.fetch(descriptor).first
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = C.startTimeFormat
        return formatter
    }()
}
