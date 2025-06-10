import SwiftUI
import MapKit
import CoreLocation

// MARK: - Modèles de données
struct AirQualityResponse: Codable {
    let data: [AirQualityData]
}

struct AirQualityData: Codable {
    let indice: Int
    let qualificatif: String
    let couleur_html: String
    let commune_nom: String
    let date_echeance: String
    let sous_indices: [Pollutant]
}

struct Pollutant: Codable {
    let polluant_nom: String
    let concentration: Double
    let indice: Int
}

struct District: Equatable {
    let id: String
    let name: String
    let codeInsee: String
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: District, rhs: District) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Données Lyon
struct Lyon {
    static let districts = [
        District(id: "69381", name: "Lyon 1er", codeInsee: "69381", coordinate: CLLocationCoordinate2D(latitude: 45.7676, longitude: 4.8351)),
        District(id: "69382", name: "Lyon 2e", codeInsee: "69382", coordinate: CLLocationCoordinate2D(latitude: 45.7537, longitude: 4.8320)),
        District(id: "69383", name: "Lyon 3e", codeInsee: "69383", coordinate: CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8435)),
        District(id: "69384", name: "Lyon 4e", codeInsee: "69384", coordinate: CLLocationCoordinate2D(latitude: 45.7751, longitude: 4.8287)),
        District(id: "69385", name: "Lyon 5e", codeInsee: "69385", coordinate: CLLocationCoordinate2D(latitude: 45.7630, longitude: 4.8156)),
        District(id: "69386", name: "Lyon 6e", codeInsee: "69386", coordinate: CLLocationCoordinate2D(latitude: 45.7692, longitude: 4.8502)),
        District(id: "69387", name: "Lyon 7e", codeInsee: "69387", coordinate: CLLocationCoordinate2D(latitude: 45.7343, longitude: 4.8418)),
        District(id: "69388", name: "Lyon 8e", codeInsee: "69388", coordinate: CLLocationCoordinate2D(latitude: 45.7378, longitude: 4.8707)),
        District(id: "69389", name: "Lyon 9e", codeInsee: "69389", coordinate: CLLocationCoordinate2D(latitude: 45.7797, longitude: 4.8060))
    ]
}

// MARK: - Service API corrigé
class AirQualityAPIService {
    private let apiToken = "0c7d0bee25f494150fa591275260e81f"
    private let baseURL = "https://api.atmo-aura.fr/api/v1/communes"
    
    func fetchAirQuality(for codeInsee: String) async throws -> AirQualityData {
        // Essai avec données actuelles en utilisant "now"
        if let data = try? await performRequest(codeInsee: codeInsee, useNow: true) {
            return data
        }
        
        // Fallback avec echeance=0 si "now" ne fonctionne pas
        if let data = try? await performRequest(codeInsee: codeInsee, useNow: false, withEcheance: true) {
            return data
        }
        
        // Dernier fallback sans paramètre
        return try await performRequest(codeInsee: codeInsee, useNow: false, withEcheance: false)
    }
    
    private func performRequest(codeInsee: String, useNow: Bool = false, withEcheance: Bool = false) async throws -> AirQualityData {
        var urlString = "\(baseURL)/\(codeInsee)/indices/atmo?api_token=\(apiToken)"
        
        if useNow {
            // Utilisation du paramètre "now" recommandé par l'API
            urlString += "&date_echeance=now"
        } else if withEcheance {
            // Fallback avec date de calcul aujourd'hui et echeance=0
            urlString += "&date_calcul=now&echeance=0"
        }
        // Sinon, pas de paramètre de date (récupère les dernières données disponibles)
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(AirQualityResponse.self, from: data)
        
        guard let firstData = apiResponse.data.first else {
            throw APIError.noData
        }
        
        return firstData
    }
}

enum APIError: Error {
    case invalidURL
    case serverError
    case noData
}

