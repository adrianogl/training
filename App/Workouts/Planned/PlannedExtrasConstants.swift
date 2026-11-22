enum PlannedExtrasConstants {
    static let maxLaps = 4
    static let courseTolerance = 0.12
    static let profilePoints = 80
    static let forecastStartHour = 5
    static let forecastEndHour = 22
    static let locationSearchLimit = 30
    static let forecastDaysAhead = 9
    static let forecastURL = "https://api.open-meteo.com/v1/forecast"
    static let forecastFields = "temperature_2m,dew_point_2m,shortwave_radiation"
    static let forecastTimezone = "auto"
    static let coordinateScale = 10.0
}
