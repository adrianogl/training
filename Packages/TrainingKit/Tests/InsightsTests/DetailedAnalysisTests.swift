import FITReader
import Foundation
import Storage
import Testing
@testable import Insights

@Suite struct DetailedAnalysisTests {
    @Test func splitsAndFadeForLongRunThatStopsShort() throws {
        let analysis = try #require(detailedScenario().analysis())

        #expect(analysis.kind == .long)
        #expect(analysis.splits.count == 12)
        #expect(analysis.splits.first?.paceSeconds == 271)
        #expect(analysis.splits.first?.heartRate == 159)
        #expect(analysis.splits.last?.heartRate == 170)
        #expect(analysis.fadeKm == 10)
        #expect(analysis.pauseKilometers.isEmpty)
    }

    @Test func kpisCompareWithTheEightSimilarRuns() throws {
        let analysis = try #require(detailedScenario().analysis())
        let kpis = analysis.kpis

        #expect(analysis.similar.count == 8)
        #expect(analysis.similar.map(\.activityId) == [1, 2, 3, 4, 5, 6, 7, 8])
        let completion = try #require(kpis.completionPercent)
        let completionAverage = try #require(kpis.completionAverage)
        let fadeAverage = try #require(kpis.fadeKmAverage)
        let drift = try #require(kpis.driftPercent)
        let driftAverage = try #require(kpis.driftAverage)
        #expect(abs(completion - 63.3) < 0.01)
        #expect(completionAverage == 93.1)
        #expect(kpis.fadeKm == 10)
        #expect(fadeAverage == 9.8)
        #expect(drift == 7.5)
        #expect(abs(driftAverage) < 4)
    }

    @Test func similarRunsKeepCompletionAndPauses() throws {
        let analysis = try #require(detailedScenario().analysis())

        #expect(analysis.current.percentOfDistance.map { abs($0 - 63.3) < 0.01 } == true)
        #expect(!analysis.current.isComplete)
        #expect(analysis.similar[0].isClean)
        #expect(analysis.similar[1].percentOfDistance == 75)
        #expect(!analysis.similar[1].isComplete)
        #expect(analysis.similar[1].fadeKm == 9)
        #expect(analysis.similar.filter(\.isClean).count == 6)
    }

    @Test func findingsFollowPriorityAndCapAtFiveKeepingOneGoodOne() throws {
        let analysis = try #require(detailedScenario().analysis())

        #expect(analysis.findings.map(\.kind) == [.completion, .fadeKm, .hrDrift, .startPace, .readiness])
        let start = try #require(analysis.finding(.startPace))
        #expect(start.tone == .fix)
        #expect(start.value("fastFaded") == 3)
        #expect(start.value("fastTotal") == 5)
        #expect(start.value("slowFaded") == 0)
        #expect(start.value("slowTotal") == 3)
        #expect(abs((start.value("startPace") ?? 0) - 271) < 0.001)
        #expect(start.text.contains("4:31/km"))
        #expect(start.text.contains("4:35/km"))
    }

    @Test func readinessFindingSeparatesLowFromHighDays() throws {
        let analysis = try #require(detailedScenario().analysis())
        let readiness = try #require(analysis.finding(.readiness))

        #expect(readiness.tone == .fix)
        #expect(readiness.value("lowCount") == 2)
        #expect(readiness.value("lowMean") == 72.5)
        #expect(readiness.value("highCount") == 6)
        #expect(readiness.value("highMean") == 100)
        #expect(readiness.value("readiness") == 58)
    }

    @Test func weekLoadComparesSevenDaysWithTheFourWeeksBefore() throws {
        let analysis = try #require(detailedScenario(todayReadiness: nil).analysis())
        let week = try #require(analysis.finding(.weekLoad))

        #expect(week.value("weekKm") == 34)
        #expect(week.value("weekAverageKm") == 21)
        let percent = try #require(week.value("percent"))
        #expect(abs(percent - (34.0 / 21 - 1) * 100) < 0.001)
        #expect(week.value("hadIntervals") == 1)
        #expect(week.tone == .fix)
    }

    @Test func completionFindingNeedsAPlan() throws {
        let plannedAnalysis = try #require(detailedScenario().analysis())
        let planned = try #require(plannedAnalysis.finding(.completion))
        let free = try #require(detailedScenario(plan: nil).analysis())

        #expect(planned.tone == .fix)
        #expect(planned.value("plannedKm") == 20)
        #expect(planned.title == "Fez 63% da distância planejada")
        #expect(free.finding(.completion) == nil)
    }

