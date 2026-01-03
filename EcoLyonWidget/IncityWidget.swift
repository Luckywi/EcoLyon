//
//  IncityWidget.swift
//  EcoLyonWidget
//
//  Widget Incity - Affiche la tour Incity avec fond dynamique.
//  - Jour : météo
//  - Nuit : LED couleur qualité air de demain
//  - Pleine lune : effet spécial
//  - Easter eggs : événements spéciaux
//

import WidgetKit
import SwiftUI
import AppIntents
import CoreLocation
import WeatherKit

// MARK: - Widget Entry

struct IncityWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: IncityWidgetConfigurationIntent
    let backgroundImageName: String
    let temperature: Int?
    let conditionSymbol: String?
    let airQualityIndex: Int?
    let airQualityColor: String?
    let isNight: Bool

    init(
        date: Date,
        configuration: IncityWidgetConfigurationIntent,
        backgroundImageName: String = "incity_cloudy_day",
        temperature: Int? = nil,
        conditionSymbol: String? = nil,
        airQualityIndex: Int? = nil,
        airQualityColor: String? = nil,
        isNight: Bool = false
    ) {
        self.date = date
        self.configuration = configuration
        self.backgroundImageName = backgroundImageName
        self.temperature = temperature
        self.conditionSymbol = conditionSymbol
        self.airQualityIndex = airQualityIndex
        self.airQualityColor = airQualityColor
        self.isNight = isNight
    }
}

// MARK: - Timeline Provider

struct IncityTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = IncityWidgetEntry
    typealias Intent = IncityWidgetConfigurationIntent

    func placeholder(in context: Context) -> IncityWidgetEntry {
        IncityWidgetEntry(
            date: Date(),
            configuration: IncityWidgetConfigurationIntent(),
            backgroundImageName: "incity_cloudy_day"
        )
    }

    func snapshot(for configuration: IncityWidgetConfigurationIntent, in context: Context) async -> IncityWidgetEntry {
        IncityWidgetEntry(
            date: Date(),
            configuration: configuration,
            backgroundImageName: "incity_clear_day"
        )
    }

    func timeline(for configuration: IncityWidgetConfigurationIntent, in context: Context) async -> Timeline<IncityWidgetEntry> {
        var entries: [IncityWidgetEntry] = []

        // Récupérer les données
        let data = await fetchIncityData()

        let currentDate = Date()
        let calendar = Calendar.current

        // Générer des entrées pour les prochaines 12 heures (une par heure)
        for hourOffset in 0..<12 {
            guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: currentDate) else {
                continue
            }

            // Déterminer si c'est la nuit
            let isNight = !isDaytime(
                date: entryDate,
                sunrise: data.sunrise,
                sunset: data.sunset
            )

            // Déterminer si c'est la pleine lune
            let isFullMoon = data.isFullMoon

            // Obtenir le nom de l'image de fond
            let backgroundName = IncityBackgroundService.shared.backgroundImageName(
                for: entryDate,
                condition: data.condition,
                sunrise: data.sunrise,
                sunset: data.sunset,
                tomorrowAirQualityIndex: data.tomorrowAirQualityIndex,
                isFullMoon: isFullMoon
            )

            let entry = IncityWidgetEntry(
                date: entryDate,
                configuration: configuration,
                backgroundImageName: backgroundName,
                temperature: data.temperature,
                conditionSymbol: data.conditionSymbol,
                airQualityIndex: data.currentAirQualityIndex,
                airQualityColor: data.currentAirQualityColor,
                isNight: isNight
            )

            entries.append(entry)

            #if DEBUG
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            print("📌 Incity \(formatter.string(from: entryDate)): \(backgroundName)")
            #endif
        }

        // Si aucune entrée, créer une entrée par défaut
        if entries.isEmpty {
            entries.append(IncityWidgetEntry(
                date: currentDate,
                configuration: configuration,
                backgroundImageName: "incity_cloudy_day"
            ))
        }

        // Rafraîchir dans 2 heures
        let nextUpdate = calendar.date(byAdding: .hour, value: 2, to: currentDate)!

        return Timeline(entries: entries, policy: .after(nextUpdate))
    }

    // MARK: - Data Fetching

    private struct IncityData {
        let condition: WeatherCondition
        let conditionSymbol: String
        let temperature: Int
        let sunrise: Date?
        let sunset: Date?
        let currentAirQualityIndex: Int?
        let currentAirQualityColor: String?
        let tomorrowAirQualityIndex: Int?
        let isFullMoon: Bool
    }

    private func fetchIncityData() async -> IncityData {
        // Obtenir la localisation
        let location: CLLocation
        if let cached = WidgetLocationManager.shared.getCachedLocation() {
            location = CLLocation(latitude: cached.latitude, longitude: cached.longitude)
        } else {
            location = WeatherService.defaultLocation
        }

        // Récupérer la météo et la qualité de l'air actuelle
        let weatherData = await WeatherService.shared.fetchWeather(for: location)

        // Récupérer la qualité de l'air de DEMAIN (pour les LED nuit)
        let tomorrowAQI = await fetchTomorrowAirQuality(for: location)

        // Vérifier la phase de la lune
        let isFullMoon = await checkFullMoon(for: location)

        return IncityData(
            condition: weatherData?.condition ?? .partlyCloudy,
            conditionSymbol: weatherData?.conditionSymbol ?? "cloud.sun.fill",
            temperature: Int(weatherData?.temperature ?? 0),
            sunrise: weatherData?.sunrise,
            sunset: weatherData?.sunset,
            currentAirQualityIndex: weatherData?.airQualityIndex,
            currentAirQualityColor: weatherData?.airQualityColor,
            tomorrowAirQualityIndex: tomorrowAQI,
            isFullMoon: isFullMoon
        )
    }

    /// Récupère la qualité de l'air de demain via API ATMO
    private func fetchTomorrowAirQuality(for location: CLLocation) async -> Int? {
        // Utiliser le code INSEE de Lyon (simplifié)
        let codeInsee = "69123" // Lyon

        // Date de demain au format YYYY-MM-DD
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let tomorrowStr = formatter.string(from: tomorrow)

        // Token ATMO (récupéré depuis le bundle ou fallback)
        let atmoToken: String = {
            if let token = Bundle.main.object(forInfoDictionaryKey: "ATMO_API_TOKEN") as? String, !token.isEmpty {
                return token
            }
            return "VOTRE_TOKEN_ATMO"
        }()

        let urlString = "https://api.atmo-aura.fr/api/v1/communes/\(codeInsee)/indices/atmo?api_token=\(atmoToken)&date_echeance=\(tomorrowStr)"

        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Décoder la réponse
            struct ATMOResponse: Codable {
                let data: [ATMOData]
            }
            struct ATMOData: Codable {
                let indice: Int
            }

            let atmoResponse = try JSONDecoder().decode(ATMOResponse.self, from: data)
            return atmoResponse.data.first?.indice

        } catch {
            print("❌ Incity ATMO Error: \(error)")
            return nil
        }
    }

    /// Vérifie si c'est la pleine lune via WeatherKit
    private func checkFullMoon(for location: CLLocation) async -> Bool {
        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            if let moonPhase = weather.dailyForecast.first?.moon.phase {
                return moonPhase == .full
            }
        } catch {
            print("❌ Moon phase error: \(error)")
        }
        return false
    }

    /// Vérifie si c'est le jour
    private func isDaytime(date: Date, sunrise: Date?, sunset: Date?) -> Bool {
        guard let sunrise = sunrise, let sunset = sunset else {
            let hour = Calendar.current.component(.hour, from: date)
            return hour >= 7 && hour < 19
        }
        return date >= sunrise && date < sunset
    }
}

