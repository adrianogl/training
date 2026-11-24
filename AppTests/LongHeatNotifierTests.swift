import Foundation
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct LongHeatNotifierTests {
    private let tomorrow = Day(iso: "2026-11-21")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: hour))!
    }

    private func notifier(_ scheduler: FakeNotificationScheduler, hour: Int) -> LongHeatNotifier {
        let now = date(hour: hour)
        return LongHeatNotifier(scheduler: scheduler, calendar: calendar, now: { now })
    }

    private func heatDay(usual: Int = 8, hot: Double = 27, dew: Double = 22) -> TrainerHeatDay? {
        let weather = (5...21).map { hour in
            HourlyWeather(hour: hour, temperature: hour <= 6 ? 17 : hot, dewPoint: hour <= 6 ? 12 : dew)
        }
        return TrainerHeatDayBuilder.make(weather: weather, longPace: 330, usualHour: usual)
    }

    @Test func schedulesTonightWhenTheUsualHourIsHot() async throws {
        let scheduler = FakeNotificationScheduler()
        let day = try #require(heatDay())
        let usual = try #require(day.hour(8))
        #expect(usual.heat.paceOffset >= RunWeatherConstants.minimumHeatSeconds)
        await notifier(scheduler, hour: 10).update(longDay: tomorrow, heat: day)
        let id = "long-heat-2026-11-21"
        #expect(await scheduler.scheduled[id]?.at == date(hour: 20))
        #expect(await scheduler.headers[id]?.title == "Calor no longão de amanhã")
        #expect(await scheduler.headers[id]?.link == "training://treinador/dia/2026-11-21")
        let text = try #require(await scheduler.scheduled[id]?.text)
        #expect(day.suggestedHour == 6)
        #expect(text == "No seu horário, 8h, 27 °C com orvalho de 22 °C: o pace sobe \(usual.heat.paceOffset) s/km. Saindo às 6h, só 3 s/km.")
    }

    @Test func cancelsWhenCoolOrWithoutForecast() async {
        let scheduler = FakeNotificationScheduler()
        let notifier = notifier(scheduler, hour: 10)
        await notifier.update(longDay: tomorrow, heat: heatDay())
        await notifier.update(longDay: tomorrow, heat: heatDay(hot: 18, dew: 10))
        #expect(await scheduler.scheduled.isEmpty)
        await notifier.update(longDay: tomorrow, heat: heatDay())
        await notifier.update(longDay: tomorrow, heat: nil)
        #expect(await scheduler.scheduled.isEmpty)
    }

    @Test func doesNotScheduleAfterEightPm() async {
        let scheduler = FakeNotificationScheduler()
        await notifier(scheduler, hour: 20).update(longDay: tomorrow, heat: heatDay())
        #expect(await scheduler.scheduled.isEmpty)
    }
}
