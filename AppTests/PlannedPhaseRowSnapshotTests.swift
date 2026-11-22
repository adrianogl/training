import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct PlannedPhaseRowSnapshotTests {
    @Test func stridesAndRecoveryFitTheColumn() throws {
        let phases = [
            BriefingPhase(when: "Bloco", length: "28:54–30:18", title: "6 km · 4:49–5:03/km", detail: ""),
            BriefingPhase(when: "6×", length: "0:23–0:24 cada", title: "100 m · 3:51–3:57/km", detail: ""),
            BriefingPhase(when: "Recuperação", length: "1:00", title: "Parado", detail: ""),
        ]
        let card = VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                if index > 0 { Divider().overlay(BrandColors.line) }
                PlannedPhaseRow(phase: phase)
            }
        }
        .frame(width: 360)
        .brandCard()
        try TrainerDaysVolumeSnapshotTests.save(card, name: "planned-phase-rows")
    }
}
