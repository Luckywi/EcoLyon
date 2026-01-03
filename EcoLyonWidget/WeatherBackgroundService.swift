//
//  WeatherBackgroundService.swift
//  EcoLyonWidget
//
//  Service for determining dynamic weather backgrounds based on WeatherKit conditions,
//  time of day (with sunrise/sunset), and season.
//
//  Architecture: Clean separation of concerns with enums, protocols, and a single service class.
//

import Foundation
import WeatherKit

// MARK: - Special Events (Easter Eggs)

/// Special events that override normal weather backgrounds
/// Each event has specific dates and custom day/night images
enum SpecialEvent: String, CaseIterable {
    case feteLumieres    // Fête des Lumières - 8-11 décembre
    case noel            // Noël - 24-25 décembre
    case nouvelAn        // Nouvel An - 31 décembre & 1er janvier
    case juillet14       // 14 Juillet - Fête Nationale
    case halloween       // Halloween - 31 octobre
    case saintValentin   // Saint-Valentin - 14 février

    /// Check if a given date falls within this special event
    /// - Parameter date: The date to check
    /// - Returns: true if the date is during this event
    func isActive(on date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        switch self {
        case .feteLumieres:
            // 8-10 décembre
            return month == 12 && (day >= 8 && day <= 10)

        case .noel:
            // 24-25 décembre
            return month == 12 && (day == 24 || day == 25)

        case .nouvelAn:
            // 31 décembre ET 1er janvier
            return (month == 12 && day == 31) || (month == 1 && day == 1)

        case .juillet14:
            // 14 juillet
            return month == 7 && day == 14

        case .halloween:
            // 31 octobre
            return month == 10 && day == 31

        case .saintValentin:
            // 14 février
            return month == 2 && day == 14
        }
    }

    /// Returns the image name for this event
    /// - Parameter isDay: true for day image, false for night
    /// - Returns: The asset name for the background image
    func imageName(isDay: Bool) -> String {
        let suffix = isDay ? "day" : "night"
        return "F_\(fileBaseName)_\(suffix)"
    }

    /// Base name for file generation (matches lyon_generator.py)
    private var fileBaseName: String {
        switch self {
        case .feteLumieres: return "fete_lumieres"
        case .noel: return "noel"
        case .nouvelAn: return "nouvel_an"
        case .juillet14: return "14_juillet"
        case .halloween: return "halloween"
        case .saintValentin: return "saint_valentin"
        }
    }

    /// Display name for debugging
    var displayName: String {
        switch self {
        case .feteLumieres: return "Fête des Lumières"
        case .noel: return "Noël"
        case .nouvelAn: return "Nouvel An"
        case .juillet14: return "14 Juillet"
        case .halloween: return "Halloween"
        case .saintValentin: return "Saint-Valentin"
        }
    }

    /// Check all events and return the active one (if any)
    /// - Parameter date: The date to check
    /// - Returns: The active SpecialEvent, or nil if none
    static func activeEvent(for date: Date) -> SpecialEvent? {
        // Priority order: check each event
        // Note: Events don't overlap, so order doesn't matter much
        for event in SpecialEvent.allCases {
            if event.isActive(on: date) {
                return event
            }
        }
        return nil
    }
}

// MARK: - Season

/// Astronomical seasons based on official dates (Northern Hemisphere)
/// Spring: March 20 - June 20
/// Summer: June 21 - September 21
/// Autumn: September 22 - December 20
/// Winter: December 21 - March 19
enum Season: String, CaseIterable {
    case spring
    case summer
    case autumn
    case winter

    /// Determines the current season based on a given date
    /// Uses astronomical season dates for Northern Hemisphere (France/Lyon)
    static func from(date: Date) -> Season {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        // Create date components for season boundaries
        // Spring Equinox: ~March 20
        // Summer Solstice: ~June 21
        // Autumn Equinox: ~September 22
        // Winter Solstice: ~December 21

        switch month {
        case 1, 2:
            return .winter
        case 3:
            return day < 20 ? .winter : .spring
        case 4, 5:
            return .spring
        case 6:
            return day < 21 ? .spring : .summer
        case 7, 8:
            return .summer
        case 9:
            return day < 22 ? .summer : .autumn
        case 10, 11:
            return .autumn
        case 12:
            return day < 21 ? .autumn : .winter
        default:
            return .autumn
        }
    }

    /// Asset folder name for this season
    var assetFolder: String {
        switch self {
        case .spring: return "SPRING"
        case .summer: return "SUMMER"
        case .autumn: return "AUTOMNE"
        case .winter: return "HIVER"
        }
    }
}

// MARK: - Time Slot

