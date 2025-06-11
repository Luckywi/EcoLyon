import SwiftUI
import MapKit
import CoreLocation

// MARK: - Import des vues de détail
// Assurez-vous d'avoir créé le fichier PM25DetailView.swift

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

// MARK: - Service API optimisé
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
            urlString += "&date_echeance=now"
        } else if withEcheance {
            urlString += "&date_calcul=now&echeance=0"
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
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

// MARK: - ✅ COMPOSANT PRINCIPAL OPTIMISÉ
struct AirQualityMapView: View {
    @StateObject private var locationService = GlobalLocationService.shared
    @State private var airData: AirQualityData?
    @State private var isLoadingAirData = false
    @State private var showLocationSelector = false
    @State private var errorMessage: String?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        ZStack {
            if let district = locationService.detectedDistrict {
                // ✅ Interface principale IMMÉDIATE
                mainContentView(district: district)
            } else {
                // ✅ Chargement minimal (rare grâce au GlobalLocationService optimisé)
                quickLoadingView
            }
        }
        .frame(height: 480)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
        .onAppear {
            // ✅ Redémarrer la localisation si nécessaire
            locationService.refreshLocation()
            
            // ✅ Chargement immédiat des données air si district disponible
            if let district = locationService.detectedDistrict {
                loadAirQualityData(for: district)
                updateMapRegion(for: district.coordinate)
            }
        }
        .onDisappear {
            // ✅ Arrêter les mises à jour quand la vue n'est plus visible
            locationService.stopLocationUpdates()
        }
        .onChange(of: locationService.detectedDistrict) { district in
            if let district = district {
                loadAirQualityData(for: district)
                updateMapRegion(for: district.coordinate)
            }
        }
    }
    
    // Interface principale
    private func mainContentView(district: District) -> some View {
        ZStack {
            Map(coordinateRegion: $region, showsUserLocation: true)
                .cornerRadius(20)
            
            VStack(spacing: 12) {
                // Sélecteur d'arrondissement
                DistrictSelectorView(
                    selectedDistrict: Binding(
                        get: { district },
                        set: { newDistrict in
                            locationService.setDistrict(newDistrict)
                        }
                    ),
                    showLocationSelector: $showLocationSelector,
                    userLocation: locationService.userLocation.map {
                        CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                    }
                )
                
                Spacer()
                
                // Données de qualité d'air
                AirQualityDataView(
                    airData: airData,
                    isLoading: isLoadingAirData,
                    errorMessage: errorMessage,
                    selectedDistrict: district,
                    onRetry: {
                        if let district = locationService.detectedDistrict {
                            loadAirQualityData(for: district)
                        }
                    }
                )
            }
            .padding(16)
            
            // Menu de sélection
            if showLocationSelector {
                LocationSelectorMenuView(
                    selectedDistrict: Binding(
                        get: { district },
                        set: { newDistrict in
                            locationService.setDistrict(newDistrict)
                        }
                    ),
                    isPresented: $showLocationSelector,
                    onSelection: {
                        if let newDistrict = locationService.detectedDistrict {
                            loadAirQualityData(for: newDistrict)
                        }
                    }
                )
            }
        }
    }
    
    private var quickLoadingView: some View {
        ZStack {
            Map(coordinateRegion: $region, showsUserLocation: true)
                .cornerRadius(20)
                .opacity(0.4)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.blue)
                
                Text("Finalisation...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.8))
            )
        }
    }
    
    // MARK: - Fonctions optimisées
    
    private func loadAirQualityData(for district: District) {
        let apiService = AirQualityAPIService()
        
        Task {
            await MainActor.run {
                isLoadingAirData = true
                errorMessage = nil
            }
            
            do {
                let data = try await apiService.fetchAirQuality(for: district.codeInsee)
                await MainActor.run {
                    self.airData = data
                    self.isLoadingAirData = false
                }
                print("✅ Données air chargées pour \(district.name)")
                
                // ✅ Notifier l'AQI pour les recommandations
                NotificationCenter.default.post(
                    name: NSNotification.Name("AQIUpdated"),
                    object: data.indice
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = "Données indisponibles"
                    self.isLoadingAirData = false
                }
                print("❌ Erreur données air: \(error)")
            }
        }
    }
    
    private func updateMapRegion(for coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }
    }
}

