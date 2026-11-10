import Foundation

extension RaceRecord {
    public var manualPaces: [Int: Double] {
        get { manualPacesData.flatMap { try? JSONDecoder().decode([Int: Double].self, from: $0) } ?? [:] }
        set { manualPacesData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }
}
