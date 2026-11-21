import Foundation
import SwiftUI
import Testing
@testable import trAIning

@Suite struct StrengthDayPickerTests {
    @Test func captionNamesTheDayAndTheTakenDays() {
        #expect(TrainerStrengthText.dayCaption(selected: 2, blocked: []) == "Terça")
        #expect(TrainerStrengthText.dayCaption(selected: 2, blocked: [4]) == "Terça · quinta já tem treino no plano")
        #expect(TrainerStrengthText.dayCaption(selected: 1, blocked: [6, 4]) == "Segunda · quinta e sábado já têm treino no plano")
    }

    @Test func lettersFollowTheWeek() {
        #expect(TrainerStrengthConstants.weekdayLetters == ["S", "T", "Q", "Q", "S", "S", "D"])
    }

    @MainActor @Test func pickerRenders() throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let view = StrengthDayPicker(weekday: .constant(2), blocked: [4])
            .brandCard()
            .padding(16)
            .frame(width: 440)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try image.pngData()?.write(to: URL(filePath: dir).appending(path: "strength-day-picker.png"))
    }
}
