public enum MovementPattern: String, Codable, Sendable, CaseIterable {
    case squat, hinge, singleLeg, calf, hipStability, plyo
    case horizontalPush, horizontalPull, verticalPush, verticalPull
    case antiExtension, antiRotation, lateralCore
    case mobilityHip, mobilityAnkle, mobilityThoracic
}

public enum BodyRegion: String, Codable, Sendable, CaseIterable {
    case knee, calfAchilles, lowerBack, hip, shoulder
}

public enum StrengthPlace: String, Codable, Sendable, CaseIterable {
    case gym, home, bodyweight
}

public enum StrengthEquipment: String, Codable, Sendable, CaseIterable {
    case barbell, machine, cable, dumbbell, kettlebell, medicineBall, suspension, swissBall, band, bodyweight
}

public struct CatalogExercise: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let category: String
    public let exerciseName: String
    public let pattern: MovementPattern
    public let focus: Set<TrainerStrengthGroup>
    public let equipment: StrengthEquipment
    public let loads: Set<BodyRegion>
    public let unilateral: Bool
    public let timed: Bool

    public init(
        id: String, name: String, category: String, exerciseName: String, pattern: MovementPattern,
        focus: Set<TrainerStrengthGroup>, equipment: StrengthEquipment, loads: Set<BodyRegion> = [],
        unilateral: Bool = false, timed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.exerciseName = exerciseName
        self.pattern = pattern
        self.focus = focus
        self.equipment = equipment
        self.loads = loads
        self.unilateral = unilateral
        self.timed = timed
    }

    public func fits(_ place: StrengthPlace) -> Bool {
        StrengthCatalogConstants.equipmentByPlace[place]?.contains(equipment) ?? false
    }

    public var isMobility: Bool {
        StrengthCatalogConstants.mobilityPatterns.contains(pattern)
    }
}