/// Time periods for background selection, dynamically calculated from sunrise/sunset
enum TimeSlot: String, CaseIterable {
    case goldenMorning  // ~30min before to ~45min after sunrise
    case day            // After golden morning to ~45min before sunset
    case goldenEvening  // ~45min before to ~30min after sunset
    case night          // After golden evening to before golden morning

    /// Determines the time slot based on current time, sunrise, and sunset
    /// - Parameters:
    ///   - date: The current date/time
    ///   - sunrise: Today's sunrise time
    ///   - sunset: Today's sunset time
    /// - Returns: The appropriate TimeSlot
    static func from(date: Date, sunrise: Date?, sunset: Date?) -> TimeSlot {
        guard let sunrise = sunrise, let sunset = sunset else {
            // Fallback to hour-based logic if sunrise/sunset unavailable
            return fallbackTimeSlot(for: date)
        }

        let calendar = Calendar.current

        // Golden hour margins
        let goldenBeforeSunrise: TimeInterval = -30 * 60  // 30 min before
        let goldenAfterSunrise: TimeInterval = 45 * 60    // 45 min after
        let goldenBeforeSunset: TimeInterval = -45 * 60   // 45 min before
        let goldenAfterSunset: TimeInterval = 30 * 60     // 30 min after

        // Calculate golden hour boundaries
        let goldenMorningStart = sunrise.addingTimeInterval(goldenBeforeSunrise)
        let goldenMorningEnd = sunrise.addingTimeInterval(goldenAfterSunrise)
        let goldenEveningStart = sunset.addingTimeInterval(goldenBeforeSunset)
        let goldenEveningEnd = sunset.addingTimeInterval(goldenAfterSunset)

        // Determine time slot
        if date >= goldenMorningStart && date < goldenMorningEnd {
            return .goldenMorning
        } else if date >= goldenMorningEnd && date < goldenEveningStart {
            return .day
        } else if date >= goldenEveningStart && date < goldenEveningEnd {
            return .goldenEvening
        } else {
            return .night
        }
    }

    /// Fallback time slot calculation when sunrise/sunset is unavailable
    /// Uses approximate hours for Lyon latitude in autumn
    private static func fallbackTimeSlot(for date: Date) -> TimeSlot {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 7..<9:
            return .goldenMorning
        case 9..<17:
            return .day
        case 17..<19:
            return .goldenEvening
        default:
            return .night
        }
    }
}

// MARK: - Weather Category

/// Simplified weather categories for background selection
/// Groups 41+ WeatherKit conditions into 5 manageable categories
enum WeatherCategory: String, CaseIterable {
    case clear      // Sunny, clear sky
    case cloudy     // Overcast, foggy, hazy
    case rainy      // Rain, drizzle, showers
    case snowy      // Snow, blizzard, flurries
    case stormy     // Thunderstorms, severe weather

    /// Maps a WeatherKit condition to a simplified category
    /// Priority order: Storm > Snow > Rain > Cloudy > Clear
    static func from(condition: WeatherCondition) -> WeatherCategory {
        switch condition {
        // STORMY - Highest priority
        case .thunderstorms,
             .isolatedThunderstorms,
             .scatteredThunderstorms,
             .strongStorms,
             .tropicalStorm,
             .hurricane:
            return .stormy

        // SNOWY - Second priority
        case .snow,
             .heavySnow,
             .flurries,
             .blizzard,
             .blowingSnow,
             .frigid,
             .sunFlurries:
            return .snowy

        // RAINY - Third priority
        case .drizzle,
             .rain,
             .heavyRain,
             .freezingDrizzle,
             .freezingRain,
             .sleet,
             .hail,
             .wintryMix,
             .sunShowers:
            return .rainy

        // CLOUDY - Fourth priority
        case .partlyCloudy,
             .mostlyCloudy,
             .cloudy,
             .foggy,
             .haze,
             .smoky,
             .blowingDust,
             .windy,
             .breezy:
            return .cloudy

        // CLEAR - Default/lowest priority
        case .clear,
             .mostlyClear,
             .hot:
            return .clear

        // Unknown conditions default to cloudy (safe fallback)
        @unknown default:
            return .cloudy
        }
    }
}

// MARK: - Background Image Name

/// Generates the correct asset name for weather backgrounds
struct WeatherBackgroundImageName {

    /// Generates the image asset name based on season, weather, and time
    /// - Parameters:
    ///   - season: Current season
    ///   - category: Weather category
    ///   - timeSlot: Time of day
    /// - Returns: The asset name string (without extension)
    static func generate(
        season: Season,
        category: WeatherCategory,
        timeSlot: TimeSlot
    ) -> String {

        // SNOW: Uses global snow images (not season-specific)
        if category == .snowy {
            return snowImageName(for: timeSlot)
        }

        // STORM: Uses season-specific storm image (same for all times)
        if category == .stormy {
            return stormImageName(for: season)
        }

        // Other categories: Season + Weather + Time
        return standardImageName(
            season: season,
            category: category,
            timeSlot: timeSlot
        )
    }

