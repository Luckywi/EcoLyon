//
//  MapDataService.swift
//  EcoLyon
//
//  Service générique pour le chargement des données de carte.
//  Élimine la duplication de code entre les différentes MapViews.
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Protocols

/// Protocol de base pour tous les types de localisation sur la carte
protocol MapLocationProtocol: Identifiable {
    var id: UUID { get }
    var coordinate: CLLocationCoordinate2D { get }
}

/// Protocol pour les configurations de service API
protocol MapDataConfiguration {
    associatedtype LocationType: MapLocationProtocol
    associatedtype PropertiesType: Decodable

    /// URL de l'API (endpoint GeoServer)
    var apiURL: String { get }

    /// Rayon de recherche en mètres
    var searchRadius: Double { get }

    /// Nombre maximum d'éléments à afficher
    var maxItemsToShow: Int { get }

    /// Convertit les propriétés GeoJSON en modèle de localisation
    func parseLocation(coordinates: [Double], properties: PropertiesType) -> LocationType?
}

// MARK: - Generic GeoJSON Response

/// Structure générique pour les réponses GeoJSON
struct GenericGeoJSONResponse<Properties: Decodable>: Decodable {
    let type: String
    let features: [GenericFeature<Properties>]
    let totalFeatures: Int?
}

struct GenericFeature<Properties: Decodable>: Decodable {
    let type: String
    let geometry: GenericGeometry
    let properties: Properties
}

struct GenericGeometry: Decodable {
    let type: String
    let coordinates: [Double]
}

// MARK: - API Error

/// Erreur générique pour les services API
enum MapDataAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .httpError(let code):
            return "Erreur HTTP: \(code)"
        case .decodingError(let error):
            return "Erreur de décodage: \(error.localizedDescription)"
        case .noData:
            return "Aucune donnée disponible"
        }
    }
}

// MARK: - Cache Structure

/// Structure de cache de zone
struct ZoneCache<T> {
    let items: [T]
    let timestamp: Date
    let centerLocation: CLLocationCoordinate2D
}

// MARK: - Generic Map Data Service

/// Service générique pour charger des données de carte
/// Utilise un système de cache global + local pour optimiser les performances
@MainActor
class MapDataService<Config: MapDataConfiguration>: ObservableObject {

    // MARK: - Published Properties

    @Published var items: [Config.LocationType] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Configuration

    private let config: Config

    // MARK: - Cache Properties

    private var zoneCache: [String: ZoneCache<Config.LocationType>] = [:]
    private let cacheExpiryTime: TimeInterval = 3600 // 1 heure

    // Cache global (static par type de configuration)
    private static var globalCacheStorage: [String: Any] {
        get { GlobalCacheManager.shared.getCache(for: String(describing: Config.self)) }
        set { GlobalCacheManager.shared.setCache(newValue, for: String(describing: Config.self)) }
    }

    private var globalCache: [Config.LocationType] {
        get { (Self.globalCacheStorage["items"] as? [Config.LocationType]) ?? [] }
        set {
            var storage = Self.globalCacheStorage
            storage["items"] = newValue
            storage["timestamp"] = Date()
            Self.globalCacheStorage = storage
        }
    }

    private var globalCacheTimestamp: Date {
        (Self.globalCacheStorage["timestamp"] as? Date) ?? Date.distantPast
    }

    private let globalCacheExpiry: TimeInterval = 86400 // 24 heures

    // MARK: - Initialization

    init(configuration: Config) {
        self.config = configuration
    }

    // MARK: - Public Methods

    /// Charge les données autour d'une localisation
    func loadAroundLocation(_ location: CLLocationCoordinate2D) async {
        // Vérifier le cache global d'abord
        if !globalCache.isEmpty,
           Date().timeIntervalSince(globalCacheTimestamp) < globalCacheExpiry {

            let nearbyItems = filterAndSortByDistance(globalCache, from: location)
            self.items = Array(nearbyItems.prefix(config.maxItemsToShow))
            print("🌍 Cache global utilisé: \(self.items.count) éléments trouvés")
            return
        }

        // Vérifier le cache local
        let zoneKey = generateZoneKey(for: location)
        if let cachedZone = zoneCache[zoneKey],
           Date().timeIntervalSince(cachedZone.timestamp) < cacheExpiryTime,
           cachedZone.centerLocation.distance(to: location) < 200 {

            items = Array(cachedZone.items.prefix(config.maxItemsToShow))
            print("📦 Cache local utilisé: \(items.count) éléments depuis le cache")
            return
        }

        // Charger depuis l'API
        await loadFromAPI(around: location)
    }

