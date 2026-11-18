import CoreLocation
import Foundation
import HealthImport
import HealthKit
import TrainingCore

final class HealthKitReader: HealthReading, @unchecked Sendable {
    private typealias C = HealthKitReaderConstants

    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute(), HKCategoryType(.sleepAnalysis)]
        for identifier in C.quantityTypes { types.insert(HKQuantityType(identifier)) }
        return types
    }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func workouts(from: Date, to: Date) async throws -> [HealthWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
        let samples: [HKWorkout] = try await samples(HKObjectType.workoutType(), predicate: predicate)
        let vo2 = try await quantities(.vo2Max, unit: HKUnit(from: "ml/kg*min"), from: from, to: to)
        return samples.map { map($0, vo2: vo2) }
    }

    func series(for workout: HealthWorkout) async throws -> HealthSeries {
        guard let hk = try await workoutSample(id: workout.id) else { return HealthSeries() }
        let predicate = HKQuery.predicateForObjects(from: hk)
        let heart = try await points(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: predicate)
        let distance = try await points(.distanceWalkingRunning, unit: .meter(), predicate: predicate)
        let speed = try await points(.runningSpeed, unit: HKUnit.meter().unitDivided(by: .second()), predicate: predicate)
        let contact = try await points(.runningGroundContactTime, unit: .secondUnit(with: .milli), predicate: predicate)
        let cadence = try await cadence(predicate: predicate)
        let route = try await route(for: hk)
        return HealthSeries(
            heartRate: heart, distance: distance, speed: speed,
            cadence: cadence, groundContactMs: contact, route: route, laps: laps(hk)
        )
    }

    func restingHeartRate(from: Day, to: Day) async throws -> [Day: Double] {
        let values = try await quantities(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: start(of: from), to: start(of: to.adding(days: 1)))
        return averageByDay(values)
    }

    func nightlyHRV(from: Day, to: Day) async throws -> [Day: Double] {
        let values = try await quantities(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: start(of: from).addingTimeInterval(-C.nightLeadHours * 3600), to: start(of: to.adding(days: 1)))
        let night = values.filter { point in
            let hour = Calendar.current.component(.hour, from: point.date)
            return hour >= C.nightStartHour || hour < C.nightEndHour
        }
        let shifted = night.map { HealthPoint(date: $0.date.addingTimeInterval(C.nightLeadHours * 3600), value: $0.value) }
        return averageByDay(shifted).filter { $0.key >= from && $0.key <= to }
    }

    func sleep(from: Day, to: Day) async throws -> [HealthSleepNight] {
        let predicate = HKQuery.predicateForSamples(withStart: start(of: from).addingTimeInterval(-C.nightLeadHours * 3600), end: start(of: to.adding(days: 1)))
        let samples: [HKCategorySample] = try await samples(HKCategoryType(.sleepAnalysis), predicate: predicate)
        let staged = samples.contains { [HKCategoryValueSleepAnalysis.asleepDeep, .asleepREM, .asleepCore].map(\.rawValue).contains($0.value) }
        let grouped = Dictionary(grouping: samples) { Day.today(in: .current, now: $0.endDate) }
        return grouped.compactMap { day, items -> HealthSleepNight? in
            guard day >= from, day <= to else { return nil }
            func seconds(_ values: [HKCategoryValueSleepAnalysis]) -> Double {
                items.filter { values.map(\.rawValue).contains($0.value) }.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            }
            let deep = seconds([.asleepDeep]), rem = seconds([.asleepREM]), core = seconds([.asleepCore])
            let asleep = staged ? deep + rem + core : seconds([.asleepUnspecified])
            guard asleep > 0, let end = items.map(\.endDate).max() else { return nil }
            return HealthSleepNight(day: day, end: end, asleepSeconds: asleep, deepSeconds: deep, remSeconds: rem, coreSeconds: staged ? core : asleep, awakeSeconds: seconds([.awake]))
        }
        .sorted { $0.day < $1.day }
    }

    private func map(_ workout: HKWorkout, vo2: [HealthPoint]) -> HealthWorkout {
        func average(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? {
            workout.statistics(for: HKQuantityType(id))?.averageQuantity()?.doubleValue(for: unit)
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let steps = workout.statistics(for: HKQuantityType(.stepCount))?.sumQuantity()?.doubleValue(for: .count())
        let minutes = workout.duration / 60
        let day = Calendar.current.startOfDay(for: workout.startDate)
        return HealthWorkout(
            id: workout.uuid,
            kind: kind(workout.workoutActivityType),
            start: workout.startDate,
            end: workout.endDate,
            duration: workout.duration,
            distanceMeters: workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()),
            averageHeartRate: average(.heartRate, bpm),
            maxHeartRate: workout.statistics(for: HKQuantityType(.heartRate))?.maximumQuantity()?.doubleValue(for: bpm),
            elevationGain: (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter()),
            averagePower: average(.runningPower, .watt()),
            averageCadence: steps.flatMap { minutes > 0 ? $0 / minutes : nil },
            averageGroundContactMs: average(.runningGroundContactTime, .secondUnit(with: .milli)),
            averageVerticalOscillationCm: average(.runningVerticalOscillation, .meterUnit(with: .centi)),
            averageStrideMeters: average(.runningStrideLength, .meter()),
            vo2max: vo2.last { Calendar.current.isDate($0.date, inSameDayAs: day) || ($0.date <= workout.endDate && $0.date > day.addingTimeInterval(-C.vo2LookbackDays * 86_400)) }?.value,
            indoor: (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false
        )
    }

    private func kind(_ type: HKWorkoutActivityType) -> HealthWorkoutKind {
        switch type {
        case .running: .run
        case .walking, .hiking: .walk
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining, .highIntensityIntervalTraining: .strength
        default: .other
        }
    }

    private func laps(_ workout: HKWorkout) -> [HealthLap] {
        let events = workout.workoutEvents ?? []
        let segments = events.filter { $0.type == .segment }
        let chosen = segments.isEmpty ? events.filter { $0.type == .lap } : segments
        return chosen.map { HealthLap(start: $0.dateInterval.start, end: $0.dateInterval.end) }
    }

    private func cadence(predicate: NSPredicate) async throws -> [HealthPoint] {
        let found: [HKQuantitySample] = try await samples(HKQuantityType(.stepCount), predicate: predicate)
        return found.compactMap { sample in
            let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
            guard minutes > 0 else { return nil }
            return HealthPoint(date: sample.endDate, value: sample.quantity.doubleValue(for: .count()) / minutes)
        }
    }

    private func averageByDay(_ points: [HealthPoint]) -> [Day: Double] {
        Dictionary(grouping: points) { Day.today(in: .current, now: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.value } / Double($0.count) }
    }

    private func start(of day: Day) -> Date {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
    }

    private func workoutSample(id: UUID) async throws -> HKWorkout? {
        let found: [HKWorkout] = try await samples(HKObjectType.workoutType(), predicate: HKQuery.predicateForObject(with: id))
        return found.first
    }

    private func quantities(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async throws -> [HealthPoint] {
        try await points(id, unit: unit, predicate: HKQuery.predicateForSamples(withStart: from, end: to))
    }

    private func points(_ id: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async throws -> [HealthPoint] {
        let found: [HKQuantitySample] = try await samples(HKQuantityType(id), predicate: predicate)
        return found.map { HealthPoint(date: $0.endDate, value: $0.quantity.doubleValue(for: unit)) }
    }

    private func samples<T: HKSample>(_ type: HKSampleType, predicate: NSPredicate) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [T]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func route(for workout: HKWorkout) async throws -> [HealthRoutePoint] {
        let routes: [HKWorkoutRoute] = try await samples(HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: workout))
        var points: [HealthRoutePoint] = []
        for route in routes {
            points += try await locations(route)
        }
        return points.sorted { $0.date < $1.date }
    }

    private func locations(_ route: HKWorkoutRoute) async throws -> [HealthRoutePoint] {
        try await withCheckedThrowingContinuation { continuation in
            nonisolated(unsafe) var collected: [HealthRoutePoint] = []
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                collected += (locations ?? []).map {
                    HealthRoutePoint(date: $0.timestamp, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, altitude: $0.verticalAccuracy >= 0 ? $0.altitude : nil)
                }
                if done { continuation.resume(returning: collected) }
            }
            store.execute(query)
        }
    }
}
