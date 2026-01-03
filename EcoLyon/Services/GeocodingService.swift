//
//  GeocodingService.swift
//  EcoLyon
//
//  Service centralisé pour le géocodage et la recherche d'adresses.
//  Utilise MKLocalSearchCompleter pour l'autocomplétion instantanée.
//

import Foundation
import MapKit
import CoreLocation
import Combine

// MARK: - AddressSuggestion Model

/// Représente une suggestion d'adresse pour l'autocomplétion
struct AddressSuggestion: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    var coordinate: CLLocationCoordinate2D
    let completion: MKLocalSearchCompletion?

    init(title: String, subtitle: String, coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(), completion: MKLocalSearchCompletion? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.completion = completion
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AddressSuggestion, rhs: AddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - GeocodingService

/// Service centralisé pour toutes les opérations de géocodage
/// Utilise MKLocalSearchCompleter pour des résultats instantanés
@MainActor
final class GeocodingService: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = GeocodingService()

    // MARK: - Published Properties

    @Published private(set) var suggestions: [AddressSuggestion] = []
    @Published private(set) var isSearching = false

    // MARK: - Private Properties

    private let completer: MKLocalSearchCompleter
    private var currentQuery: String = ""
    private var completionHandler: (([AddressSuggestion]) -> Void)?

    /// Centre de Lyon pour la recherche régionale
    private let lyonCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)

    // MARK: - Initialization

    override private init() {
        self.completer = MKLocalSearchCompleter()

        super.init()

        // Configuration du completer
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]

        // Région centrée sur Lyon avec un large rayon
        completer.region = MKCoordinateRegion(
            center: lyonCenter,
            latitudinalMeters: 100_000,  // 100km
            longitudinalMeters: 100_000
        )
    }

    // MARK: - Public Methods

    /// Recherche des adresses correspondant à une requête (autocomplétion instantanée)
    /// - Parameter query: La chaîne de recherche
    /// - Returns: Un tableau de suggestions d'adresses
    func searchAddresses(query: String) async -> [AddressSuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            suggestions = []
            return []
        }

        currentQuery = trimmedQuery

        return await withCheckedContinuation { continuation in
            self.completionHandler = { results in
                continuation.resume(returning: results)
            }

            // Déclenche la recherche - les résultats arrivent via le delegate
            completer.queryFragment = trimmedQuery
        }
    }

    /// Obtient les coordonnées d'une suggestion sélectionnée
    /// - Parameter suggestion: La suggestion à géocoder
    /// - Returns: Les coordonnées correspondantes
    func getCoordinate(for suggestion: AddressSuggestion) async -> CLLocationCoordinate2D? {
        // Si on a déjà les coordonnées valides
        if suggestion.coordinate.latitude != 0 && suggestion.coordinate.longitude != 0 {
            return suggestion.coordinate
        }

        // Sinon, utiliser MKLocalSearch pour obtenir les coordonnées
        guard let completion = suggestion.completion else {
            return await geocodeAddress("\(suggestion.title) \(suggestion.subtitle)")
        }

        return await withCheckedContinuation { continuation in
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)

            search.start { response, error in
                if let coordinate = response?.mapItems.first?.placemark.coordinate {
                    continuation.resume(returning: coordinate)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Géocode une adresse textuelle en coordonnées
    /// - Parameter address: L'adresse à géocoder
    /// - Returns: Les coordonnées correspondantes, ou nil si non trouvées
    func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    print("❌ GeocodingService - Erreur géocodage: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                let coordinate = placemarks?.first?.location?.coordinate
                continuation.resume(returning: coordinate)
            }
        }
    }

    // MARK: - Private Methods

    /// Filtre les résultats pour la France uniquement
    private func filterFrenchResults(_ completions: [MKLocalSearchCompletion]) -> [MKLocalSearchCompletion] {
        return completions.filter { completion in
            let subtitle = completion.subtitle.lowercased()

            // Indicateurs français
            let frenchIndicators = ["france", "lyon", "rhône", "rhone",
                                    "villeurbanne", "vénissieux", "venissieux",
                                    "caluire", "bron", "vaulx", "saint-priest",
                                    "oullins", "tassin", "écully", "ecully",
                                    "décines", "decines", "meyzieu", "rillieux"]

            // Vérifier si contient un indicateur français
            for indicator in frenchIndicators {
                if subtitle.contains(indicator) {
                    return true
                }
            }

            // Vérifier le code postal français (5 chiffres commençant par 69 pour Lyon)
            let postalCodePattern = /\b69\d{3}\b/
            if subtitle.contains(postalCodePattern) {
                return true
            }

            // Accepter si pas d'indicateur de pays étranger
            let foreignIndicators = ["germany", "deutschland", "italy", "italia",
                                     "spain", "españa", "uk", "united kingdom",
                                     "belgium", "belgique", "switzerland", "suisse"]

            for indicator in foreignIndicators {
                if subtitle.contains(indicator) {
                    return false
                }
            }

            return true
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension GeocodingService: MKLocalSearchCompleterDelegate {

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            // Filtrer pour la France
            let filteredResults = filterFrenchResults(completer.results)

            // Convertir en suggestions
            let newSuggestions = filteredResults.prefix(6).map { completion in
                AddressSuggestion(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    coordinate: CLLocationCoordinate2D(),
                    completion: completion
                )
            }

            self.suggestions = Array(newSuggestions)

            // Appeler le completion handler si présent
            self.completionHandler?(self.suggestions)
            self.completionHandler = nil
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ GeocodingService - Erreur completer: \(error.localizedDescription)")
            self.suggestions = []
            self.completionHandler?([])
            self.completionHandler = nil
        }
    }
}

// MARK: - Convenience Extension

extension GeocodingService {

    /// Wrapper simplifié pour la recherche
    func search(_ query: String) async -> [AddressSuggestion] {
        await searchAddresses(query: query)
    }
}
