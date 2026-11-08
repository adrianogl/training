import FITReader
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

    @Test func templatesNeverEmpty() {
        let blocks = buildBlocks(F.intervalStructure(), zones: nil)
        let cases: [(Finding, String)] = [
            (Finding(group: .positive, kind: .blockInTarget, blockOrdinal: nil, facts: [FindingFact.inTarget: 5, FindingFact.total: 6]), "5 de 6"),
            (Finding(group: .positive, kind: .steadyPace, blockOrdinal: 1, facts: [FindingFact.spread: 4]), "4 s/km"),
            (Finding(group: .positive, kind: .lowerHeartRateThanBefore, blockOrdinal: 1, facts: [FindingFact.delta: 5]), "5 bpm"),
            (Finding(group: .positive, kind: .goodRecovery, blockOrdinal: 2, facts: [FindingFact.drop: 31]), "31 bpm"),
            (Finding(group: .negative, kind: .blockOffTarget, blockOrdinal: 1, facts: [
                FindingFact.speed: 1_000.0 / 245, FindingFact.targetLow: 1_000.0 / 250, FindingFact.targetHigh: 1_000.0 / 240,
            ]), "4:05 /km"),
            (Finding(group: .negative, kind: .stepIncomplete, blockOrdinal: 1, facts: [
                FindingFact.distance: 800, FindingFact.seconds: 200, FindingFact.targetDistance: 1_000,
            ]), "800 m"),
            (Finding(group: .negative, kind: .paceFade, blockOrdinal: 1, facts: [FindingFact.fade: 9]), "9 s/km"),
            (Finding(group: .attention, kind: .cardiacDrift, blockOrdinal: 1, facts: [
                FindingFact.rise: 0.06, FindingFact.fromHR: 150, FindingFact.toHR: 159,
            ]), "159 bpm"),
            (Finding(group: .attention, kind: .zoneAboveTarget, blockOrdinal: 0, facts: [FindingFact.zone: 3]), "Z3"),
            (Finding(group: .attention, kind: .hardOnLowReadiness, blockOrdinal: nil, facts: [FindingFact.readiness: 42]), "42"),
            (Finding(group: .attention, kind: .highAcuteChronic, blockOrdinal: nil, facts: [FindingFact.ratio: 1.62]), "1,62"),
        ]
        let kinds: Set<FindingKind> = [
            .blockInTarget, .steadyPace, .lowerHeartRateThanBefore, .goodRecovery, .blockOffTarget, .stepIncomplete,
            .paceFade, .cardiacDrift, .zoneAboveTarget, .hardOnLowReadiness, .highAcuteChronic,
        ]
        #expect(Set(cases.map(\.0.kind)) == kinds)
        for (finding, number) in cases {
            let text = FindingTemplates.text(finding, blocks: blocks)
            #expect(!text.isEmpty, "\(finding.kind)")
            #expect(text.contains(number), "\(finding.kind): \(text)")
        }
        let offTarget = FindingTemplates.text(cases[4].0, blocks: blocks)
        #expect(offTarget.contains("Tiro 1"))
        #expect(offTarget.contains("4:00–4:10"))
    }
}
