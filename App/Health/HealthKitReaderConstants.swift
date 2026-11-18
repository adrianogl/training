import HealthKit

enum HealthKitReaderConstants {
    static let quantityTypes: [HKQuantityTypeIdentifier] = [
        .heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .distanceWalkingRunning, .runningSpeed, .runningPower,
        .runningGroundContactTime, .runningVerticalOscillation, .runningStrideLength, .stepCount, .vo2Max,
    ]
    static let nightLeadHours = 6.0
    static let nightStartHour = 18
    static let nightEndHour = 11
    static let vo2LookbackDays = 14.0
}
