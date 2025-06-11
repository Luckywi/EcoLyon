import SwiftUI
import CoreLocation

// MARK: - Service LocationService GLOBAL (nouveau)
@MainActor
class GlobalLocationService: NSObject, ObservableObject {
    static let shared = GlobalLocationService()
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var detectedDistrict: District?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationReady = false
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    private var hasStartedLocation = false
    
    override init() {
        super.init()
        setupLocationManager()
        // ✅ DÉMARRER IMMÉDIATEMENT au lancement de l'app
        startLocationDetection()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // ✅ Démarre la localisation immédiatement sans attendre
    func startLocationDetection() {
        guard !hasStartedLocation else { return }
        hasStartedLocation = true
        
        print("🚀 Démarrage localisation globale immédiate")
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocationNow()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            setFallbackDistrict()
        @unknown default:
            setFallbackDistrict()
        }
    }
    
    private func requestLocationNow() {
        print("📍 Demande de position immédiate")
        locationManager.requestLocation()
        
        // Timeout de sécurité : 3 secondes max
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !self.isLocationReady {
                print("⏰ Timeout localisation après 3s")
                self.setFallbackDistrict()
            }
        }
    }
    
    private func setFallbackDistrict() {
        let fallback = Lyon.districts[0] // Lyon 1er
        detectedDistrict = fallback
        isLocationReady = true
        locationError = userLocation == nil ? "Position indisponible" : nil
        print("🏠 Fallback: \(fallback.name)")
    }
    
    // ✅ Calcul immédiat de l'arrondissement (< 5ms)
    private func calculateNearestDistrict(from location: CLLocationCoordinate2D) -> District {
        let userCLLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        let nearest = Lyon.districts.min { district1, district2 in
            let location1 = CLLocation(latitude: district1.coordinate.latitude, longitude: district1.coordinate.longitude)
            let location2 = CLLocation(latitude: district2.coordinate.latitude, longitude: district2.coordinate.longitude)
            return userCLLocation.distance(from: location1) < userCLLocation.distance(from: location2)
        }
        
        return nearest ?? Lyon.districts[0]
    }
    
    // Fonction publique pour changer d'arrondissement manuellement
    func setDistrict(_ district: District) {
        detectedDistrict = district
    }
}

// MARK: - CLLocationManagerDelegate
extension GlobalLocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let coordinate = location.coordinate
        userLocation = coordinate
        
        // ✅ Calcul immédiat de l'arrondissement
        let nearestDistrict = calculateNearestDistrict(from: coordinate)
        detectedDistrict = nearestDistrict
        isLocationReady = true
        
        print("✅ Position détectée: \(nearestDistrict.name) (\(coordinate.latitude), \(coordinate.longitude))")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Erreur localisation: \(error)")
        setFallbackDistrict()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocationNow()
        case .denied, .restricted:
            setFallbackDistrict()
        case .notDetermined:
            break
        @unknown default:
            setFallbackDistrict()
        }
    }
}

// Vue racine qui gère le loading screen
struct RootView: View {
    @State private var showLoadingScreen = true
    
    var body: some View {
        ZStack {
            if showLoadingScreen {
                AppLoadingView {
                    showLoadingScreen = false
                }
                .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showLoadingScreen)
    }
}

@main
struct EcoLyonApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // ✅ DÉMARRER LA LOCALISATION DÈS LE LANCEMENT
        _ = GlobalLocationService.shared
        print("🚀 App lancée - Localisation démarrée immédiatement")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.light)
        }
    }
}
