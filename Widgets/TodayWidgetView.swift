import SwiftUI
import WidgetKit

struct TodayWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private typealias C = WidgetConstants

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium.containerBackground(C.background, for: .widget)
        default: small.containerBackground(C.background, for: .widget)
        }
    }

    private var workoutTitle: String { snapshot.workoutTitle ?? C.rest }

    private var circular: some View {
        Gauge(value: Double(snapshot.score ?? 0), in: 0...100) {
            Text(C.readinessLabel)
        } currentValueLabel: {
            Text(snapshot.score.map(String.init) ?? "—")
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.clear, for: .widget)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text([C.todayLabel, snapshot.score.map { "prontidão \($0)" }].compactMap { $0 }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(workoutTitle).font(.headline).lineLimit(1)
            Text([snapshot.strengthTitle.map { "+ \($0)" }, C.raceText(snapshot)].compactMap { $0 }.joined(separator: " · "))
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
            Circle()
                .trim(from: 0, to: Double(snapshot.score ?? 0) / 100)
                .stroke(C.scoreColor(snapshot.score ?? 0), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(snapshot.score.map(String.init) ?? "—").font(.system(size: 14, weight: .heavy, design: .rounded))
        }
        .frame(width: 44, height: 44)
    }

    private var score: some View {
        HStack(spacing: 8) {
            ring
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.verdict ?? "—").font(.system(size: 14, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                if let line = snapshot.readinessLine { Text(line).font(.caption2).foregroundStyle(C.dim).lineLimit(1) }
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(C.readinessLabel.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(C.dim)
            score
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 1) {
                Text(workoutTitle).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                if let detail = snapshot.workoutDetail { Text(detail).font(.caption2).foregroundStyle(C.dim) }
            }
            if let race = C.raceText(snapshot) { Text(race).font(.caption2).foregroundStyle(C.dim).lineLimit(1) }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(C.readinessLabel.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(C.dim)
                score
                Spacer(minLength: 0)
                if let race = C.raceText(snapshot) { Text(race).font(.caption2).foregroundStyle(C.dim).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 7) {
                Text(C.todayLabel.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(C.dim)
                chip(workoutTitle, color: snapshot.workoutTitle == nil ? C.dim : C.amber)
                if let strength = snapshot.strengthTitle { chip(C.strengthPrefix + strength, color: C.violet) }
                Spacer(minLength: 0)
                if let week = snapshot.weekText { Text(week).font(.caption2).foregroundStyle(C.dim).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
