enum StrengthLoadSuggestionConstants {
    static let firstTimeShare = 0.8
    static let unilateralShare = 0.5
    static let perHandShare = 0.5
    static let increments: [StrengthEquipment: Double] = [
        .barbell: 2.5, .machine: 2.5, .cable: 2.5, .dumbbell: 1, .kettlebell: 2, .medicineBall: 1,
    ]
    static let handheld: Set<StrengthEquipment> = [.dumbbell, .kettlebell]
}