    /// Force le rechargement des données
    func forceReload(around location: CLLocationCoordinate2D) async {
        // Invalider les caches
        zoneCache.removeAll()
        globalCache = []

        await loadFromAPI(around: location)
    }

    // MARK: - Private Methods

    private func loadFromAPI(around location: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil

        do {
            guard let url = URL(string: config.apiURL) else {
                throw MapDataAPIError.invalidURL
            }

            print("🔄 Chargement depuis l'API...")

            var request = URLRequest(url: url)
            request.timeoutInterval = 15.0

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw MapDataAPIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw MapDataAPIError.httpError(httpResponse.statusCode)
            }

            let geoJsonResponse = try JSONDecoder().decode(
                GenericGeoJSONResponse<Config.PropertiesType>.self,
                from: data
            )

            print("📊 Features reçues: \(geoJsonResponse.features.count)")

            let allLocations = geoJsonResponse.features.compactMap { feature -> Config.LocationType? in
                guard feature.geometry.coordinates.count >= 2 else { return nil }
                return config.parseLocation(
                    coordinates: feature.geometry.coordinates,
                    properties: feature.properties
                )
            }

            // Mettre à jour le cache global
            globalCache = allLocations
            print("🌍 Cache global mis à jour avec \(allLocations.count) éléments")

            // Filtrer par distance
            let nearbyLocations = filterAndSortByDistance(allLocations, from: location)
            let limitedItems = Array(nearbyLocations.prefix(config.maxItemsToShow))

            // Mettre en cache local
            let zoneKey = generateZoneKey(for: location)
            zoneCache[zoneKey] = ZoneCache(
                items: nearbyLocations,
                timestamp: Date(),
                centerLocation: location
            )

            items = limitedItems
            isLoading = false

            print("✅ \(limitedItems.count) éléments chargés et triés par distance")

        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            isLoading = false
            print("❌ Erreur: \(error)")
        }
    }

    private func filterAndSortByDistance(_ locations: [Config.LocationType], from center: CLLocationCoordinate2D) -> [Config.LocationType] {
        // Calculer les distances
        var locationsWithDistance: [(location: Config.LocationType, distance: Double)] = []

        for location in locations {
            let dist = center.distance(to: location.coordinate)
            if dist <= config.searchRadius {
                locationsWithDistance.append((location: location, distance: dist))
            }
        }

        // Trier par distance
        locationsWithDistance.sort { $0.distance < $1.distance }

        // Extraire les locations
        return locationsWithDistance.map { $0.location }
    }

    private func generateZoneKey(for location: CLLocationCoordinate2D) -> String {
        let gridSize = 0.01 // ~1km de grille
        let gridLat = Int(location.latitude / gridSize)
        let gridLon = Int(location.longitude / gridSize)
        return "zone_\(gridLat)_\(gridLon)"
    }
}

// MARK: - Global Cache Manager

/// Gestionnaire de cache global pour éviter les problèmes de generics avec static
final class GlobalCacheManager {
    static let shared = GlobalCacheManager()

    private var caches: [String: [String: Any]] = [:]
    private let lock = NSLock()

    private init() {}

    func getCache(for key: String) -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return caches[key] ?? [:]
    }

    func setCache(_ cache: [String: Any], for key: String) {
        lock.lock()
        defer { lock.unlock() }
        caches[key] = cache
    }

    func clearCache(for key: String) {
        lock.lock()
        defer { lock.unlock() }
        caches.removeValue(forKey: key)
    }

    func clearAllCaches() {
        lock.lock()
        defer { lock.unlock() }
        caches.removeAll()
    }
}

