//
//  IncityBackgroundService.swift
//  EcoLyonWidget
//
//  Service pour déterminer le fond dynamique du widget Incity.
//  Logique simplifiée : pas de saisons, mais gestion des LED qualité air la nuit.
//

import Foundation
import WeatherKit

// MARK: - Air Quality Level (pour les LED nuit)

/// Niveaux de qualité de l'air ATMO avec leurs couleurs LED
enum AirQualityLevel: Int, CaseIterable {
    case good = 1        // Bon - #50F0E6 (cyan)
    case fair = 2        // Moyen - #50CCAA (vert)
    case moderate = 3    // Dégradé - #F0E641 (jaune)
    case poor = 4        // Mauvais - #E63A52 (rouge)
    case veryPoor = 5    // Très mauvais - #872181 (violet)

    /// Nom du fichier image pour cette qualité (nuit normale)
    var nightImageName: String {
        switch self {
        case .good: return "incity_night_cyan"
        case .fair: return "incity_night_green"
        case .moderate: return "incity_night_yellow"
        case .poor: return "incity_night_red"
        case .veryPoor: return "incity_night_purple"
        }
    }

    /// Nom du fichier image pour cette qualité (pleine lune)
    var fullMoonImageName: String {
        switch self {
        case .good: return "incity_fullmoon_cyan"
        case .fair: return "incity_fullmoon_green"
        case .moderate: return "incity_fullmoon_yellow"
        case .poor: return "incity_fullmoon_red"
        case .veryPoor: return "incity_fullmoon_purple"
        }
    }

    /// Couleur hex pour l'affichage
    var hexColor: String {
        switch self {
        case .good: return "#50F0E6"
        case .fair: return "#50CCAA"
        case .moderate: return "#F0E641"
        case .poor: return "#E63A52"
        case .veryPoor: return "#872181"
        }
    }

    /// Créer depuis l'indice ATMO (1-6, on regroupe 5-6 en veryPoor)
    static func from(atmoIndex: Int) -> AirQualityLevel {
        switch atmoIndex {
        case 1: return .good
        case 2: return .fair
        case 3: return .moderate
        case 4: return .poor
        default: return .veryPoor // 5, 6 ou inconnu
        }
    }
}

// MARK: - Incity Weather Category

/// Catégories météo simplifiées pour Incity (pas de saisons)
enum IncityWeatherCategory: String, CaseIterable {
    case clearGolden    // Lever/coucher de soleil
    case clearDay       // Jour ensoleillé
    case partlyCloudy   // Partiellement nuageux
    case cloudy         // Nuageux
    case rainy          // Pluie
    case snowy          // Neige
    case stormy         // Orage

    /// Nom du fichier image jour
    var dayImageName: String {
        switch self {
        case .clearGolden: return "incity_clear_golden"
        case .clearDay: return "incity_clear_day"
        case .partlyCloudy: return "incity_partly_cloudy_day"
        case .cloudy: return "incity_cloudy_day"
        case .rainy: return "incity_rain_day"
        case .snowy: return "incity_snow_day"
        case .stormy: return "incity_storm_day"
        }
    }

    /// Mappe une condition WeatherKit vers une catégorie Incity
    static func from(condition: WeatherCondition) -> IncityWeatherCategory {
        switch condition {
        // STORMY
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms,
             .strongStorms, .tropicalStorm, .hurricane:
            return .stormy

        // SNOWY
        case .snow, .heavySnow, .flurries, .blizzard, .blowingSnow, .frigid, .sunFlurries:
            return .snowy

        // RAINY
        case .drizzle, .rain, .heavyRain, .freezingDrizzle, .freezingRain,
             .sleet, .hail, .wintryMix, .sunShowers:
            return .rainy

        // PARTLY CLOUDY
        case .partlyCloudy, .mostlyClear:
            return .partlyCloudy

        // CLOUDY
        case .mostlyCloudy, .cloudy, .foggy, .haze, .smoky, .blowingDust, .windy, .breezy:
            return .cloudy

        // CLEAR
        case .clear, .hot:
            return .clearDay

        @unknown default:
            return .cloudy
        }
    }
}

// MARK: - Incity Special Event (Easter Eggs)

/// Événements spéciaux pour le widget Incity
enum IncitySpecialEvent: String, CaseIterable {
    case feteLumieres    // 8-11 décembre
    case noel            // 24-25 décembre
    case nouvelAn        // 31 décembre & 1er janvier
    case juillet14       // 14 Juillet
    case halloween       // 31 octobre
    case saintValentin   // 14 février

    /// Vérifie si l'événement est actif à une date donnée
    func isActive(on date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        switch self {
        case .feteLumieres:
            return month == 12 && (day >= 8 && day <= 11)
        case .noel:
            return month == 12 && (day == 24 || day == 25)
        case .nouvelAn:
            return (month == 12 && day == 31) || (month == 1 && day == 1)
        case .juillet14:
            return month == 7 && day == 14
        case .halloween:
            return month == 10 && day == 31
        case .saintValentin:
            return month == 2 && day == 14
        }
    }

    /// Nom du fichier image jour
    var dayImageName: String {
        return "incity_\(fileBaseName)_day"
    }

    /// Nom du fichier image nuit
    var nightImageName: String {
        return "incity_\(fileBaseName)_night"
    }

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

    /// Nom affiché
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

    /// Retourne l'événement actif pour une date donnée
    static func activeEvent(for date: Date) -> IncitySpecialEvent? {
        for event in IncitySpecialEvent.allCases {
            if event.isActive(on: date) {
                return event
            }
        }
        return nil
    }
}