// MARK: - Gestionnaire de localisation
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Erreur de localisation: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - Vue principale avec carte RÉUTILISABLE
struct AirQualityMapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var selectedDistrict = Lyon.districts[0]
    @State private var airData: AirQualityData?
    @State private var isLoading = false
    @State private var showLocationSelector = false
    @State private var errorMessage: String?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        // Container principal avec hauteur fixe
        ZStack {
            // Carte Apple Maps en arrière-plan
            Map(coordinateRegion: $region, showsUserLocation: true, userTrackingMode: .constant(.none))
                .cornerRadius(20)
            
            // Overlay avec tous les composants
            VStack(spacing: 12) {
                // Sélecteur d'arrondissement en haut
                DistrictSelectorView(
                    selectedDistrict: $selectedDistrict,
                    showLocationSelector: $showLocationSelector,
                    userLocation: locationManager.userLocation
                )
                
                Spacer()
                
                // Données de qualité d'air en bas
                AirQualityDataView(
                    airData: airData,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    onRetry: { loadAirQuality() }
                )
            }
            .padding(16)
            
            // Menu de sélection par-dessus tout
            if showLocationSelector {
                LocationSelectorMenuView(
                    selectedDistrict: $selectedDistrict,
                    isPresented: $showLocationSelector,
                    onSelection: { loadAirQuality() }
                )
            }
        }
        .frame(height: 480) // Hauteur fixe équivalente à ~60% d'un écran iPhone standard
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
        .onAppear {
            locationManager.requestLocation()
            loadAirQuality()
        }
        .onChange(of: locationManager.userLocation) { location in
            if let location = location {
                updateSelectedDistrict(for: location)
                updateMapRegion(for: location)
            }
        }
        .onChange(of: selectedDistrict) { _ in
            loadAirQuality()
        }
    }
    
    private func loadAirQuality() {
        let apiService = AirQualityAPIService()
        
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let data = try await apiService.fetchAirQuality(for: selectedDistrict.codeInsee)
                await MainActor.run {
                    self.airData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Données indisponibles"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func updateSelectedDistrict(for location: CLLocation) {
        let nearestDistrict = Lyon.districts.min { district1, district2 in
            let location1 = CLLocation(latitude: district1.coordinate.latitude, longitude: district1.coordinate.longitude)
            let location2 = CLLocation(latitude: district2.coordinate.latitude, longitude: district2.coordinate.longitude)
            return location.distance(from: location1) < location.distance(from: location2)
        }
        
        if let nearest = nearestDistrict,
           location.distance(from: CLLocation(latitude: nearest.coordinate.latitude, longitude: nearest.coordinate.longitude)) < 5000 {
            selectedDistrict = nearest
        }
    }
    
    private func updateMapRegion(for location: CLLocation) {
        withAnimation(.easeInOut(duration: 1)) {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }
    }
}

// MARK: - Composant Sélecteur REDESIGNÉ
struct DistrictSelectorView: View {
    @Binding var selectedDistrict: District
    @Binding var showLocationSelector: Bool
    let userLocation: CLLocation?
    
    private var isNearSelectedDistrict: Bool {
        guard let userLocation = userLocation else { return false }
        let districtLocation = CLLocation(
            latitude: selectedDistrict.coordinate.latitude,
            longitude: selectedDistrict.coordinate.longitude
        )
        return userLocation.distance(from: districtLocation) < 5000
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showLocationSelector.toggle()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: isNearSelectedDistrict ? "location.fill" : "location")
                    .foregroundColor(isNearSelectedDistrict ? .green : .blue)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(selectedDistrict.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 14, weight: .bold))
                    .rotationEffect(.degrees(showLocationSelector ? 180 : 0))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showLocationSelector)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Composant Données REDESIGNÉ
struct AirQualityDataView: View {
    let airData: AirQualityData?
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    
    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let error = errorMessage {
                EmptyStateView(message: error, onRetry: onRetry)
            } else if let data = airData {
                AirQualityCompactView(airData: data)
            } else {
                EmptyStateView(message: "Aucune donnée", onRetry: onRetry)
            }
        }
    }
}