    @Test func recommendationsFollowTheSiteRules() throws {
        let analysis = try #require(detailedScenario().analysis())

        #expect(analysis.recommendations.map(\.kind) == [.fuel, .swapDay, .easeWeek])
        #expect(analysis.recommendations[0].title == "Gel no km 9")
        #expect(analysis.recommendations[0].number == 9)
        #expect(analysis.recommendations[0].reason == "O pace de hoje caiu a partir do km 10. Nos treinos parecidos, a queda costuma vir no km 9.")
        #expect(analysis.recommendations[1].title == "Treino forte em dia de prontidão 60 ou mais")
        #expect(analysis.recommendations[1].number == 72.5)
        #expect(analysis.recommendations[2].title == "Aliviar a semana antes do treino")
        #expect(abs(analysis.recommendations[2].number - (34.0 / 21 - 1) * 100) < 0.001)
    }

    @Test func fastStartWithEarlyFadeSuggestsTheMedianStartOfTheSteadyRuns() throws {
        let paces: [Double] = [271, 271, 271, 271, 271, 271, 271, 283, 291, 299, 299, 299]
        let analysis = try #require(detailedScenario(todayReadiness: 80, paces: paces).analysis())

        #expect(analysis.fadeKm == 8)
        #expect(analysis.recommendations.map(\.kind) == [.startPace, .fuel, .easeWeek])
        #expect(analysis.recommendations[0].title == "Primeiros 5 km a 4:40/km")
        #expect(analysis.recommendations[0].number == 280)
        #expect(analysis.recommendations[1].title == "Gel no km 7")
    }

    @Test func slowStartWithEarlyFadeGetsNoStartPaceAdvice() throws {
        let paces: [Double] = [285, 285, 285, 285, 285, 285, 285, 297, 305, 313, 313, 313]
        let analysis = try #require(detailedScenario(todayReadiness: 80, paces: paces).analysis())

        #expect(analysis.fadeKm == 8)
        #expect(!analysis.recommendations.contains { $0.kind == .startPace })
    }

    @Test func highReadinessSwapsTheDayAdviceOut() throws {
        let analysis = try #require(detailedScenario(todayReadiness: 80).analysis())

        #expect(analysis.finding(.readiness)?.tone == .info)
        #expect(analysis.recommendations.map(\.kind) == [.fuel, .easeWeek])
    }

    @Test func noGelAdviceWhenTheRunHeldUntilTheEnd() throws {
        let analysis = try #require(detailedScenario(todayFade: false, todayReadiness: 80).analysis())

        #expect(analysis.fadeKm == nil)
        #expect(analysis.recommendations.map(\.kind) == [.easeWeek])
        #expect(analysis.finding(.fadeKm) == nil)
    }

    @Test func easyRunsGetHeartRateAtPaceAndDrift() throws {
        let analysis = try #require(detailedScenario(name: "Rodagem", plan: nil).analysis())

        #expect(analysis.kind == .easy)
        #expect(analysis.findings.map(\.kind) == [.fadeKm, .hrDrift, .readiness, .weekLoad, .hrAtPace])
        let pace = try #require(analysis.finding(.hrAtPace))
        #expect(pace.tone == .good)
        let delta = try #require(pace.value("deltaBpm"))
        let first = try #require(pace.value("firstBpm"))
        let last = try #require(pace.value("lastBpm"))
        #expect(delta < -2)
        #expect(first > last)
        #expect(analysis.finding(.startPace) == nil)
        #expect(analysis.recommendations.contains { $0.kind == .fuel })
    }

    @Test func runsWithoutSamplesProduceNoAnalysis() {
        let record = makeRun(id: 1, offset: 0, name: "Longão", kilometers: 10, plan: 20)

        #expect(detailedAnalysis(record: record, history: [], daily: []) == nil)
    }

    @Test func similarRunsOutsideTheWindowOrOtherKindsAreLeftOut() throws {
        var scenario = detailedScenario()
        scenario.history.append(makeRun(id: 301, offset: 120, name: "Longão", kilometers: 20, paces: Array(repeating: 270, count: 20), plan: 20))
        scenario.history.append(makeRun(id: 302, offset: 5, name: "Tiros 5x1000", kilometers: 10, paces: Array(repeating: 250, count: 10)))
        let analysis = try #require(scenario.analysis())

        #expect(analysis.similar.count == 8)
        #expect(!analysis.similar.map(\.activityId).contains(301))
        #expect(!analysis.similar.map(\.activityId).contains(302))
    }

    @Test func similarRunsAreLimitedToTheEightMostRecent() throws {
        var scenario = detailedScenario()
        scenario.history.append(makeRun(id: 303, offset: 88, name: "Longão", kilometers: 20, paces: Array(repeating: 270, count: 20), plan: 20))
        let analysis = try #require(scenario.analysis())

        #expect(analysis.similar.count == 8)
        #expect(!analysis.similar.map(\.activityId).contains(303))
        #expect(analysis.readinessDays == 9)
    }