// MARK: - Incity Background Service

/// Service principal pour déterminer le fond du widget Incity
final class IncityBackgroundService {

    // MARK: - Singleton

    static let shared = IncityBackgroundService()

    private init() {}

    // MARK: - Public API

    /// Détermine le nom de l'image de fond pour le widget Incity
    /// - Parameters:
    ///   - date: Date/heure actuelle
    ///   - condition: Condition météo WeatherKit
    ///   - sunrise: Lever du soleil
    ///   - sunset: Coucher du soleil
    ///   - tomorrowAirQualityIndex: Indice qualité air de demain (pour LED nuit)
    ///   - moonPhase: Phase de la lune (optionnel)
    /// - Returns: Nom de l'image de fond
    func backgroundImageName(
        for date: Date,
        condition: WeatherCondition,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        tomorrowAirQualityIndex: Int? = nil,
        isFullMoon: Bool = false
    ) -> String {

        // 1. EASTER EGGS - Priorité maximale
        if let specialEvent = IncitySpecialEvent.activeEvent(for: date) {
            let isDay = isDaytime(date: date, sunrise: sunrise, sunset: sunset)
            let imageName = isDay ? specialEvent.dayImageName : specialEvent.nightImageName

            #if DEBUG
            print("🎉 Incity Easter Egg: \(specialEvent.displayName) | \(imageName)")
            #endif

            return imageName
        }

        // 2. JOUR ou NUIT ?
        let isDay = isDaytime(date: date, sunrise: sunrise, sunset: sunset)

        if isDay {
            // JOUR - Utiliser la météo
            return dayBackgroundImageName(
                for: date,
                condition: condition,
                sunrise: sunrise,
                sunset: sunset
            )
        } else {
            // NUIT - Utiliser la qualité de l'air de demain
            return nightBackgroundImageName(
                tomorrowAirQualityIndex: tomorrowAirQualityIndex,
                isFullMoon: isFullMoon
            )
        }
    }

    // MARK: - Day Background

    private func dayBackgroundImageName(
        for date: Date,
        condition: WeatherCondition,
        sunrise: Date?,
        sunset: Date?
    ) -> String {

        // Vérifier si c'est l'heure dorée (golden hour)
        if isGoldenHour(date: date, sunrise: sunrise, sunset: sunset) {
            // Golden hour uniquement pour beau temps
            let category = IncityWeatherCategory.from(condition: condition)
            if category == .clearDay || category == .partlyCloudy {
                return IncityWeatherCategory.clearGolden.dayImageName
            }
        }

        // Sinon, utiliser la catégorie météo
        let category = IncityWeatherCategory.from(condition: condition)
        return category.dayImageName
    }

    // MARK: - Night Background

    private func nightBackgroundImageName(
        tomorrowAirQualityIndex: Int?,
        isFullMoon: Bool
    ) -> String {

        // Déterminer le niveau de qualité de l'air
        let airQualityLevel: AirQualityLevel
        if let index = tomorrowAirQualityIndex {
            airQualityLevel = AirQualityLevel.from(atmoIndex: index)
        } else {
            // Fallback: qualité moyenne si pas de données
            airQualityLevel = .fair
        }

        // Pleine lune ou nuit normale ?
        if isFullMoon {
            return airQualityLevel.fullMoonImageName
        } else {
            return airQualityLevel.nightImageName
        }
    }

    // MARK: - Time Helpers

    /// Vérifie si c'est le jour (entre lever et coucher du soleil)
    private func isDaytime(date: Date, sunrise: Date?, sunset: Date?) -> Bool {
        guard let sunrise = sunrise, let sunset = sunset else {
            // Fallback: 7h-19h = jour
            let hour = Calendar.current.component(.hour, from: date)
            return hour >= 7 && hour < 19
        }

        return date >= sunrise && date < sunset
    }

    /// Vérifie si c'est l'heure dorée (30min avant/après lever ou coucher)
    private func isGoldenHour(date: Date, sunrise: Date?, sunset: Date?) -> Bool {
        guard let sunrise = sunrise, let sunset = sunset else {
            return false
        }

        let goldenMargin: TimeInterval = 45 * 60 // 45 minutes

        // Golden hour matin : 30min avant à 45min après lever
        let morningStart = sunrise.addingTimeInterval(-30 * 60)
        let morningEnd = sunrise.addingTimeInterval(goldenMargin)

        // Golden hour soir : 45min avant à 30min après coucher
        let eveningStart = sunset.addingTimeInterval(-goldenMargin)
        let eveningEnd = sunset.addingTimeInterval(30 * 60)

        return (date >= morningStart && date < morningEnd) ||
               (date >= eveningStart && date < eveningEnd)
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension IncityBackgroundService {

    /// Liste tous les noms d'images possibles (pour vérification des assets)
    static var allPossibleImageNames: [String] {
        var names: [String] = []

        // Images météo jour
        for category in IncityWeatherCategory.allCases {
            names.append(category.dayImageName)
        }

        // Images nuit (5 couleurs)
        for level in AirQualityLevel.allCases {
            names.append(level.nightImageName)
        }

        // Images pleine lune (5 couleurs)
        for level in AirQualityLevel.allCases {
            names.append(level.fullMoonImageName)
        }

        // Easter eggs
        for event in IncitySpecialEvent.allCases {
            names.append(event.dayImageName)
            names.append(event.nightImageName)
        }

        return names
    }

    /// Compte total d'images
    static var totalImageCount: Int {
        // 7 météo jour + 5 nuit + 5 pleine lune + 12 easter eggs = 29
        return allPossibleImageNames.count
    }
}
#endif
