struct CourseClimb: Equatable {
    let startKm: Double
    let endKm: Double
    let gain: Double
}

struct CoursePoints: Equatable {
    let climbs: [CourseClimb]
    let water: [Double]
    let gels: [Double]
}
