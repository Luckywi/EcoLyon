//
//  WidgetLocationManager.swift
//  EcoLyonWidget
//
//  Gestionnaire de localisation pour le widget.
//  Utilise un cache partagé via App Group et une localisation limitée.
//

import CoreLocation
import Foundation

// MARK: - App Group Constants

enum AppGroupConstants {
    static let suiteName = "group.com.ecolyon.shared"
    static let lastLatitudeKey = "lastUserLatitude"
    static let lastLongitudeKey = "lastUserLongitude"
    static let lastLocationTimestampKey = "lastLocationTimestamp"
    static let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
}

// MARK: - Widget Location Manager

final class WidgetLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = WidgetLocationManager()

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Cache Management

    /// Récupère la dernière position connue depuis le cache App Group
    func getCachedLocation() -> CLLocationCoordinate2D? {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else {
            return nil
        }

        // Vérifier l'expiration du cache
        let timestamp = defaults.double(forKey: AppGroupConstants.lastLocationTimestampKey)
        let cacheAge = Date().timeIntervalSince1970 - timestamp

        guard cacheAge < AppGroupConstants.cacheExpiryInterval else {
            return nil
        }

        let latitude = defaults.double(forKey: AppGroupConstants.lastLatitudeKey)
        let longitude = defaults.double(forKey: AppGroupConstants.lastLongitudeKey)

        guard latitude != 0 && longitude != 0 else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Sauvegarde la position dans le cache App Group
    func cacheLocation(_ coordinate: CLLocationCoordinate2D) {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else {
            return
        }

        defaults.set(coordinate.latitude, forKey: AppGroupConstants.lastLatitudeKey)
        defaults.set(coordinate.longitude, forKey: AppGroupConstants.lastLongitudeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: AppGroupConstants.lastLocationTimestampKey)
    }

    // MARK: - Location Request

    /// Demande la position actuelle (avec timeout)
    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        let authStatus = locationManager.authorizationStatus

        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()

            // Timeout après 5 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if self?.locationContinuation != nil {
                    self?.locationContinuation?.resume(returning: nil)
                    self?.locationContinuation = nil
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        let coordinate = location.coordinate
        cacheLocation(coordinate)

        locationContinuation?.resume(returning: coordinate)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Widget Location Error: \(error.localizedDescription)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}

// MARK: - Location Cache Helper (Pour l'app principale)

/// Classe à appeler depuis l'app principale pour mettre à jour le cache
final class LocationCacheHelper {
    static let shared = LocationCacheHelper()

    private init() {}

    /// Met à jour le cache de position (à appeler depuis l'app principale)
    func updateLocationCache(latitude: Double, longitude: Double) {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) else {
            return
        }

        defaults.set(latitude, forKey: AppGroupConstants.lastLatitudeKey)
        defaults.set(longitude, forKey: AppGroupConstants.lastLongitudeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: AppGroupConstants.lastLocationTimestampKey)

        print("📍 Cache position mis à jour: \(latitude), \(longitude)")
    }
}
