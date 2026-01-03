//
//  WeatherService.swift
//  EcoLyon
//
//  Service pour récupérer les données météo (WeatherKit) et qualité de l'air (ATMO API).
//  Copie exacte du widget pour garantir le même fonctionnement.
//

import Foundation
import WeatherKit
import CoreLocation
import SwiftUI

// MARK: - Weather Data Model

struct AppWeatherData {
    let temperature: Double
    let conditionSymbol: String
    let conditionDescription: String
    let airQualityIndex: Int?
    let airQualityLabel: String?

    static let placeholder = AppWeatherData(
        temperature: 0,
        conditionSymbol: "cloud.fill",
        conditionDescription: "Chargement...",
        airQualityIndex: nil,
        airQualityLabel: nil
    )

    /// Température formatée en degrés Celsius
    var formattedTemperature: String {
        if temperature == 0 && conditionSymbol == "questionmark.circle" {
            return "--°"
        }
        return "\(Int(round(temperature)))°"
    }

    /// Couleur de l'indice de qualité de l'air
    var airQualityColor: Color {
        guard let index = airQualityIndex else { return .gray }
        switch index {
        case 1: return Color(hex: "50F0E6") // Bon
        case 2: return Color(hex: "50CCAA") // Moyen
        case 3: return Color(hex: "F0E641") // Dégradé
        case 4: return Color(hex: "FF5050") // Mauvais
        case 5: return Color(hex: "960032") // Très mauvais
        case 6: return Color(hex: "872181") // Extrêmement mauvais
        default: return .gray
        }
    }
}

// MARK: - ATMO API Response Models

private struct ATMOResponse: Codable {
    let data: [ATMOData]
}

private struct ATMOData: Codable {
    let indice: Int
    let qualificatif: String
}

// MARK: - App Weather Service (identique au widget)

final class AppWeatherService: ObservableObject {
    static let shared = AppWeatherService()

    @MainActor @Published private(set) var weatherData: AppWeatherData = .placeholder
    @MainActor @Published private(set) var isLoading = false

    private let weatherService = WeatherKit.WeatherService.shared

    // Token ATMO (même pattern que le widget)
    private let atmoToken: String = {
        if let token = Bundle.main.object(forInfoDictionaryKey: "ATMO_API_TOKEN") as? String, !token.isEmpty {
            return token
        }
        return "0c7d0bee25f494150fa591275260e81f"
    }()

    private init() {}

    /// Récupère les données météo complètes (WeatherKit + ATMO)
    func fetchWeather(for coordinate: CLLocationCoordinate2D) async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Lancer les deux requêtes en parallèle
        async let weatherTask = fetchWeatherKit(for: location)
        async let airQualityTask = fetchATMOAirQuality(for: location)

        let weather = await weatherTask
        let airQuality = await airQualityTask

        let newData: AppWeatherData
        if let weather = weather {
            newData = AppWeatherData(
                temperature: weather.temperature,
                conditionSymbol: weather.conditionSymbol,
                conditionDescription: weather.conditionDescription,
                airQualityIndex: airQuality?.index,
                airQualityLabel: airQuality?.label
            )
        } else if let airQuality = airQuality {
            newData = AppWeatherData(
                temperature: 0,
                conditionSymbol: "questionmark.circle",
                conditionDescription: "Indisponible",
                airQualityIndex: airQuality.index,
                airQualityLabel: airQuality.label
            )
        } else {
            newData = .placeholder
        }

        await MainActor.run {
            weatherData = newData
        }
    }

    // MARK: - WeatherKit

    private struct WeatherKitResult {
        let temperature: Double
        let conditionSymbol: String
        let conditionDescription: String
    }

    private func fetchWeatherKit(for location: CLLocation) async -> WeatherKitResult? {
        do {
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather
            let tempCelsius = current.temperature.converted(to: .celsius).value

            print("✅ WeatherKit: \(tempCelsius)°C, \(current.symbolName)")

            return WeatherKitResult(
                temperature: tempCelsius,
                conditionSymbol: current.symbolName,
                conditionDescription: current.condition.description
            )
        } catch {
            print("❌ WeatherKit Error: \(error)")
            return nil
        }
    }

    // MARK: - ATMO AURA API

    private struct AirQualityResult {
        let index: Int
        let label: String
    }

    private func fetchATMOAirQuality(for location: CLLocation) async -> AirQualityResult? {
        let codeInsee = getNearestLyonDistrictCode(for: location)
        let urlString = "https://api.atmo-aura.fr/api/v1/communes/\(codeInsee)/indices/atmo?api_token=\(atmoToken)&date_echeance=now"

        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10.0

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let atmoResponse = try JSONDecoder().decode(ATMOResponse.self, from: data)

            guard let firstData = atmoResponse.data.first else { return nil }

            print("✅ ATMO: Index \(firstData.indice) - \(firstData.qualificatif)")

            return AirQualityResult(
                index: firstData.indice,
                label: firstData.qualificatif
            )
        } catch {
            print("❌ ATMO Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func getNearestLyonDistrictCode(for location: CLLocation) -> String {
        let lyonDistricts: [(code: String, lat: Double, lon: Double)] = [
            ("69381", 45.7676, 4.8351),
            ("69382", 45.7537, 4.8320),
            ("69383", 45.7578, 4.8435),
            ("69384", 45.7751, 4.8287),
            ("69385", 45.7630, 4.8156),
            ("69386", 45.7692, 4.8502),
            ("69387", 45.7343, 4.8418),
            ("69388", 45.7378, 4.8707),
            ("69389", 45.7797, 4.8060),
        ]

        var nearestCode = "69381"
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
}
