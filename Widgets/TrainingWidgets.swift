import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: WidgetSnapshot(score: 62, verdict: "Treino moderado", readinessLine: "HRV na faixa", workoutTitle: "VO2 máx 5 × 1 km", workoutDetail: "9,8 km · 55 min", strengthTitle: "Superiores", raceName: "LIVE!21K", raceDays: 6, weekText: "Semana: 34 de 62 km", updatedAt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : TodayEntry(date: .now, snapshot: WidgetSharedConstants.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: WidgetConstants.refreshHours, to: .now) ?? .now
        completion(Timeline(entries: [TodayEntry(date: .now, snapshot: WidgetSharedConstants.load())], policy: .after(next)))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSharedConstants.kind, provider: TodayProvider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
                .widgetURL(WidgetSharedConstants.deepLink)
        }
        .configurationDisplayName(WidgetConstants.displayName)
        .description(WidgetConstants.description)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall, .systemMedium])
    }
}

@main
struct TrainingWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        StrengthLiveActivity()
    }
}
