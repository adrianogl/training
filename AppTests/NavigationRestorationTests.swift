import Insights
import SwiftUI
import Testing
@testable import trAIning

@Suite struct NavigationRestorationTests {
    private func roundTrip<Route: Codable & Equatable>(_ path: [Route]) -> [Route] {
        NavigationRestoration.decodePath(NavigationRestoration.encode(path))
    }

    @Test func todayRoutesRoundTrip() {
        let path: [TodayRoute] = [.readiness, .workout(42)]
        #expect(roundTrip(path) == path)
    }

    @Test func workoutSelectionsRoundTrip() {
        let path: [WorkoutSelection] = [.activity(7), .planned(9)]
        #expect(roundTrip(path) == path)
        let selection: WorkoutSelection? = NavigationRestoration.decodeValue(NavigationRestoration.encode(WorkoutSelection.planned(3)))
        #expect(selection == .planned(3))
    }

    @Test func raceRoutesRoundTrip() {
        let path: [RaceRoute] = [.next(UUID()), .completed(UUID())]
        #expect(roundTrip(path) == path)
    }

    @Test func metricKindsRoundTrip() {
        let path: [MetricKind] = [MetricKind.allCases[0]]
        #expect(roundTrip(path) == path)
    }

    @Test func sectionsRoundTrip() {
        for section in AppSection.allCases {
            #expect(AppSection(rawValue: section.rawValue) == section)
        }
    }

    @Test func morePathRoundTrip() {
        var path = NavigationPath()
        path.append(AppSection.trainer)
        path.append(TrainerRoute.day("2026-11-15"))
        path.append(TrainerRoute.changes)
        let decoded = NavigationRestoration.decodeNavigationPath(NavigationRestoration.encode(path))
        #expect(decoded.count == 3)
        #expect(NavigationRestoration.encode(decoded) == NavigationRestoration.encode(path))
    }

    @Test func morePathWithSettingsRoundTrip() {
        var path = NavigationPath()
        path.append(AppSection.settings)
        path.append(SettingsGroup.notice)
        let decoded = NavigationRestoration.decodeNavigationPath(NavigationRestoration.encode(path))
        #expect(NavigationRestoration.encode(decoded) == NavigationRestoration.encode(path))
    }

    @Test func invalidDataFallsBackToRoot() {
        let garbage = Data("nao e json".utf8)
        let today: [TodayRoute] = NavigationRestoration.decodePath(garbage)
        let races: [RaceRoute] = NavigationRestoration.decodePath(garbage)
        let selection: WorkoutSelection? = NavigationRestoration.decodeValue(garbage)
        #expect(today.isEmpty)
        #expect(races.isEmpty)
        #expect(selection == nil)
        #expect(NavigationRestoration.decodeNavigationPath(garbage).isEmpty)
        #expect(NavigationRestoration.decodeNavigationPath(Data()).isEmpty)
    }

    @Test func unknownSectionFallsBackToToday() {
        #expect(NavigationRestoration.section("inexistente", allowed: AppConstants.compactTabs) == .today)
        #expect(NavigationRestoration.section(AppSection.trainer.rawValue, allowed: AppConstants.compactTabs) == .today)
        #expect(NavigationRestoration.section(AppSection.races.rawValue, allowed: AppConstants.compactTabs) == .races)
    }

    @Test func missingRouteTruncatesPath() {
        let path: [TodayRoute] = [.readiness, .workout(1), .workout(2)]
        let kept = NavigationRestoration.validPrefix(path) { route in
            if case .workout(let id) = route { return id != 2 }
            return true
        }
        #expect(kept == [.readiness, .workout(1)])
        let none = NavigationRestoration.validPrefix([TodayRoute.workout(2)]) { _ in false }
        #expect(none.isEmpty)
    }

    @Test func mirroredStatePushesAndPopsWithoutRevertingToPreviousValue() {
        var live: [TodayRoute] = []
        var stored = Data()
        func mutate(_ change: (inout [TodayRoute]) -> Void) {
            change(&live)
            stored = NavigationRestoration.encode(live)
        }
        mutate { $0.append(.readiness) }
        #expect(live == [.readiness])
        mutate { $0.append(.workout(5)) }
        #expect(live == [.readiness, .workout(5)])
        mutate { $0.removeLast() }
        #expect(live == [.readiness])
        let restored: [TodayRoute] = NavigationRestoration.decodePath(stored)
        #expect(restored == live)
    }
}
