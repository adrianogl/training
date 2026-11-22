import Foundation
import Insights
import SwiftUI
import UIKit
import Testing
@testable import trAIning

@MainActor
@Suite struct TrainerDaysVolumeSnapshotTests {
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
    private static let paces = TrainerPaces(easy: 300, long: 290, threshold: 245, vo2max: 228)
    private static let target = TrainerTarget(kind: .text, name: "Ficar mais forte", text: "ficar mais forte")
    private static let five = TrainerDayPreference(runs: 5, optional: false, offDays: [7], longDay: 6)

    static func save(_ view: some View, name: String) throws {
        for (scheme, suffix) in [(ColorScheme.dark, ""), (.light, "-light")] {
            let content = view.padding(16).frame(width: 390).fixedSize(horizontal: false, vertical: true).background(BrandColors.background)
            let host = UIHostingController(rootView: content)
            host.safeAreaRegions = []
            host.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
            let fitted = host.sizeThatFits(in: CGSize(width: 390, height: 4_000))
            let size = CGSize(width: 390, height: fitted.height)
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.overrideUserInterfaceStyle = host.overrideUserInterfaceStyle
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            window.isHidden = true
            if let output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
                try data.write(to: output.appending(path: "\(name)\(suffix).png"))
            }
        }
    }

    @Test func daysWithVolumeRange() throws {
        let peak = 78_000.0
        var ranges: [Int: TrainerVolumeRange] = [:]
        for runs in 4...6 {
            var preference = Self.five
            preference.runs = runs
            ranges[runs] = TrainerEngine.volumeRange(structure: TrainerEngine.suggestedStructure(preference), paces: Self.paces, target: Self.target)
        }
        let structure = TrainerEngine.suggestedStructure(Self.five)
        let cards = TrainerDaysCards(
            preference: .constant(Self.five), structure: .constant(structure), strength: .constant([]), outAndBack: .constant(false),
            suggested: structure,
            meters: TrainerEngine.peakWeekMeters(structure: structure, peakMeters: peak, paces: Self.paces, target: Self.target),
            peakMeters: peak,
            warnings: TrainerEngine.dayWarnings(structure: structure, strength: [], peakMeters: peak, paces: Self.paces, target: Self.target),
            showsStrength: false,
            volumeRows: ranges.keys.sorted().compactMap { runs in ranges[runs].map { TrainerVolumeRangeRow(runs: runs, range: $0) } },
            suggestedRuns: TrainerEngine.suggestedRuns(ranges: ranges, current: 5, peakMeters: peak)
        )
        try Self.save(VStack(alignment: .leading, spacing: 10) { DSSectionTitle(TrainerText.daysSection); cards }, name: "trainer-days-volume")
    }

    @Test func extraDayCard() throws {
        let structure = TrainerEngine.suggestedStructure(Self.five)
        let suggestion = try #require(TrainerEngine.extraDay(
            preference: Self.five, structure: structure, weekMeters: 68_000, paces: Self.paces, target: Self.target
        ))
        try Self.save(TrainerExtraDayCard(suggestion: suggestion, currentRuns: 5, keep: {}, review: {}), name: "trainer-extra-day")
    }
}
