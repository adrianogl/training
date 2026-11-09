import FITSwiftSDK

enum WorkoutStructureReader {
    static func structure(workouts: [WorkoutMesg], steps: [WorkoutStepMesg], laps: [LapMesg], origin: Double?) -> WorkoutStructure {
        WorkoutStructure(
            prescription: prescription(workout: workouts.first, steps: steps),
            laps: lapSummaries(laps, origin: origin)
        )
    }

    private static func prescription(workout: WorkoutMesg?, steps: [WorkoutStepMesg]) -> WorkoutPrescription? {
        guard workout != nil || !steps.isEmpty else { return nil }
        let prescribed = steps.enumerated().map { position, step in
            PrescribedStep(
                index: step.getMessageIndex().map(Int.init) ?? position,
                intensity: intensity(step.getIntensity()) ?? .active,
                duration: duration(of: step),
                target: target(of: step)
            )
        }
        return WorkoutPrescription(
            name: workout?.getWktName(),
            description: workout?.getWktDescription(),
            steps: prescribed.sorted { $0.index < $1.index }
        )
    }

    private static func duration(of step: WorkoutStepMesg) -> StepDuration {
        switch step.getDurationType() {
        case .distance:
            (try? step.getDurationDistance()).flatMap { $0 }.map { .distance(meters: $0) } ?? .open
        case .time:
            (try? step.getDurationTime()).flatMap { $0 }.map { .time(seconds: $0) } ?? .open
        case .repeatUntilStepsCmplt:
            if let from = step.getDurationValue(), let count = step.getTargetValue() {
                .repeatSteps(fromIndex: Int(from), count: Int(count))
            } else {
                .open
            }
        default:
            .open
        }
    }

    private static func target(of step: WorkoutStepMesg) -> StepTarget {
        switch step.getTargetType() {
        case .speed:
            speedTarget(of: step)
        case .heartRate:
            heartRateTarget(of: step)
        default:
            .open
        }
    }

    private static func speedTarget(of step: WorkoutStepMesg) -> StepTarget {
        let low = (try? step.getCustomTargetSpeedLow()).flatMap { $0 } ?? 0
        let high = (try? step.getCustomTargetSpeedHigh()).flatMap { $0 } ?? 0
        guard low > 0 || high > 0 else { return .open }
        return .speed(low: low, high: high)
    }

    private static func heartRateTarget(of step: WorkoutStepMesg) -> StepTarget {
        let low = Int((try? step.getCustomTargetHeartRateLow()).flatMap { $0 } ?? 0)
        let high = Int((try? step.getCustomTargetHeartRateHigh()).flatMap { $0 } ?? 0)
        if low == 0 && high == 0 {
            guard let zone = (try? step.getTargetHrZone()).flatMap({ $0 }),
                  FITReaderConstants.heartRateZones.contains(Int(zone)) else { return .open }
            return .heartRateZone(Int(zone))
        }
        let offset = FITReaderConstants.heartRateBpmOffset
        if low > offset || high > offset {
            return .heartRateBpm(low: max(low - offset, 0), high: max(high - offset, 0))
        }
        return .heartRatePercentMax(low: low, high: high)
    }

    private static func lapSummaries(_ laps: [LapMesg], origin: Double?) -> [LapSummary] {
        let starts = laps.map { $0.getStartTime()?.date.timeIntervalSince1970 }
        let base = origin ?? starts.compactMap { $0 }.min() ?? 0
        return zip(laps, starts).map { lap, start in
            LapSummary(
                stepIndex: lap.getWktStepIndex().map(Int.init),
                intensity: intensity(lap.getIntensity()),
                trigger: trigger(lap.getLapTrigger()),
                startOffset: start.map { $0 - base } ?? 0,
                timerSeconds: lap.getTotalTimerTime() ?? 0,
                distance: lap.getTotalDistance() ?? 0,
                avgSpeed: lap.getEnhancedAvgSpeed() ?? lap.getAvgSpeed(),
                avgHeartRate: lap.getAvgHeartRate().map(Int.init),
                maxHeartRate: lap.getMaxHeartRate().map(Int.init)
            )
        }
    }

    private static func intensity(_ value: Intensity?) -> StepIntensity? {
        switch value {
        case .active, .interval: .active
        case .rest: .rest
        case .warmup: .warmup
        case .cooldown: .cooldown
        case .recovery: .recovery
        case .other: .other
        case .invalid, nil: nil
        }
    }

    private static func trigger(_ value: LapTrigger?) -> String? {
        switch value {
        case .manual: "manual"
        case .time: "time"
        case .distance: "distance"
        case .positionStart: "position_start"
        case .positionLap: "position_lap"
        case .positionWaypoint: "position_waypoint"
        case .positionMarked: "position_marked"
        case .sessionEnd: "session_end"
        case .fitnessEquipment: "fitness_equipment"
        case .invalid, nil: nil
        }
    }
}
