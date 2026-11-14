import FITReader
import Foundation
import Narrative
import WorkoutAnalysis

enum WorkoutFeedback {
    private typealias C = WorkoutFeedbackConstants

    private struct Group {
        let kind: FindingKind
        let group: FindingGroup
        let status: BlockStatus?
        var findings: [Finding]
    }

    static func summary(assessment: WorkoutAssessment, blocks: [WorkoutBlock]) -> WorkoutAnalysisSummary {
        let groups = grouped(assessment.positives + assessment.negatives + assessment.attention, blocks: blocks)
        let entries = groups.enumerated().map { index, group in
            AnalysisEntry(
                id: index,
                tag: tag(group),
                title: title(group, blocks: blocks),
                evidence: evidence(group, blocks: blocks),
                why: why(group, blocks: blocks)
            )
        }
        return WorkoutAnalysisSummary(feedback: feedback(entries, blocks: blocks), next: next(groups), entries: entries)
    }

    private static func grouped(_ findings: [Finding], blocks: [WorkoutBlock]) -> [Group] {
        var groups: [Group] = []
        for finding in findings {
            let status = finding.kind == .blockOffTarget || finding.kind == .stepIncomplete
                ? finding.blockOrdinal.flatMap { blocks.indices.contains($0) ? blocks[$0].status : nil }
                : nil
            if finding.blockOrdinal != nil,
               let index = groups.firstIndex(where: { $0.kind == finding.kind && $0.status == status && $0.findings.first?.blockOrdinal != nil }) {
                groups[index].findings.append(finding)
            } else {
                groups.append(Group(kind: finding.kind, group: finding.group, status: status, findings: [finding]))
            }
        }
        return groups.sorted { rank($0) < rank($1) }
    }

    private static func rank(_ group: Group) -> Int {
        C.priority.firstIndex(of: group.kind) ?? C.priority.count
    }

    private static func tag(_ group: Group) -> AnalysisTag {
        guard group.group == .positive else { return .fix }
        return WorkoutDetailConstants.expectedKinds.contains(group.kind) ? .expected : .good
    }

    private static func positions(_ group: Group) -> [Int] {
        group.findings.compactMap(\.blockOrdinal)
    }

    private static func title(_ group: Group, blocks: [WorkoutBlock]) -> String {
        guard let first = group.findings.first else { return "" }
        let name = BlockNaming.name(positions(group), blocks: blocks)
        let subject = name?.text ?? ""
        let text: String
        switch group.kind {
        case .blockOffTarget:
            switch group.status {
            case .faster: text = "\(subject) \(agree(C.faster, name))"
            case .aboveTarget: text = "\(subject) \(C.heartRateAbove)"
            case .belowTarget: text = "\(subject) \(C.heartRateBelow)"
            default: text = "\(subject) \(agree(C.slower, name))"
            }
        case .stepIncomplete:
            text = "\(subject) \(agree(group.status == .notExecuted ? C.notExecuted : C.incomplete, name))"
        case .zoneAboveTarget:
            let zone = group.findings.compactMap { $0.facts[FindingFact.zone] }.max() ?? 0
            text = "\(subject) \(String(format: C.zoneFormat, Int(zone)))"
        case .cardiacDrift: text = "\(subject) \(C.drift)"
        case .paceFade: text = "\(subject) \(C.fade)"
        case .goodRecovery: text = "\(subject) \(C.recovered)"
        case .lowerHeartRateThanBefore: text = "\(subject) \(C.lowerHeartRate)"
        case .steadyPace: text = "\(subject) \(C.steady)"
        case .blockInTarget:
            let inTarget = Int(first.facts[FindingFact.inTarget] ?? 0)
            let total = Int(first.facts[FindingFact.total] ?? 0)
            text = inTarget == total
                ? String(format: C.allInTargetFormat, total, targetedNoun(blocks))
                : String(format: C.inTargetFormat, inTarget, total, targetedNoun(blocks))
        case .hardOnLowReadiness, .highAcuteChronic:
            text = TemplateNarrator.text(first, blocks: blocks)
        }
        return capitalized(text.trimmingCharacters(in: .whitespaces))
    }