// MARK: - Vue compacte des données REDESIGNÉE
struct AirQualityCompactView: View {
    let airData: AirQualityData
    
    var body: some View {
        VStack(spacing: 14) {
            // Section principale avec jauge horizontale
            VStack(spacing: 12) {
                // Informations textuelles en haut
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(airData.qualificatif)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Qualité de l'air")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Indice numérique
                    Text("\(airData.indice)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Jauge horizontale colorée
                HStack(spacing: 2) {
                    ForEach(1...6, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(level <= airData.indice ? Color(hex: airData.couleur_html) : Color.white.opacity(0.3))
                            .frame(height: 8)
                            .animation(.easeInOut(duration: 0.3).delay(Double(level) * 0.1), value: airData.indice)
                    }
                }
                
                // Date
                HStack {
                    Spacer()
                    Text(formatDate(airData.date_echeance))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Grille des polluants sans chiffres
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(airData.sous_indices.prefix(4), id: \.polluant_nom) { pollutant in
                    CompactPollutantView(pollutant: pollutant)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Vue compacte des polluants REDESIGNÉE
struct CompactPollutantView: View {
    let pollutant: Pollutant
    
    var body: some View {
        Circle()
            .fill(getColor(from: pollutant.indice))
            .frame(width: 40, height: 40)
            .overlay(
                Text(getShortName(pollutant.polluant_nom))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private func getShortName(_ name: String) -> String {
        switch name.uppercased() {
        case "NO2": return "NO2"
        case "O3": return "O3"
        case "PM10": return "PM10"
        case "PM2.5": return "PM25"
        case "SO2": return "SO2"
        default: return String(name.prefix(3))
        }
    }
    
    private func getColor(from indice: Int) -> Color {
        switch indice {
        case 1: return Color(hex: "#50F0E6")
        case 2: return Color(hex: "#50CCAA")
        case 3: return Color(hex: "#F0E641")
        case 4: return Color(hex: "#FF5050")
        case 5: return Color(hex: "#960032")
        case 6: return Color(hex: "#872181")
        default: return Color.gray
        }
    }
}

// MARK: - Menu de sélection REDESIGNÉ
struct LocationSelectorMenuView: View {
    @Binding var selectedDistrict: District
    @Binding var isPresented: Bool
    let onSelection: () -> Void
    
    var body: some View {
        ZStack {
            // Fond semi-transparent
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            VStack {
                // Menu compact centré verticalement
                VStack(spacing: 0) {
                    // En-tête compact
                    HStack {
                        Text("Arrondissement")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("✕") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .background(.white.opacity(0.3))
                    
                    // Liste scrollable des arrondissements
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Lyon.districts, id: \.id) { district in
                                Button(action: {
                                    selectedDistrict = district
                                    onSelection()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isPresented = false
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 14))
                                        
                                        Text(district.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        if selectedDistrict.id == district.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if district.id != Lyon.districts.last?.id {
                                    Divider()
                                        .background(.white.opacity(0.2))
                                        .padding(.leading, 44)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .padding(.bottom, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

// MARK: - Vues d'état REDESIGNÉES
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Chargement...")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EmptyStateView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Button("Réessayer") {
                onRetry()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.white.opacity(0.2))
            )
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Extension Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Exemple d'utilisation dans une page d'accueil scrollable
struct HomePageView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // En-tête
                Text("Tableau de bord")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Composant qualité de l'air réutilisable
                AirQualityMapView()
                    .padding(.horizontal, 20)
                
                // Autres composants...
                DummyCard(title: "Météo", content: "25°C - Ensoleillé")
                DummyCard(title: "Trafic", content: "Normal")
                DummyCard(title: "Actualités", content: "Dernières nouvelles...")
                
                Spacer(minLength: 100)
            }
            .padding(.bottom, 20)
        }
    }
}

// Composant exemple pour démontrer l'utilisation
struct DummyCard: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

#Preview {
    AirQualityMapView()
}
