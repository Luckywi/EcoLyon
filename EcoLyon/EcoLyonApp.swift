import SwiftUI
import CoreLocation

// MARK: - Service LocationService GLOBAL OPTIMISÉ
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
    private var isUpdatingLocation = false
    private var fallbackTimer: Timer?
    private var positionCount = 0 // Compteur pour arrêter après quelques positions précises
    
    override init() {
        super.init()
        setupLocationManager()
        // ✅ DÉMARRER IMMÉDIATEMENT avec position connue + continuous updates
        startLocationDetection()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Mise à jour tous les 50m minimum
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // ✅ NOUVELLE STRATÉGIE : Position connue + continuous updates
    func startLocationDetection() {
        guard !hasStartedLocation else { return }
        hasStartedLocation = true
        
        print("🚀 Démarrage localisation globale optimisée")
        
        // ✅ ÉTAPE 1 : Utiliser IMMÉDIATEMENT la position connue si disponible
        if let lastKnownLocation = locationManager.location {
            print("📍 Position connue trouvée : \(lastKnownLocation.coordinate)")
            processLocation(lastKnownLocation.coordinate, isKnownLocation: true)
        }
        
        // ✅ ÉTAPE 2 : Lancer les mises à jour continues selon les permissions
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startContinuousLocationUpdates()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Position connue déjà traitée ci-dessus, sinon fallback
            if userLocation == nil {
                scheduleFallback()
            }
        @unknown default:
            if userLocation == nil {
                scheduleFallback()
            }
        }
    }
    
    // ✅ NOUVELLE MÉTHODE : Mises à jour continues
    private func startContinuousLocationUpdates() {
        guard !isUpdatingLocation else { return }
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        print("🔄 Démarrage mises à jour continues")
        isUpdatingLocation = true
        positionCount = 0
        locationManager.startUpdatingLocation()
        
        // ✅ Fallback seulement si pas de position après 5 secondes
        if userLocation == nil {
            scheduleFallback()
        }
    }
    
    // ✅ NOUVELLE MÉTHODE : Arrêter les mises à jour
    func stopLocationUpdates() {
        guard isUpdatingLocation else { return }
        
        print("⏸️ Arrêt mises à jour location")
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }
    
    // ✅ Fallback différé et conditionnel
    private func scheduleFallback() {
        fallbackTimer?.invalidate()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            Task { @MainActor in
                if self.userLocation == nil && !self.isLocationReady {
                    print("⏰ Fallback après 5s - aucune position disponible")
                    self.setFallbackDistrict()
                }
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
    
    // ✅ NOUVELLE MÉTHODE : Traitement centralisé des positions
    private func processLocation(_ coordinate: CLLocationCoordinate2D, isKnownLocation: Bool = false) {
        userLocation = coordinate
        
        // Calcul immédiat de l'arrondissement
        let nearestDistrict = calculateNearestDistrict(from: coordinate)
        detectedDistrict = nearestDistrict
        isLocationReady = true
        locationError = nil
        
        // Annuler le fallback si en cours
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        
        let locationSource = isKnownLocation ? "(position connue)" : "(nouvelle position)"
        print("✅ Position traitée \(locationSource): \(nearestDistrict.name) (\(coordinate.latitude), \(coordinate.longitude))")
        
        // ✅ Arrêter les mises à jour après 3 positions précises nouvelles
        if !isKnownLocation && isUpdatingLocation {
            positionCount += 1
            if positionCount >= 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.stopLocationUpdates()
                    print("🎯 3 positions reçues, arrêt des mises à jour")
                }
            }
        }
    }
    
    // ✅ Calcul optimisé de l'arrondissement
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
    
    // ✅ NOUVELLE MÉTHODE : Redémarrer la localisation si nécessaire
    func refreshLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("🚫 Pas d'autorisation pour refresh location")
            return
        }
        
        if !isUpdatingLocation {
            print("🔄 Refresh location demandé")
            startContinuousLocationUpdates()
        }
    }
    
    // ✅ NOUVELLE MÉTHODE : Forcer une nouvelle localisation
    func forceLocationUpdate() {
        if isUpdatingLocation {
            stopLocationUpdates()
        }
        
        // Petite pause puis redémarrage
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate OPTIMISÉ
extension GlobalLocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // ✅ Utiliser la méthode centralisée de traitement
        processLocation(location.coordinate, isKnownLocation: false)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Erreur localisation: \(error)")
        
        // ✅ Ne pas fallback immédiatement, garder la position connue si elle existe
        if userLocation == nil {
            setFallbackDistrict()
        }
        
        // Arrêter les mises à jour en cas d'erreur
        stopLocationUpdates()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // ✅ Vérifier position connue puis démarrer les mises à jour
            if let lastKnownLocation = locationManager.location, userLocation == nil {
                print("📍 Autorisation accordée - position connue disponible")
                processLocation(lastKnownLocation.coordinate, isKnownLocation: true)
            }
            startContinuousLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
            if userLocation == nil {
                setFallbackDistrict()
            }
        case .notDetermined:
            break
        @unknown default:
            stopLocationUpdates()
            if userLocation == nil {
                setFallbackDistrict()
            }
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
        // ✅ DÉMARRER LA LOCALISATION DÈS LE LANCEMENT AVEC STRATÉGIE OPTIMISÉE
        _ = GlobalLocationService.shared
        print("🚀 App lancée - Localisation optimisée démarrée immédiatement")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.light)
        }
    }
}