    // MARK: - Private Helpers

    private static func snowImageName(for timeSlot: TimeSlot) -> String {
        switch timeSlot {
        case .goldenMorning, .goldenEvening:
            return "D_snow_golden"
        case .day:
            return "D_snow_day"
        case .night:
            return "D_snow_night"
        }
    }

    private static func stormImageName(for season: Season) -> String {
        switch season {
        case .spring:
            return "E_storm_spring"
        case .summer:
            return "E_storm_summer"
        case .autumn:
            return "E_storm_autumn"
        case .winter:
            return "E_storm_winter"
        }
    }

    private static func standardImageName(
        season: Season,
        category: WeatherCategory,
        timeSlot: TimeSlot
    ) -> String {
        let seasonName = season.rawValue
        let prefix: String
        let timeSuffix: String

        // Determine prefix based on weather category
        switch category {
        case .clear:
            prefix = "A"
        case .cloudy:
            prefix = "B"
        case .rainy:
            prefix = "C"
        case .snowy, .stormy:
            // Handled above, but included for completeness
            prefix = "A"
        }

        // Determine time suffix
        // Note: Golden hour only applies to clear weather
        // Cloudy/rainy weather doesn't show golden light
        switch (category, timeSlot) {
        case (.clear, .goldenMorning), (.clear, .goldenEvening):
            timeSuffix = "golden"
        case (_, .day), (_, .goldenMorning), (_, .goldenEvening):
            // Non-clear weather during golden hour shows as day
            timeSuffix = category == .clear ? "golden" : "day"
        case (_, .night):
            timeSuffix = "night"
        }

        // Correct time suffix for non-clear weather
        let finalTimeSuffix: String
        switch (category, timeSlot) {
        case (.clear, .goldenMorning), (.clear, .goldenEvening):
            finalTimeSuffix = "golden"
        case (.clear, .day):
            finalTimeSuffix = "day"
        case (.clear, .night):
            finalTimeSuffix = "night"
        case (.cloudy, .night), (.rainy, .night):
            finalTimeSuffix = "night"
        case (.cloudy, _), (.rainy, _):
            finalTimeSuffix = "day"
        default:
            finalTimeSuffix = "day"
        }

        // Build image name
        // Format: {prefix}_{season}_{weather}_{time} or {prefix}_{season}_{time}
        switch category {
        case .clear:
            return "\(prefix)_\(seasonName)_\(finalTimeSuffix)"
        case .cloudy:
            return "\(prefix)_\(seasonName)_grey_\(finalTimeSuffix)"
        case .rainy:
            return "\(prefix)_\(seasonName)_rain_\(finalTimeSuffix)"
        default:
            return "\(prefix)_\(seasonName)_\(finalTimeSuffix)"
        }
    }
}

// MARK: - Weather Background Service

/// Main service class for determining weather backgrounds
/// Thread-safe singleton with clean API
final class WeatherBackgroundService {

    // MARK: - Singleton

    static let shared = WeatherBackgroundService()

    private init() {}

    // MARK: - Public API

    /// Determines the appropriate background image for given conditions
    /// Checks for special events (easter eggs) first, then falls back to weather-based selection
    /// - Parameters:
    ///   - date: The date/time for the background
    ///   - condition: WeatherKit weather condition
    ///   - sunrise: Today's sunrise time (optional, will use fallback if nil)
    ///   - sunset: Today's sunset time (optional, will use fallback if nil)
    /// - Returns: The asset name for the background image
    func backgroundImageName(
        for date: Date,
        condition: WeatherCondition,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) -> String {

        // 1. CHECK FOR SPECIAL EVENTS (Easter Eggs) - Highest priority
        if let specialEvent = SpecialEvent.activeEvent(for: date) {
            let isDay = isDaytime(date: date, sunrise: sunrise, sunset: sunset)
            let imageName = specialEvent.imageName(isDay: isDay)

            #if DEBUG
            print("🎉 Easter Egg: \(specialEvent.displayName) | Image: \(imageName) | isDay: \(isDay)")
            #endif

            return imageName
        }

        // 2. NORMAL WEATHER-BASED SELECTION
        let season = Season.from(date: date)
        let category = WeatherCategory.from(condition: condition)
        let timeSlot = TimeSlot.from(date: date, sunrise: sunrise, sunset: sunset)

        let imageName = WeatherBackgroundImageName.generate(
            season: season,
            category: category,
            timeSlot: timeSlot
        )

        #if DEBUG
        print("🎨 Background: \(imageName) | Season: \(season) | Weather: \(category) | Time: \(timeSlot)")
        #endif

        return imageName
    }

