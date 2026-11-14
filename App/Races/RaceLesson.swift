import Foundation
import WorkoutAnalysis

enum RaceLesson {
    private typealias C = RaceLessonConstants

    static func columns(resultSeconds: Double?, goalSeconds: Double?, eveSeconds: Double?, splits: [RaceSplit]) -> AnalysisColumns {
        guard let resultSeconds else { return AnalysisColumns(negative: [], positive: [], expected: []) }
        var negative: [Lesson] = []
        var positive: [Lesson] = []
        var next: [Lesson] = []

        if let goalSeconds {
            let delta = resultSeconds - goalSeconds
            let pair = "\(clock(resultSeconds)) \(C.versus) \(clock(goalSeconds))"
            if delta > C.sameTimeSeconds {
                let why = eveSeconds.map { eve in
                    eve > goalSeconds + C.sameTimeSeconds
                        ? String(format: C.whyGoalAggressive, clock(eve), percent((eve - goalSeconds) / goalSeconds))
                        : C.whyGoalMissedOnDay
                } ?? C.whyGoalMissed
                negative.append(Lesson(String(format: C.aboveGoal, clock(delta)), pair, why))
                if let eveSeconds, eveSeconds > goalSeconds + C.sameTimeSeconds {
                    next.append(Lesson(C.nextUseEve, "\(C.eve) \(clock(eveSeconds)) \(C.versus) \(C.goal) \(clock(goalSeconds))", C.whyNextUseEve))
                }
            } else if delta < -C.sameTimeSeconds {
                positive.append(Lesson(String(format: C.belowGoal, clock(-delta)), pair, C.whyBelowGoal))
            }
        }

        if let eveSeconds {
            let delta = eveSeconds - resultSeconds
            if delta > C.sameTimeSeconds {
                positive.append(Lesson(
                    String(format: C.beatEve, clock(delta)),
                    "\(clock(resultSeconds)) \(C.versus) \(clock(eveSeconds))",
                    C.whyBeatEve
                ))
            }
        }

        let full = splits.filter { $0.distance >= RacesConstants.metersPerKm * C.fullSplitRatio }
        if full.count >= C.minimumSplits {
            let half = full.count / 2
            let first = Array(full.prefix(half))
            let second = Array(full.suffix(full.count - half))
            let firstPace = mean(first)
            let secondPace = mean(second)
            let difference = secondPace - firstPace
            let evidence = "\(C.km) \(range(first)): \(clock(firstPace)) · \(C.km) \(range(second)): \(clock(secondPace))"
            if difference > RacesConstants.evenSplitTolerance {
                negative.append(Lesson(String(format: C.paceDropped, Int(difference.rounded())), evidence, C.whyPaceDropped))
                let easing = max(C.minimumEasing, (difference / 2).rounded())
                let opening = Array(full.prefix(C.openingKm))
                next.append(Lesson(
                    String(format: C.nextStartSlower, Int(easing), opening.count),
                    String(format: C.nextStartTarget, clock(mean(opening) + easing), opening.count),
                    C.whyNextStartSlower
                ))
            } else if difference < -RacesConstants.evenSplitTolerance {
                positive.append(Lesson(String(format: C.negativeSplit, Int((-difference).rounded())), evidence, C.whyNegativeSplit))
            } else {
                positive.append(Lesson(C.evenSplit, evidence, C.whyEvenSplit))
            }
            if let last = full.last, full.count > C.minimumSplits {
                let before = median(full.dropLast().map(\.pace))
                let gain = before - last.pace
                if gain >= C.strongFinishSeconds {
                    positive.append(Lesson(
                        String(format: C.strongFinish, clock(last.pace), Int(gain.rounded())),
                        "\(C.median) \(clock(before))",
                        C.whyStrongFinish
                    ))
                }
            }
        }

        if next.isEmpty {
            next.append(Lesson(C.nextRepeat, nil, C.whyNextRepeat))
        }
        return AnalysisColumns(
            negative: items(negative, offset: 0),
            positive: items(positive, offset: negative.count),
            expected: items(next, offset: negative.count + positive.count)
        )
    }

    private struct Lesson {
        let title: String
        let evidence: String?
        let why: String

        init(_ title: String, _ evidence: String?, _ why: String) {
            self.title = title
            self.evidence = evidence
            self.why = why
        }
    }

    private static func items(_ lessons: [Lesson], offset: Int) -> [AnalysisItem] {
        lessons.enumerated().map { index, lesson in
            AnalysisItem(id: offset + index, text: lesson.title, evidence: lesson.evidence, why: lesson.why, blockOrdinal: nil)
        }
    }

    private static func clock(_ seconds: Double) -> String {
        WorkoutFormat.clock(seconds)
    }

    private static func percent(_ value: Double) -> String {
        TodayText.decimal(value * 100, fractionDigits: 1) + "%"
    }

    private static func mean(_ splits: [RaceSplit]) -> Double {
        splits.map(\.pace).reduce(0, +) / Double(max(splits.count, 1))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func range(_ splits: [RaceSplit]) -> String {
        guard let first = splits.first, let last = splits.last else { return "" }
        return "\(first.index + 1)–\(last.index + 1)"
    }
}
