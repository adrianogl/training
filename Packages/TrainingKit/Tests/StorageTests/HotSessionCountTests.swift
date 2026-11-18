import Foundation
import Testing
@testable import Storage

@Test func hotSessionCountsMatchTheSlowCount() {
    let base = Date(timeIntervalSince1970: 1_800_000_000)
    let records = (0..<30).map { index in
        let record = ActivityRecord(activityId: Int64(index), typeKey: index % 7 == 0 ? "cycling" : "running", name: "Corrida", start: base.addingTimeInterval(Double(index) * 86_400))
        record.weatherTemperature = index % 3 == 0 ? 18 : 30
        record.weatherDewPoint = index % 3 == 0 ? 10 : 22
        return record
    }
    let counts = ActivityRecord.hotSessionCounts(records)
    for record in records where record.typeKey == "running" {
        #expect(counts[record.activityId] == record.hotSessions(among: records))
    }
    #expect((counts.values.max() ?? 0) > 0)
}