    @Test func goalNoteBecomesAFinding() throws {
        let goal = DetailedGoalNote(title: "Longo contínuo 16 km", status: "Quase", isMet: false, lines: ["Maior trecho: 12,7 km."])
        var scenario = detailedScenario()
        scenario.daily = []
        scenario.history = []
        let analysis = try #require(scenario.analysis(goals: [goal]))

        let finding = try #require(analysis.finding(.goal))
        #expect(finding.title == "Meta: Longo contínuo 16 km")
        #expect(finding.text == "Quase. Maior trecho: 12,7 km.")
        #expect(finding.tone == .info)
    }

    @Test func pausesFindingReportsTheLongestStretch() throws {
        var rows = [FITSample(t: 0, distance: 0)]
        var time = 0.0
        var distance = 0.0
        for km in 0..<8 {
            for _ in 0..<10 {
                time += 27
                distance += 100
                rows.append(FITSample(t: time, heartRate: 150, distance: distance))
            }
            if km == 3 {
                time += 60
                rows.append(FITSample(t: time, heartRate: 140, distance: distance))
            }
        }
        let record = makeRun(id: 100, offset: 0, name: "Longão", kilometers: 8, paces: nil)
        record.samplesData = try JSONEncoder().encode(rows)
        let analysis = try #require(detailedAnalysis(record: record, history: [], daily: []))

        let finding = try #require(analysis.finding(.pauses))
        #expect(finding.tone == .fix)
        #expect(finding.value("pauses") == 1)
        #expect(finding.text.hasPrefix("Foi 1 pausa, no km 4,0."))
        #expect(analysis.pauseKilometers == [4])
    }
}

@Suite struct DetailedAnalysisMathTests {
    @Test func fadeNeedsTheNextKilometerStillSlowerOrTheLastOne() {
        let spike = [270.0, 270, 270, 270, 285, 270, 270, 270]
        let fade = [270.0, 270, 270, 270, 285, 286, 270, 270]
        let partialRecovery = [270.0, 270, 270, 270, 280, 275, 270]

        #expect(fadeKilometer(spike) == nil)
        #expect(fadeKilometer(fade) == 5)
        #expect(fadeKilometer(partialRecovery) == 5)
        #expect(fadeKilometer([270, 270, 270, 270, 270, 290]) == 6)
    }

    @Test func fadeIgnoresTheFirstTwoKilometers() {
        #expect(fadeKilometer([300, 270, 270, 270, 270]) == nil)
        #expect(fadeKilometer([270, 285, 285, 285, 285]) == nil)
        #expect(fadeKilometer([270, 270, 285, 285]) == 3)
    }

    @Test func fadeNeedsEightSecondsOverTheMedian() {
        #expect(fadeKilometer([270, 270, 270, 277, 277, 277]) == nil)
        #expect(fadeKilometer([270, 270, 270, 278, 278, 270]) == 4)
    }

    @Test func decouplingComparesSpeedPerBeatBetweenHalves() throws {
        let splits = [DetailedSplit(km: 1, paceSeconds: 330, heartRate: 130)] + (2...5).map { DetailedSplit(km: $0, paceSeconds: $0 <= 3 ? 300 : 315, heartRate: $0 <= 3 ? 150 : 160) }
        let first = (1000.0 / 300) / 150
        let second = (1000.0 / 315) / 160

        let drift = try #require(decoupling(splits))
        #expect(abs(drift - (first - second) / first * 100) < 0.0001)
        #expect(decoupling(Array(splits.prefix(4))) == nil)
    }

    @Test func splitsIgnoreStoppedTimeAndTheLastPartialKilometer() {
        var rows = [FITSample(t: 0, distance: 0)]
        rows.append(FITSample(t: 300, distance: 1_000))
        rows.append(FITSample(t: 400, distance: 1_000))
        rows.append(FITSample(t: 700, distance: 2_000))
        rows.append(FITSample(t: 800, distance: 2_300))

        let splits = detailedSplits(rows)
        #expect(splits.map(\.paceSeconds) == [300, 300])
    }

    @Test func linearFitReturnsSlopeAndIntercept() throws {
        let fit = try #require(linearFit([(x: 0, y: 160), (x: 10, y: 158), (x: 20, y: 156)]))

        #expect(abs(fit.slope + 0.2) < 0.0001)
        #expect(abs(fit.intercept - 160) < 0.0001)
        #expect(linearFit([(x: 1, y: 1), (x: 1, y: 2)]) == nil)
    }
}