    /// Determines if the given time is during daytime
    /// Used for easter eggs which only have day/night variants (no golden hour)
    /// - Parameters:
    ///   - date: The date/time to check
    ///   - sunrise: Today's sunrise time
    ///   - sunset: Today's sunset time
    /// - Returns: true if daytime, false if nighttime
    private func isDaytime(date: Date, sunrise: Date?, sunset: Date?) -> Bool {
        guard let sunrise = sunrise, let sunset = sunset else {
            // Fallback: use hour-based logic (7h-19h = day)
            let hour = Calendar.current.component(.hour, from: date)
            return hour >= 7 && hour < 19
        }

        // Daytime = between sunrise and sunset
        return date >= sunrise && date < sunset
    }

    /// Generates a complete timeline of background images for the next 24 hours
    /// - Parameters:
    ///   - hourlyForecasts: WeatherKit hourly forecasts
    ///   - sunrise: Today's sunrise
    ///   - sunset: Today's sunset
    ///   - tomorrowSunrise: Tomorrow's sunrise (for night entries past midnight)
    ///   - tomorrowSunset: Tomorrow's sunset
    /// - Returns: Array of (date, imageName) tuples for timeline entries
    func generateBackgroundTimeline(
        hourlyForecasts: [HourWeather],
        sunrise: Date?,
        sunset: Date?,
        tomorrowSunrise: Date? = nil,
        tomorrowSunset: Date? = nil
    ) -> [(date: Date, imageName: String)] {

        var timeline: [(date: Date, imageName: String)] = []

        for forecast in hourlyForecasts.prefix(24) {
            // Determine which sunrise/sunset to use based on forecast date
            let forecastSunrise: Date?
            let forecastSunset: Date?

            if let sunrise = sunrise, let sunset = sunset {
                // Check if forecast is for tomorrow
                let isTomorrow = Calendar.current.isDate(
                    forecast.date,
                    inSameDayAs: sunrise.addingTimeInterval(24 * 60 * 60)
                )

                if isTomorrow {
                    forecastSunrise = tomorrowSunrise ?? sunrise.addingTimeInterval(24 * 60 * 60)
                    forecastSunset = tomorrowSunset ?? sunset.addingTimeInterval(24 * 60 * 60)
                } else {
                    forecastSunrise = sunrise
                    forecastSunset = sunset
                }
            } else {
                forecastSunrise = nil
                forecastSunset = nil
            }

            let imageName = backgroundImageName(
                for: forecast.date,
                condition: forecast.condition,
                sunrise: forecastSunrise,
                sunset: forecastSunset
            )

            timeline.append((date: forecast.date, imageName: imageName))
        }

        return timeline
    }

    /// Returns the current background image name using current conditions
    /// Convenience method for immediate use
    func currentBackgroundImageName(
        condition: WeatherCondition,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) -> String {
        return backgroundImageName(
            for: Date(),
            condition: condition,
            sunrise: sunrise,
            sunset: sunset
        )
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension WeatherBackgroundService {

    /// Returns all possible background image names for testing
    static var allPossibleImageNames: [String] {
        var names: [String] = []

        // Snow images (global)
        names.append(contentsOf: ["D_snow_golden", "D_snow_day", "D_snow_night"])

        // Season-specific images
        for season in Season.allCases {
            // Storm
            names.append("E_storm_\(season.rawValue)")

            // Clear weather
            names.append("A_\(season.rawValue)_golden")
            names.append("A_\(season.rawValue)_day")
            names.append("A_\(season.rawValue)_night")

            // Grey weather
            names.append("B_\(season.rawValue)_grey_day")
            names.append("B_\(season.rawValue)_grey_night")

            // Rain
            names.append("C_\(season.rawValue)_rain_day")
            names.append("C_\(season.rawValue)_rain_night")
        }

        // Easter eggs (special events)
        for event in SpecialEvent.allCases {
            names.append(event.imageName(isDay: true))
            names.append(event.imageName(isDay: false))
        }

        return names
    }

    /// Returns all easter egg image names
    static var allEasterEggImageNames: [String] {
        var names: [String] = []
        for event in SpecialEvent.allCases {
            names.append(event.imageName(isDay: true))
            names.append(event.imageName(isDay: false))
        }
        return names
    }

    /// Test method to preview a specific combination
    static func previewImageName(
        season: Season,
        category: WeatherCategory,
        timeSlot: TimeSlot
    ) -> String {
        return WeatherBackgroundImageName.generate(
            season: season,
            category: category,
            timeSlot: timeSlot
        )
    }
}
#endif
