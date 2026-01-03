//
//  WeatherService.swift
//  EcoLyonWidget
//
//  Service pour récupérer les données météo (WeatherKit) et qualité de l'air (ATMO API).
//

import Foundation
import WeatherKit
import CoreLocation

// MARK: - Weather Data Model

struct WidgetWeatherData {
    let temperature: Double
    let conditionSymbol: String
    let conditionDescription: String
    let condition: WeatherCondition
    let airQualityIndex: Int?
    let airQualityLabel: String?

    // Sun data for dynamic backgrounds
    let sunrise: Date?
    let sunset: Date?
    let tomorrowSunrise: Date?
    let tomorrowSunset: Date?

    // Hourly forecasts for timeline generation
    let hourlyForecasts: [HourWeather]

    static let placeholder = WidgetWeatherData(
        temperature: 15,
        conditionSymbol: "cloud.sun.fill",
        conditionDescription: "Partiellement nuageux",
        condition: .partlyCloudy,
        airQualityIndex: 2,
        airQualityLabel: "Bon",
        sunrise: nil,
        sunset: nil,
        tomorrowSunrise: nil,
        tomorrowSunset: nil,
        hourlyForecasts: []
    )
}

// MARK: - ATMO API Response Models

private struct ATMOResponse: Codable {
    let data: [ATMOData]
}

private struct ATMOData: Codable {
    let indice: Int
    let qualificatif: String
}

// MARK: - Weather Service

final class WeatherService {
    static let shared = WeatherService()

    private let weatherService = WeatherKit.WeatherService.shared

    // Token ATMO (récupéré depuis Info.plist ou en dur pour le widget)
    private let atmoToken: String = {
        // Essayer de récupérer depuis le bundle du widget
        if let token = Bundle.main.object(forInfoDictionaryKey: "ATMO_API_TOKEN") as? String, !token.isEmpty {
            return token
        }
        // Fallback - tu peux mettre ton token ici directement pour le widget
        return "REMPLACE_PAR_TON_TOKEN_ATMO"
    }()

    private init() {}

    /// Récupère les données météo complètes (WeatherKit + ATMO)
    func fetchWeather(for location: CLLocation) async -> WidgetWeatherData? {
        // Lancer les deux requêtes en parallèle
        async let weatherTask = fetchWeatherKit(for: location)
        async let airQualityTask = fetchATMOAirQuality(for: location)

        let weather = await weatherTask
        let airQuality = await airQualityTask

        // Si on a au moins la météo, retourner les données
        if let weather = weather {
            return WidgetWeatherData(
                temperature: weather.temperature,
                conditionSymbol: weather.conditionSymbol,
                conditionDescription: weather.conditionDescription,
                condition: weather.condition,
                airQualityIndex: airQuality?.index,
                airQualityLabel: airQuality?.label,
                sunrise: weather.sunrise,
                sunset: weather.sunset,
                tomorrowSunrise: weather.tomorrowSunrise,
                tomorrowSunset: weather.tomorrowSunset,
                hourlyForecasts: weather.hourlyForecasts
            )
        }

        // Si WeatherKit échoue mais ATMO fonctionne, retourner avec données météo par défaut
        if let airQuality = airQuality {
            return WidgetWeatherData(
                temperature: 0,
                conditionSymbol: "questionmark.circle",
                conditionDescription: "Indisponible",
                condition: .cloudy,
                airQualityIndex: airQuality.index,
                airQualityLabel: airQuality.label,
                sunrise: nil,
                sunset: nil,
                tomorrowSunrise: nil,
                tomorrowSunset: nil,
                hourlyForecasts: []
            )
        }

        // Tout a échoué - retourner nil pour utiliser le placeholder
        return nil
    }

    // MARK: - WeatherKit

    private struct WeatherKitResult {
        let temperature: Double
        let conditionSymbol: String
        let conditionDescription: String
        let condition: WeatherCondition
        let sunrise: Date?
        let sunset: Date?
        let tomorrowSunrise: Date?
        let tomorrowSunset: Date?
        let hourlyForecasts: [HourWeather]
    }