// MARK: - Widget Configuration

struct IncityWidget: Widget {
    let kind: String = "IncityWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: IncityWidgetConfigurationIntent.self,
            provider: IncityTimelineProvider()
        ) { entry in
            IncityWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    IncityBackgroundView(imageName: entry.backgroundImageName)
                }
        }
        .configurationDisplayName("Widget Incity")
        .description("Météo, qualité de l'air et raccourci. La tour Incity s'illumine le soir aux couleurs de la qualité de l'air du lendemain.")
        .supportedFamilies([.systemSmall]) // UNIQUEMENT SMALL
        .contentMarginsDisabled()
    }
}

// MARK: - Background View

struct IncityBackgroundView: View {
    let imageName: String

    var body: some View {
        if let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Fallback
            Image("incity_cloudy_day")
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }
}

// MARK: - Entry View

struct IncityWidgetEntryView: View {
    var entry: IncityWidgetEntry

    var body: some View {
        IncitySmallWidgetView(entry: entry)
    }
}

// MARK: - Small Widget View

struct IncitySmallWidgetView: View {
    let entry: IncityWidgetEntry

    /// Convertit un symbole météo en version .fill
    private func weatherSymbolWithFill(_ symbol: String) -> String {
        if symbol.hasSuffix(".fill") {
            return symbol
        }
        return symbol + ".fill"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Le fond est géré par containerBackground

                VStack {
                    // Météo + Qualité air en haut à droite
                    HStack {
                        Spacer()

                        HStack(spacing: 6) {
                            // Météo: Icône + Température
                            if let symbol = entry.conditionSymbol, let temp = entry.temperature {
                                Image(systemName: weatherSymbolWithFill(symbol))
                                    .font(.system(size: 12, weight: .medium))
                                    .symbolRenderingMode(.multicolor)

                                Text("\(temp)°")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            // Séparateur + AQI
                            if let aqi = entry.airQualityIndex, let color = entry.airQualityColor {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.3))
                                    .frame(width: 1, height: 12)

                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 8, height: 8)

                                Text("\(aqi)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.regularMaterial)
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                    Spacer()

                    // Bouton raccourci en bas à gauche
                    HStack {
                        Link(destination: entry.configuration.shortcut.deepLinkURL) {
                            Image(entry.configuration.shortcut.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.regularMaterial)
                                )
                        }

                        Spacer()
                    }
                    .padding(10)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    IncityWidget()
} timeline: {
    IncityWidgetEntry(
        date: .now,
        configuration: IncityWidgetConfigurationIntent(shortcut: .toilettes),
        backgroundImageName: "incity_clear_day",
        temperature: 18,
        conditionSymbol: "sun.max.fill",
        airQualityIndex: 2,
        airQualityColor: "#50CCAA"
    )
    IncityWidgetEntry(
        date: .now,
        configuration: IncityWidgetConfigurationIntent(shortcut: .fontaines),
        backgroundImageName: "incity_night_cyan",
        temperature: 12,
        conditionSymbol: "moon.stars.fill",
        airQualityIndex: 1,
        airQualityColor: "#50F0E6",
        isNight: true
    )
    IncityWidgetEntry(
        date: .now,
        configuration: IncityWidgetConfigurationIntent(shortcut: .silos),
        backgroundImageName: "incity_fullmoon_red",
        temperature: 8,
        conditionSymbol: "moon.fill",
        airQualityIndex: 4,
        airQualityColor: "#E63A52",
        isNight: true
    )
}
