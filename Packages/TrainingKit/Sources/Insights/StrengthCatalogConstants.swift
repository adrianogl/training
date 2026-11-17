enum StrengthCatalogConstants {
    static let equipmentByPlace: [StrengthPlace: Set<StrengthEquipment>] = [
        .gym: [.barbell, .machine, .cable, .dumbbell, .band, .bodyweight],
        .home: [.dumbbell, .band, .bodyweight],
        .bodyweight: [.bodyweight],
    ]
    static let mobilityPatterns: Set<MovementPattern> = [.mobilityHip, .mobilityAnkle, .mobilityThoracic]
}