// MARK: - Composant Sélecteur
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

// MARK: - Composant Données
struct AirQualityDataView: View {
    let airData: AirQualityData?
    let isLoading: Bool
    let errorMessage: String?
    let selectedDistrict: District
    let onRetry: () -> Void
    
    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let error = errorMessage {
                EmptyStateView(message: error, onRetry: onRetry)
            } else if let data = airData {
                AirQualityCompactView(airData: data, selectedDistrict: selectedDistrict)
            } else {
                EmptyStateView(message: "Aucune donnée", onRetry: onRetry)
            }
        }
    }
}

// MARK: - Vue compacte des données (MODIFIÉE)
struct AirQualityCompactView: View {
    let airData: AirQualityData
    let selectedDistrict: District
    
    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
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
                    
                    Text("\(airData.indice)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 2) {
                    ForEach(1...6, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(level <= airData.indice ? Color(hex: airData.couleur_html) : Color.white.opacity(0.3))
                            .frame(height: 8)
                            .animation(.easeInOut(duration: 0.3).delay(Double(level) * 0.1), value: airData.indice)
                    }
                }
                
                HStack {
                    Spacer()
                    Text(formatDate(airData.date_echeance))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // ✅ CHANGEMENT ICI : Passer selectedDistrict
            LazyVGrid(columns: createAdaptiveColumns(for: airData.sous_indices.count), spacing: 6) {
                ForEach(airData.sous_indices, id: \.polluant_nom) { pollutant in
                    CompactPollutantView(pollutant: pollutant, selectedDistrict: selectedDistrict)
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
    
    // ✅ NOUVELLE FONCTION : Créer une grille adaptative
    private func createAdaptiveColumns(for count: Int) -> [GridItem] {
        if count <= 4 {
            // Pour 4 polluants ou moins : 4 colonnes
            return Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        } else {
            // Pour 5 polluants : 5 colonnes avec espacement réduit
            return Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)
        }
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

// MARK: - Vue compacte des polluants (MODIFIÉE POUR NAVIGATION)
struct CompactPollutantView: View {
    let pollutant: Pollutant
    let selectedDistrict: District
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            Circle()
                .fill(getColor(from: pollutant.indice))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(getShortName(pollutant.polluant_nom))
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(showingDetail ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: showingDetail)
        .sheet(isPresented: $showingDetail) {
            getPollutantDetailView()
        }
    }
    
    // ✅ ROUTER VERS LES VUES SPÉCIFIQUES
    @ViewBuilder
    private func getPollutantDetailView() -> some View {
        switch pollutant.polluant_nom.uppercased() {
        case "PM2.5":
            PM25DetailView(pollutant: pollutant, selectedDistrict: selectedDistrict)
        case "PM10":
            PM10DetailView(pollutant: pollutant, selectedDistrict: selectedDistrict)
        case "NO2":
            NO2DetailView(pollutant: pollutant, selectedDistrict: selectedDistrict)
        case "O3":
            O3DetailView(pollutant: pollutant, selectedDistrict: selectedDistrict)
        case "SO2":
            SO2DetailView(pollutant: pollutant, selectedDistrict: selectedDistrict)
        default:
            Text("Détails non disponibles pour \(pollutant.polluant_nom)")
                .padding()
        }
    }
    
    private func getShortName(_ name: String) -> String {
        switch name.uppercased() {
        case "NO2": return "NO2"
        case "O3": return "O3"
        case "PM10": return "PM10"
        case "PM2.5": return "PM2.5"  // ✅ Gardé avec le point
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

// MARK: - Menu de sélection
struct LocationSelectorMenuView: View {
    @Binding var selectedDistrict: District
    @Binding var isPresented: Bool
    let onSelection: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            VStack {
                VStack(spacing: 0) {
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

// MARK: - Vues d'état
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

#Preview {
    AirQualityMapView()
}