    private static func evidence(_ group: Group, blocks: [WorkoutBlock]) -> String? {
        guard let first = group.findings.first else { return nil }
        guard group.findings.count > 1 else { return FindingDetail.evidence(first, blocks: blocks) }
        switch group.kind {
        case .blockOffTarget:
            let facts = first.facts
            if group.status == .aboveTarget || group.status == .belowTarget {
                let values = group.findings.compactMap { $0.facts[FindingFact.heartRate].map { String(Int($0.rounded())) } }
                let range = [facts[FindingFact.targetLow], facts[FindingFact.targetHigh]].compactMap { $0.map { String(Int($0.rounded())) } }
                return join([list(values) + " bpm", range.count == 2 ? "\(C.target) \(range[0])–\(range[1]) bpm" : nil])
            }
            let values = group.findings.compactMap { WorkoutListModel.paceClock(metersPerSecond: $0.facts[FindingFact.speed]) }
            let range = [facts[FindingFact.targetHigh], facts[FindingFact.targetLow]].compactMap { WorkoutListModel.paceClock(metersPerSecond: $0) }
            return join([list(values) + " \(WorkoutConstants.paceUnit)", range.count == 2 ? "\(C.target) \(range[0])–\(range[1])" : nil])
        case .zoneAboveTarget:
            let rates = group.findings.compactMap { $0.facts[FindingFact.heartRate].map { String(Int($0.rounded())) } }
            let paces = group.findings.compactMap { WorkoutListModel.paceClock(metersPerSecond: $0.facts[FindingFact.speed]) }
            return join([rates.isEmpty ? nil : list(rates) + " bpm", paces.isEmpty ? nil : "\(C.jogAt) \(list(paces)) \(WorkoutConstants.paceUnit)"])
        case .cardiacDrift:
            let parts = group.findings.compactMap { finding -> String? in
                guard let from = finding.facts[FindingFact.fromHR], let to = finding.facts[FindingFact.toHR], let rise = finding.facts[FindingFact.rise] else { return nil }
                return String(format: C.driftFormat, Int(from.rounded()), Int(to.rounded()), Int((rise * 100).rounded()))
            }
            return parts.isEmpty ? nil : list(parts)
        case .goodRecovery:
            let drops = group.findings.compactMap { $0.facts[FindingFact.drop] }.map { Int($0.rounded()) }
            guard let low = drops.min(), let high = drops.max() else { return nil }
            return String(format: C.fromPeakFormat, low, high)
        case .lowerHeartRateThanBefore:
            let pairs = group.findings.compactMap { finding -> String? in
                guard let now = finding.facts[FindingFact.heartRate], let before = finding.facts[FindingFact.beforeHeartRate] else { return nil }
                return "\(Int(now.rounded())) \(C.versus) \(Int(before.rounded())) bpm"
            }
            return pairs.isEmpty ? nil : pairs.joined(separator: " · ") + ", \(C.samePace)"
        default:
            return join(group.findings.map { FindingDetail.evidence($0, blocks: blocks) })
        }
    }

    private static func why(_ group: Group, blocks: [WorkoutBlock]) -> String {
        guard let first = group.findings.first else { return "" }
        switch group.kind {
        case .blockOffTarget where group.status == .slower && group.findings.count > 1:
            if let highest = group.findings.first(where: { $0.facts[FindingFact.recoveryHighest] == 1 }),
               let position = highest.blockOrdinal, let bpm = highest.facts[FindingFact.recoveryHeartRate] {
                return String(format: C.whyHighestRecoveryFormat, BlockNaming.single(position, blocks: blocks).text, Int(bpm.rounded()))
            }
            return C.whySlowerGroup
        case .zoneAboveTarget:
            let base = FindingDetail.why(first, blocks: blocks)
            let slowedNext = positions(group).compactMap { position in
                blocks.indices.dropFirst(position + 1).first { blocks[$0].kind == .active }
            }.first { blocks[$0].status == .slower }
            guard let slowedNext else { return base }
            return base + String(format: C.whyNextBlockFormat, BlockNaming.single(slowedNext, blocks: blocks).text)
        default:
            return FindingDetail.why(first, blocks: blocks)
        }
    }

