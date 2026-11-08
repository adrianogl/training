import Foundation
import GarminAPI
import Metrics
import Storage
import TrainingCore

extension SyncEngine {
    func syncDaily(from: Day, to: Day, progress: (Double) -> Void) async throws -> Set<Day> {
        typealias C = SyncConstants
        let summaryWindows = windows(from: from, to: to, maxDays: C.dailySummaryWindowDays)
        let hrvWindows = windows(from: from, to: to, maxDays: C.hrvWindowDays)
        let sleepWindows = windows(from: from, to: to, maxDays: C.sleepWindowDays)
        let batteryWindows = windows(from: from, to: to, maxDays: C.bodyBatteryWindowDays)
        let total = Double(summaryWindows.count + hrvWindows.count + sleepWindows.count + batteryWindows.count)
        var completed = 0.0
        var touched: Set<Day> = []
        var sleepEnds: [Day: Int64] = [:]

        for window in summaryWindows {
            for dto in try await source.dailySummaries(from: window.lowerBound, to: window.upperBound) {
                try upsertDaily(dto.day) { $0.apply(dto) }
                touched.insert(dto.day)
            }
            try modelContext.save()
            completed += 1
            progress(completed / total)
        }
        for window in hrvWindows {
            for dto in try await source.hrvSummaries(from: window.lowerBound, to: window.upperBound) {
                try upsertDaily(dto.day) { $0.apply(dto) }
                touched.insert(dto.day)
            }
            try modelContext.save()
            completed += 1
            progress(completed / total)
        }
        for window in sleepWindows {
            for dto in try await source.sleepSummaries(from: window.lowerBound, to: window.upperBound) {
                try upsertDaily(dto.day) { $0.apply(dto) }
                touched.insert(dto.day)
                sleepEnds[dto.day] = dto.sleepEndTimestampGMT
            }
            try modelContext.save()
            completed += 1
            progress(completed / total)
        }
        for window in batteryWindows {
            let days = try await source.bodyBattery(from: window.lowerBound, to: window.upperBound)
            let samplesByDay = Dictionary(days.map { ($0.day, $0.samples) }, uniquingKeysWith: +)
            for dto in days {
                let morningMax = sleepEnds[dto.day].flatMap { morningBodyBattery(day: dto.day, sleepEndMs: $0, samplesByDay: samplesByDay) }
                try upsertDaily(dto.day) { record in
                    if let morningMax { record.bodyBatteryMorningMax = morningMax }
                }
                touched.insert(dto.day)
            }
            try modelContext.save()
            completed += 1
            progress(completed / total)
        }
        return touched
    }

    private func morningBodyBattery(day: Day, sleepEndMs: Int64, samplesByDay: [Day: [BodyBatterySampleDTO]]) -> Int? {
        let samples = (-1...1).flatMap { samplesByDay[day.adding(days: $0)] ?? [] }
        let values = samples.compactMap { sample in
            sample.value.map { (Date(timeIntervalSince1970: Double(sample.timestampMs) / 1000), $0) }
        }
        return bodyBatteryMorningMax(values: values, sleepEnd: Date(timeIntervalSince1970: Double(sleepEndMs) / 1000))
    }
}
