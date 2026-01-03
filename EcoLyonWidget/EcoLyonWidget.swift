//
//  EcoLyonWidget.swift
//  EcoLyonWidget
//
//  Created by Lucky Lebeurre on 07/12/2025.
//

import WidgetKit
import SwiftUI
import AppIntents
import CoreLocation

// MARK: - Timeline Provider

struct EcoLyonTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = EcoLyonWidgetEntry
    typealias Intent = EcoLyonWidgetConfigurationIntent

    func placeholder(in context: Context) -> EcoLyonWidgetEntry {
        let backgroundName = WeatherBackgroundService.shared.backgroundImageName(
            for: Date(),
            condition: .partlyCloudy
        )
        return EcoLyonWidgetEntry(
            date: Date(),
            configuration: EcoLyonWidgetConfigurationIntent(),
            weatherData: .placeholder,
            backgroundImageName: backgroundName
        )
    }

    func snapshot(for configuration: EcoLyonWidgetConfigurationIntent, in context: Context) async -> EcoLyonWidgetEntry {
        // Snapshot doit être RAPIDE - utiliser placeholder directement
        let backgroundName = WeatherBackgroundService.shared.backgroundImageName(
            for: Date(),
            condition: .partlyCloudy
        )
        return EcoLyonWidgetEntry(
            date: Date(),
            configuration: configuration,
            weatherData: .placeholder,
            backgroundImageName: backgroundName
        )
    }

    func timeline(for configuration: EcoLyonWidgetConfigurationIntent, in context: Context) async -> Timeline<EcoLyonWidgetEntry> {
        // Récupérer la météo
        let weatherData = await fetchWeatherData()

        var entries: [EcoLyonWidgetEntry] = []

        if let weatherData = weatherData, !weatherData.hourlyForecasts.isEmpty {
            // Generate timeline entries from hourly forecasts
            let backgroundTimeline = WeatherBackgroundService.shared.generateBackgroundTimeline(
                hourlyForecasts: weatherData.hourlyForecasts,
                sunrise: weatherData.sunrise,
                sunset: weatherData.sunset,
                tomorrowSunrise: weatherData.tomorrowSunrise,
                tomorrowSunset: weatherData.tomorrowSunset
            )

            print("📅 Generating \(backgroundTimeline.count) timeline entries")

            for (index, item) in backgroundTimeline.enumerated() {
                // For the first entry, use current weather data
                // For subsequent entries, we keep the same weather data but change the background
                let entry = EcoLyonWidgetEntry(
                    date: item.date,
                    configuration: configuration,
                    weatherData: index == 0 ? weatherData : weatherData,
                    backgroundImageName: item.imageName
                )
                entries.append(entry)

                #if DEBUG
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                print("  📌 \(formatter.string(from: item.date)): \(item.imageName)")
                #endif
            }
        } else {
            // Fallback: single entry with current conditions
            let backgroundName: String
            if let weatherData = weatherData {
                backgroundName = WeatherBackgroundService.shared.backgroundImageName(
                    for: Date(),
                    condition: weatherData.condition,
                    sunrise: weatherData.sunrise,
                    sunset: weatherData.sunset
                )
            } else {
                backgroundName = WeatherBackgroundService.shared.backgroundImageName(
                    for: Date(),
                    condition: .partlyCloudy
                )
            }

            let entry = EcoLyonWidgetEntry(
                date: Date(),
                configuration: configuration,
                weatherData: weatherData,
                backgroundImageName: backgroundName
            )
            entries.append(entry)
        }

        // Next refresh: 2 hours (iOS will manage the timeline entries in between)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        print("⏰ Next weather refresh scheduled for: \(nextUpdate)")

        return Timeline(entries: entries, policy: .after(nextUpdate))
    }

    // MARK: - Weather Fetching

    private func fetchWeatherData() async -> WidgetWeatherData? {
        // Essayer d'obtenir la position de l'utilisateur
        let location: CLLocation

        if let cachedCoordinate = WidgetLocationManager.shared.getCachedLocation() {
            print("📍 Widget: Using cached location")
            location = CLLocation(latitude: cachedCoordinate.latitude, longitude: cachedCoordinate.longitude)
        } else if let currentCoordinate = await WidgetLocationManager.shared.requestCurrentLocation() {
            print("📍 Widget: Using current location")
            location = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        } else {
            print("📍 Widget: Using default Lyon location")
            location = WeatherService.defaultLocation
        }

        print("📍 Widget Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        let result = await WeatherService.shared.fetchWeather(for: location)

        if let data = result {
            print("✅ Widget Weather Data: \(data.formattedTemperature), AQI: \(data.airQualityIndex ?? -1)")
        } else {
            print("❌ Widget: No weather data received")
        }

        return result
    }
}

// MARK: - Widget Configuration

struct EcoLyonWidget: Widget {
    let kind: String = "EcoLyonWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: EcoLyonWidgetConfigurationIntent.self,
            provider: EcoLyonTimelineProvider()
        ) { entry in
            EcoLyonWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(imageName: entry.backgroundImageName)
                }
        }
        .configurationDisplayName("Widget Lyon")
        .description("Météo, qualité de l'air et raccourcis.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled() // Désactive les marges pour que le background remplisse tout
    }
}

// MARK: - Background View

struct WidgetBackgroundView: View {
    let imageName: String

    init(imageName: String = "A_autumn_day") {
        self.imageName = imageName
    }

    var body: some View {
        if let uiImage = UIImage(named: imageName, in: Bundle.main, compatibleWith: nil) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Fallback: try default autumn day image
            if let fallbackImage = UIImage(named: "A_autumn_day") {
                Image(uiImage: fallbackImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Last resort: gradient fallback
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

// MARK: - Entry View

struct EcoLyonWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: EcoLyonWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    EcoLyonWidget()
} timeline: {
    EcoLyonWidgetEntry(
        date: .now,
        configuration: EcoLyonWidgetConfigurationIntent(
            first: .toilettes,
            second: .bancs
        ),
        weatherData: .placeholder,
        backgroundImageName: "A_autumn_golden"
    )
}

