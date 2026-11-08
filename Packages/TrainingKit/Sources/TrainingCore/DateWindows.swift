public func windows(from start: Day, to end: Day, maxDays: Int) -> [ClosedRange<Day>] {
    guard maxDays > 0, start <= end else { return [] }
    var result: [ClosedRange<Day>] = []
    var cursor = start
    while cursor <= end {
        let windowEnd = min(cursor.adding(days: maxDays - 1), end)
        result.append(cursor...windowEnd)
        cursor = windowEnd.adding(days: 1)
    }
    return result
}
