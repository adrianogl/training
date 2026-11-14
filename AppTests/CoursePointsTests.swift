import Testing
@testable import trAIning

@Suite struct CoursePointsTests {
    @Test func findsClimbsAboveTwoPercentOverFourHundredMeters() {
        var profile: [GPXPoint] = (0...70).map { GPXPoint(distance: Double($0) * 100, altitude: 800) }
        for index in 30...36 { profile[index] = GPXPoint(distance: Double(index) * 100, altitude: 800 + Double(index - 29) * 3) }
        for index in 37...70 { profile[index] = GPXPoint(distance: Double(index) * 100, altitude: 821) }

        let climbs = CoursePointsBuilder.climbs(profile)

        #expect(climbs.count == 1)
        #expect(climbs.first?.startKm == 2.9)
        #expect(climbs.first?.gain == 21)
    }

    @Test func gelsEveryFortyMinutesAndWaterParsing() {
        #expect(CoursePointsBuilder.gels(distance: 21_097.5, targetSeconds: 5_520) == [9, 18])
        #expect(CoursePointsBuilder.water("15, 5,10") == [5, 10, 15])
    }
}