    private static func feedback(_ entries: [AnalysisEntry], blocks: [WorkoutBlock]) -> [String] {
        var paragraphs = [opening(blocks)].compactMap { $0 }
        let fixes = entries.filter { $0.tag == .fix }.prefix(2)
        if !fixes.isEmpty {
            paragraphs.append(C.fixesLead + lowerFirst(sentences(Array(fixes))))
        }
        let goods = entries.filter { $0.tag == .good }.prefix(2)
        if !goods.isEmpty {
            paragraphs.append(C.goodsLead + lowerFirst(sentences(Array(goods))))
        }
        return paragraphs
    }

    private static func opening(_ blocks: [WorkoutBlock]) -> String? {
        let actives = blocks.filter { $0.kind == .active }
        let targeted = actives.filter(hasTarget)
        let source = targeted.isEmpty ? blocks : actives
        let distance = source.reduce(0) { $0 + $1.distance }
        let seconds = source.reduce(0) { $0 + $1.seconds }
        guard distance > 0 else { return nil }
        let pace = WorkoutListModel.clockText(seconds / (distance / WorkoutConstants.metersPerKilometer))
        guard !targeted.isEmpty else {
            return String(format: C.openingFreeFormat, WorkoutListModel.distanceText(distance).replacingOccurrences(of: " km", with: ""), pace)
        }
        let inTarget = targeted.filter { $0.status == .inTarget }.count
        let noun = targetedNoun(blocks)
        if inTarget == targeted.count { return String(format: C.openingAllFormat, targeted.count, noun, pace) }
        let format = inTarget * 2 >= targeted.count ? C.openingGoodFormat : C.openingShortFormat
        return String(format: format, inTarget, targeted.count, noun, pace)
    }

    private static func next(_ groups: [Group]) -> String? {
        guard let fix = groups.first(where: { tag($0) == .fix }) else { return C.nextRepeat }
        guard fix.kind == .blockOffTarget else { return C.nextTips[fix.kind] ?? C.nextRepeat }
        switch fix.status {
        case .faster: return C.nextFaster
        case .aboveTarget: return C.nextHeartRateAbove
        case .belowTarget: return C.nextHeartRateBelow
        default: return C.nextSlower
        }
    }

    private static func targetedNoun(_ blocks: [WorkoutBlock]) -> String {
        typealias N = BlockNamingConstants
        let targeted = blocks.filter { $0.kind == .active && hasTarget($0) }
        let repeats = !targeted.isEmpty && targeted.allSatisfy { $0.label.hasPrefix(WorkoutDetailConstants.repeatLabelPrefix) }
        let noun = repeats ? N.repeatPlural : N.blockPlural
        let sizes = Set(targeted.compactMap { $0.prescribed.flatMap { BlockNaming.durationText($0.duration) } })
        guard sizes.count == 1, let size = sizes.first else { return noun }
        return "\(noun) \(N.of) \(size)"
    }

    private static func hasTarget(_ block: WorkoutBlock) -> Bool {
        guard let target = block.prescribed?.target else { return false }
        return target != .open
    }

    private static func agree(_ forms: (String, String, String, String), _ name: BlockName?) -> String {
        switch (name?.feminine ?? false, name?.plural ?? false) {
        case (false, false): forms.0
        case (false, true): forms.1
        case (true, false): forms.2
        case (true, true): forms.3
        }
    }

    private static func list(_ values: [String]) -> String {
        guard values.count > 1 else { return values.first ?? "" }
        return values.dropLast().joined(separator: ", ") + " \(C.and) " + values[values.count - 1]
    }

    private static func join(_ parts: [String?]) -> String? {
        let text = parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    private static func sentences(_ entries: [AnalysisEntry]) -> String {
        entries.map { entry in entry.evidence.map { "\(entry.title) (\($0))." } ?? "\(entry.title)." }.joined(separator: " ")
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    private static func lowerFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + text.dropFirst()
    }
}