    private func fetchWeatherKit(for location: CLLocation) async -> WeatherKitResult? {
        do {
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather

            // Convertir la température en Celsius
            let tempCelsius = current.temperature.converted(to: .celsius).value

            // Extract sun times from daily forecast
            let dailyForecasts = weather.dailyForecast
            let todayForecast = dailyForecasts.first
            let tomorrowForecast = dailyForecasts.dropFirst().first

            let sunrise = todayForecast?.sun.sunrise
            let sunset = todayForecast?.sun.sunset
            let tomorrowSunrise = tomorrowForecast?.sun.sunrise
            let tomorrowSunset = tomorrowForecast?.sun.sunset

            // Get hourly forecasts (next 24 hours)
            let hourlyForecasts = Array(weather.hourlyForecast.prefix(24))

            print("✅ WeatherKit: \(tempCelsius)°C, \(current.symbolName), \(current.condition.description)")
            if let sunrise = sunrise, let sunset = sunset {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                print("🌅 Sunrise: \(formatter.string(from: sunrise)), Sunset: \(formatter.string(from: sunset))")
            }
            print("📊 Hourly forecasts: \(hourlyForecasts.count) entries")

            return WeatherKitResult(
                temperature: tempCelsius,
                conditionSymbol: current.symbolName,
                conditionDescription: current.condition.description,
                condition: current.condition,
                sunrise: sunrise,
                sunset: sunset,
                tomorrowSunrise: tomorrowSunrise,
                tomorrowSunset: tomorrowSunset,
                hourlyForecasts: hourlyForecasts
            )
        } catch {
            print("❌ WeatherKit Error: \(error)")
            print("❌ WeatherKit Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            return nil
        }
    }

    // MARK: - ATMO AURA API (Qualité de l'air Lyon)

    private struct AirQualityResult {
        let index: Int
        let label: String
    }

    private func fetchATMOAirQuality(for location: CLLocation) async -> AirQualityResult? {
        // Déterminer le code INSEE le plus proche (Lyon par défaut)
        let codeInsee = getNearestLyonDistrictCode(for: location)

        // Construire l'URL
        let urlString = "https://api.atmo-aura.fr/api/v1/communes/\(codeInsee)/indices/atmo?api_token=\(atmoToken)&date_echeance=now"

        guard let url = URL(string: urlString) else {
            print("❌ ATMO: URL invalide")
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10.0

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ ATMO: Erreur serveur")
                return nil
            }

            let atmoResponse = try JSONDecoder().decode(ATMOResponse.self, from: data)

            guard let firstData = atmoResponse.data.first else {
                print("❌ ATMO: Pas de données")
                return nil
            }

            return AirQualityResult(
                index: firstData.indice,
                label: firstData.qualificatif
            )
        } catch {
            print("❌ ATMO Error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Trouve le code INSEE de l'arrondissement lyonnais le plus proche
    private func getNearestLyonDistrictCode(for location: CLLocation) -> String {
        let lyonDistricts: [(code: String, lat: Double, lon: Double)] = [
            ("69381", 45.7676, 4.8351), // Lyon 1er
            ("69382", 45.7537, 4.8320), // Lyon 2e
            ("69383", 45.7578, 4.8435), // Lyon 3e
            ("69384", 45.7751, 4.8287), // Lyon 4e
            ("69385", 45.7630, 4.8156), // Lyon 5e
            ("69386", 45.7692, 4.8502), // Lyon 6e
            ("69387", 45.7343, 4.8418), // Lyon 7e
            ("69388", 45.7378, 4.8707), // Lyon 8e
            ("69389", 45.7797, 4.8060), // Lyon 9e
        ]

        var nearestCode = "69381" // Default: Lyon 1er
        var minDistance = Double.greatestFiniteMagnitude

        for district in lyonDistricts {
            let districtLocation = CLLocation(latitude: district.lat, longitude: district.lon)
            let distance = location.distance(from: districtLocation)

            if distance < minDistance {
                minDistance = distance
                nearestCode = district.code
            }
        }

        return nearestCode
    }

    /// Position par défaut (Lyon centre - Place Bellecour)
    static let defaultLocation = CLLocation(latitude: 45.757814, longitude: 4.832011)
}

// MARK: - Temperature Formatter

extension WidgetWeatherData {
    /// Température formatée en degrés Celsius
    var formattedTemperature: String {
        if temperature == 0 && conditionSymbol == "questionmark.circle" {
            return "--°"
        }
        return "\(Int(round(temperature)))°"
    }

    /// Couleur de l'indice de qualité de l'air
    var airQualityColor: String {
        guard let index = airQualityIndex else { return "#808080" }
        switch index {
        case 1: return "#50F0E6" // Bon
        case 2: return "#50CCAA" // Moyen
        case 3: return "#F0E641" // Dégradé
        case 4: return "#FF5050" // Mauvais
        case 5: return "#960032" // Très mauvais
        case 6: return "#872181" // Extrêmement mauvais
        default: return "#808080"
        }
    }
}
