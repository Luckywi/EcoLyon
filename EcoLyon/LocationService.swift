import Foundation
import CoreLocation
import MapKit

// MARK: - Service de géolocalisation amélioré avec état de chargement

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLocationReady = false // ✅ NOUVEAU : Indique si la localisation est prête
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasRequestedLocation = false // ✅ Évite les demandes multiples
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        
        // ✅ Si on a déjà l'autorisation, on commence directement
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
    }
    
    // MARK: - Permissions et localisation
    
    func requestLocationPermission() {
        guard authorizationStatus == .notDetermined else {
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                startLocationUpdates()
            }
            return
        }
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func startLocationUpdates() {
        guard !hasRequestedLocation else { return }
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            isLocationReady = true // ✅ Marquer comme "prêt" même sans permission
            errorMessage = "Permission de localisation requise"
            return
        }
        
        hasRequestedLocation = true
        isLoading = true
        errorMessage = nil
        locationManager.requestLocation()
        
        // ✅ Timeout de sécurité après 10 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isLoading && self.userLocation == nil {
                self.isLoading = false
                self.isLocationReady = true
                self.errorMessage = "Localisation impossible, utilisation de la position par défaut"
                print("⏰ Timeout de localisation après 10 secondes")
            }
        }
    }
    
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Permission de localisation requise"
            return
        }
        
        isLoading = true
        errorMessage = nil
        locationManager.requestLocation()
    }
    
    // ✅ NOUVEAU : Méthode pour vérifier si l'utilisateur est dans un arrondissement de Lyon
    func getNearestLyonDistrict() -> District? {
        guard let userLocation = userLocation else { return nil }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        
        // Trouver l'arrondissement le plus proche
        let nearestDistrict = Lyon.districts.min { district1, district2 in
            let location1 = CLLocation(latitude: district1.coordinate.latitude, longitude: district1.coordinate.longitude)
            let location2 = CLLocation(latitude: district2.coordinate.latitude, longitude: district2.coordinate.longitude)
            return userCLLocation.distance(from: location1) < userCLLocation.distance(from: location2)
        }
        
        // Vérifier si l'utilisateur est dans un rayon raisonnable (5km)
        if let nearest = nearestDistrict {
            let districtLocation = CLLocation(latitude: nearest.coordinate.latitude, longitude: nearest.coordinate.longitude)
            if userCLLocation.distance(from: districtLocation) < 5000 {
                return nearest
            }
        }
        
        return nil
    }
    
    // ✅ NOUVEAU : Vérifier si l'utilisateur est à Lyon (dans un rayon de 20km du centre)
    func isUserInLyon() -> Bool {
        guard let userLocation = userLocation else { return false }
        
        let lyonCenter = CLLocation(latitude: 45.7640, longitude: 4.8357)
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        
        return userCLLocation.distance(from: lyonCenter) < 20000 // 20km
    }
    
    // MARK: - Géocodage et suggestions (inchangé)
    
    func searchAddresses(query: String) async -> [AddressSuggestion] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            
            let lyonCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
            let searchRegion = MKCoordinateRegion(
                center: lyonCenter,
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
            request.region = searchRegion
            request.resultTypes = [.address, .pointOfInterest]
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if let error = error {
                    print("❌ Erreur géocodage: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }
                
                let filteredItems = response?.mapItems.filter { item in
                    let placemark = item.placemark
                    let country = placemark.country?.lowercased() ?? ""
                    let countryCode = placemark.isoCountryCode?.lowercased() ?? ""
                    let postalCode = placemark.postalCode ?? ""
                    
                    let isFrance = country.contains("france") ||
                                  country.contains("fr") ||
                                  countryCode == "fr" ||
                                  (postalCode.count == 5 && postalCode.allSatisfy { $0.isNumber })
                    
                    return isFrance
                } ?? []
                
                let suggestions = filteredItems.prefix(5).map { item in
                    AddressSuggestion(
                        title: item.name ?? "Sans nom",
                        subtitle: self.formatFrenchAddress(item.placemark),
                        coordinate: item.placemark.coordinate
                    )
                }
                
                continuation.resume(returning: Array(suggestions))
            }
        }
    }
    
    private func formatFrenchAddress(_ placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let streetNumber = placemark.subThoroughfare {
            components.append(streetNumber)
        }
        
        if let street = placemark.thoroughfare {
            components.append(street)
        }
        
        if let postalCode = placemark.postalCode,
           let city = placemark.locality {
            components.append("\(postalCode) \(city)")
        } else if let city = placemark.locality {
            components.append(city)
        }
        
        return components.joined(separator: ", ")
    }
    
    func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    print("❌ Erreur géocodage adresse: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                let coordinate = placemarks?.first?.location?.coordinate
                continuation.resume(returning: coordinate)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        userLocation = location.coordinate
        isLoading = false
        isLocationReady = true // ✅ Marquer comme prêt
        errorMessage = nil
        
        print("📍 Position mise à jour: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        isLocationReady = true // ✅ Marquer comme prêt même en cas d'erreur
        errorMessage = "Erreur de localisation: \(error.localizedDescription)"
        print("❌ Erreur localisation: \(error)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            isLocationReady = true // ✅ Marquer comme prêt
            errorMessage = "Accès à la localisation refusé"
        case .notDetermined:
            break
        @unknown default:
            isLocationReady = true
            break
        }
    }
}

// MARK: - Modèles inchangés

struct AddressSuggestion: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AddressSuggestion, rhs: AddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }
    
    func formatDistance(to coordinate: CLLocationCoordinate2D) -> String {
        let distance = self.distance(to: coordinate)
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}
