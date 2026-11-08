import TrainingCore

struct DailyStarts {
    var summary: Day
    var hrv: Day
    var sleep: Day
    var bodyBattery: Day

    init(all day: Day) {
        summary = day
        hrv = day
        sleep = day
        bodyBattery = day
    }

    init(summary: Day, hrv: Day, sleep: Day, bodyBattery: Day) {
        self.summary = summary
        self.hrv = hrv
        self.sleep = sleep
        self.bodyBattery = bodyBattery
    }
}
