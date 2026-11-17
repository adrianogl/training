import Foundation

public enum StrengthProgression {
    public static func next(_ record: StrengthLoadRecord?) -> Double? {
        guard let record else { return nil }
        guard record.completedAllSets else { return record.weight }
        let increase = max(StrengthGeneratorConstants.minimumIncrease, (record.weight * StrengthGeneratorConstants.progressionShare).rounded())
        return record.weight + increase
    }
}
