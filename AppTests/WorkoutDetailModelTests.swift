import TrainingCore
import FITReader
import Narrative
import Foundation
import Storage
import SwiftData
import Testing
import WorkoutAnalysis
@testable import trAIning

@MainActor
@Suite struct WorkoutDetailModelTests {
    private typealias F = WorkoutDetailFixtures

    @Test func buildsFromStoredStructure() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(F.run(id: 1, meters: 5_900, workoutName: "Tiros 3 x 1 km", structure: F.intervalStructure()))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        #expect(model.structureMissing == false)
        #expect(model.hasPrescription)
        #expect(model.blocks.count == 8)
        #expect(model.blocks.map(\.label) == [
            "Aquecimento", "Tiro 1", "Recuperação 1", "Tiro 2", "Recuperação 2", "Tiro 3", "Recuperação 3", "Desaquecimento",
        ])
        #expect(model.blocks[1].status == .inTarget)
        #expect(model.summary?.paceText == "5:30 /km")
    }

    @Test func missingStructureFallsBackToKmSplits() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(F.run(
            id: 1, meters: 5_000, samples: F.samples(kilometers: 5, secondsPerKm: 300), processingVersion: 0
        ))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        #expect(model.structureMissing)
        #expect(model.hasPrescription == false)
        #expect(model.blocks.map(\.label) == ["Km 1", "Km 2", "Km 3", "Km 4", "Km 5"])
        #expect(model.blocks.allSatisfy { $0.status == .noTarget && $0.prescribed == nil })
    }

    @Test func continuousBlockOpensInKilometers() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(F.run(
            id: 1, meters: 8_000, workoutName: "Rodagem contínua",
            structure: F.continuousStructure(activeKilometers: 6),
            samples: F.samples(kilometers: 8, secondsPerKm: 300)
        ))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        #expect(model.blocks.map(\.label) == ["Aquecimento", "Bloco 1", "Desaquecimento"])
        #expect(Array(model.kilometers.keys) == [1])
        #expect(model.kilometers[1]?.map(\.label) == ["Km 1", "Km 2", "Km 3", "Km 4", "Km 5", "Km 6"])
        #expect(model.kilometers[1]?.allSatisfy { $0.status == .inTarget } == true)
        #expect(model.kilometerBars[1]?.count == 6)
        #expect(model.bars.count == 3)
        #expect(model.assessment.positives.contains { $0.kind == .steadyPace && $0.blockOrdinal == 1 })
    }

    @Test func comparisonUsesSameWorkoutName() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let name = "Tiros 3 x 1 km"
        context.insert(F.run(id: 1, meters: 5_900, workoutName: name, structure: F.intervalStructure()))
        context.insert(F.run(id: 2, daysAgo: 7, meters: 5_900, workoutName: name, structure: F.intervalStructure()))
        context.insert(F.run(id: 3, daysAgo: 14, meters: 5_900, workoutName: name, structure: F.intervalStructure()))
        context.insert(F.run(id: 4, daysAgo: 3, meters: 5_900, workoutName: "Outro treino", structure: F.intervalStructure()))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        let comparison = try #require(model.comparison)
        #expect(comparison.occurrences == [1, 2, 3])
        #expect(comparison.sameStructure)
        #expect(model.comparisonRows.map(\.activityId) == [1, 2, 3])
        #expect(model.comparisonRows.first?.isCurrent == true)
        #expect(model.comparisonRows.first?.inTargetText == "3/3")
    }

    @Test func comparisonWithoutCommonActiveBlockUsesEachOwnActiveBlocks() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(F.run(id: 1, meters: 4_000, workoutName: "Limiar", structure: F.singleBlockStructure()))
        context.insert(F.run(id: 2, daysAgo: 7, meters: 5_900, workoutName: "Limiar", structure: F.intervalStructure(tiroSeconds: 250)))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        let comparison = try #require(model.comparison)
        #expect(comparison.occurrences == [1, 2])
        #expect(comparison.blocks.map(\.label).contains("Aquecimento"))
        #expect(model.comparisonRows.map(\.paceText) == ["4:05", "4:10"])
        #expect(model.comparisonRows.map(\.heartRateText) == ["168", "168"])
        #expect(model.comparisonRows.map(\.inTargetText) == ["1/1", "3/3"])
        #expect(model.comparisonNotice == "A estrutura mudou; pace e FC são a média dos blocos ativos de cada treino.")
    }

    @Test func evolutionFollowsActiveSpeedDelta() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(F.run(id: 1, meters: 5_900, workoutName: "Tiros", structure: F.intervalStructure(tiroSeconds: 245)))
        context.insert(F.run(id: 2, daysAgo: 7, meters: 5_900, workoutName: "Tiros", structure: F.intervalStructure(tiroSeconds: 250)))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        let comparison = try #require(model.comparison)
        let delta = try #require(comparison.activeSpeedDelta)
        let currentSpeed = 1_000.0 / 245
        let paceDelta = 1_000 / currentSpeed - 1_000 / (currentSpeed - delta)
        #expect(Int(abs(paceDelta).rounded()) == 5)
        #expect(model.evolutionText?.hasPrefix("5 s/km mais rápido, FC igual") == true)
        #expect(model.comparisonNotice == nil)
    }

    @Test func freeRunComparesBySimilarDistance() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(F.run(id: 1, meters: 10_000, structure: F.freeStructure(kilometers: 10)))
        context.insert(F.run(id: 2, daysAgo: 30, meters: 9_000, structure: F.freeStructure(kilometers: 9)))
        context.insert(F.run(id: 3, daysAgo: 20, meters: 12_500, structure: F.freeStructure(kilometers: 12)))
        context.insert(F.run(id: 4, daysAgo: 120, meters: 10_500, structure: F.freeStructure(kilometers: 10)))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        #expect(model.hasPrescription == false)
        #expect(model.comparison?.occurrences == [1, 2])
        #expect(model.comparisonRows.map(\.paceText) == ["5:30", "5:30"])
        #expect(model.comparisonRows.allSatisfy { $0.inTargetText == nil })
    }

    private func storedNarrative(_ texts: (Int) -> [String], key: (WorkoutAnalysisContext) -> String) throws -> (WorkoutDetailModel, [String]) {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let record = F.run(id: 1, meters: 5_900, workoutName: "Tiros 3 x 1 km", structure: F.intervalStructure())
        context.insert(record)
        try context.save()
        let analysis = WorkoutAnalysisContext.build(record: record, records: [record], in: context)
        let stored = texts(analysis.assessment.orderedFindings.count)
        record.narrativeData = F.encoded(WorkoutNarrative(
            findings: stored, evolution: nil, generatedBy: NarrativeConstants.foundationModelsSource, factsKey: key(analysis)
        ))
        try context.save()
        return (WorkoutDetailModel(activityId: 1, context: context), stored)
    }

    @Test func screenUsesStoredNarrativeWhenKeyMatches() throws {
        let (model, stored) = try storedNarrative({ count in (0..<count).map { "Frase do modelo \($0)" } }) {
            NarrativeFacts.key($0.assessment, blocks: $0.blocks, evolution: $0.evolution)
        }

        #expect(!stored.isEmpty)
        #expect(model.reading.findings == stored)
        #expect(model.reading.findingsOnDevice)
    }

    @Test func screenFallsBackWhenFactsChangeWithSameCount() throws {
        let (model, stored) = try storedNarrative({ count in (0..<count).map { "Frase velha \($0)" } }) { _ in "chave-antiga" }

        let template = TemplateNarrator().narrative(model.assessment, blocks: model.blocks, evolution: nil)
        #expect(stored.count == template.findings.count)
        #expect(model.reading.findings == template.findings)
        #expect(model.reading.findingsOnDevice == false)
    }

    @Test func screenFallsBackWhenCountMismatch() throws {
        let (model, _) = try storedNarrative({ _ in Array(repeating: "Frase velha", count: 7) }) {
            NarrativeFacts.key($0.assessment, blocks: $0.blocks, evolution: $0.evolution)
        }

        let template = TemplateNarrator().narrative(model.assessment, blocks: model.blocks, evolution: nil)
        #expect(template.findings.count != 7)
        #expect(model.reading.findings == template.findings)
        #expect(model.reading.findingsOnDevice == false)
    }

    @Test func zonesNeedEveryFloor() {
        let complete = HeartRateZonesRecord(sport: "RUNNING", zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175, maxHeartRate: 190)
        let gap = HeartRateZonesRecord(sport: "RUNNING", zone1Floor: 100, zone2Floor: 120, zone4Floor: 160, zone5Floor: 175, maxHeartRate: 190)

        #expect(WorkoutAnalysisContext.zones(from: complete) == HeartRateZones(floors: [100, 120, 140, 160, 175], maxHeartRate: 190))
        #expect(WorkoutAnalysisContext.zones(from: gap) == nil)
    }

    @Test func detailShowsScoreForInterval() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let name = "Tiros 3 x 1 km"
        context.insert(HeartRateZonesRecord(sport: "DEFAULT", zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175, maxHeartRate: 190))
        context.insert(F.run(id: 1, meters: 5_900, workoutName: name, structure: F.intervalStructure()))
        context.insert(F.run(id: 2, daysAgo: 7, meters: 5_900, workoutName: name, structure: F.intervalStructure()))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        let score = try #require(model.score)
        #expect(score.value > 0)
        #expect(model.scoreRows.map(\.part) == [.execution, .intent, .cost])
        #expect(model.scoreRows.map(\.maximum) == [50, 25, 25])
        #expect(model.scoreRows[0].pointsText == "50/50")
    }

    @Test func freeRunScoreHasOnlyCost() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(HeartRateZonesRecord(sport: "DEFAULT", zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175, maxHeartRate: 190))
        context.insert(F.run(id: 1, meters: 5_000, structure: F.freeStructure(kilometers: 5)))
        context.insert(F.run(id: 2, daysAgo: 7, meters: 5_000, structure: F.freeStructure(kilometers: 5, secondsPerKm: 340)))
        try context.save()

        let model = WorkoutDetailModel(activityId: 1, context: context)

        #expect(model.score != nil)
        #expect(model.scoreRows.map(\.part) == [.cost])
        #expect(model.scoreRows[0].maximum == 25)
    }

    private func easyRunModel(activeTarget: StepTarget, threshold: Int?) throws -> WorkoutDetailModel {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(HeartRateZonesRecord(
            sport: "DEFAULT", zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175,
            maxHeartRate: 190, lactateThresholdHeartRate: threshold
        ))
        context.insert(F.run(id: 1, meters: 7_400, workoutName: "Rodagem leve", structure: F.easyStructure(activeTarget: activeTarget)))
        try context.save()
        return WorkoutDetailModel(activityId: 1, context: context)
    }

    @Test func scoreUsesThresholdZones() throws {
        let byThreshold = try easyRunModel(activeTarget: .open, threshold: 170)
        let byWatch = try easyRunModel(activeTarget: .open, threshold: nil)

        let intent = try #require(byThreshold.score?.items.first { $0.part == .intent })
        #expect(intent.points == intent.maximum)
        #expect(intent.reason == nil)
        let watchIntent = try #require(byWatch.score?.items.first { $0.part == .intent })
        #expect(watchIntent.points < watchIntent.maximum)
        #expect(watchIntent.reason == .easyTooHard)
    }

    @Test func zoneTargetBlockJudgedByThreshold() throws {
        let byThreshold = try easyRunModel(activeTarget: .heartRateZone(2), threshold: 170)
        let byWatch = try easyRunModel(activeTarget: .heartRateZone(2), threshold: nil)
        let bpmTarget = try easyRunModel(activeTarget: .heartRateBpm(low: 120, high: 139), threshold: 170)
        let percentTarget = try easyRunModel(activeTarget: .heartRatePercentMax(low: 60, high: 73), threshold: 170)

        #expect(byThreshold.blocks[1].status == .inTarget)
        #expect(byWatch.blocks[1].status == .aboveTarget)
        #expect(bpmTarget.blocks[1].status == .aboveTarget)
        #expect(percentTarget.blocks[1].status == .aboveTarget)
    }
}
