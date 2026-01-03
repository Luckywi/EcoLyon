import SwiftUI
import Foundation
import MapKit

// MARK: - Modèles de données Air Quality
struct AirQuality: Codable {
    let type: String
    let features: [AirQualityFeature]
    let totalFeatures: Int
    let numberMatched: Int
    let numberReturned: Int
    let timeStamp: String
}

struct AirQualityFeature: Codable {
    let type: String
    let id: String
    let geometry: Geometry
    let properties: AirQualityProperties
}

struct Geometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct AirQualityProperties: Codable {
    let dateMaj: String
    let codeNo2: Int
    let codeO3: Int
    let codePm10: Int
    let codePm25: Int
    let codeQual: Int
    let codeSo2: Int
    let codeZone: String
    let coulQual: String
    let dateEch: String
    let epsgReg: String
    let libQual: String
    let libZone: String
    let source: String
    let typeZone: String
    let xReg: Double
    let xWgs84: Double
    let yReg: Double
    let yWgs84: Double
    let dateDif: String
    
    enum CodingKeys: String, CodingKey {
        case dateMaj = "date_maj"
        case codeNo2 = "code_no2"
        case codeO3 = "code_o3"
        case codePm10 = "code_pm10"
        case codePm25 = "code_pm25"
        case codeQual = "code_qual"
        case codeSo2 = "code_so2"
        case codeZone = "code_zone"
        case coulQual = "coul_qual"
        case dateEch = "date_ech"
        case epsgReg = "epsg_reg"
        case libQual = "lib_qual"
        case libZone = "lib_zone"
        case source
        case typeZone = "type_zone"
        case xReg = "x_reg"
        case xWgs84 = "x_wgs84"
        case yReg = "y_reg"
        case yWgs84 = "y_wgs84"
        case dateDif = "date_dif"
    }
}

// MARK: - Modèles de données Commentaires
struct CommentaireResponse: Codable {
    let data: [CommentaireData]
    let success: Bool
    let message: CommentaireMessage?
}

struct CommentaireData: Codable {
    let echeance: Int
    let date_echeance: String
    let date_calcul: String
    let commentaire: String
    let date_maj: String
}

struct CommentaireMessage: Codable {
    let code: Int
    let text: String
}

// MARK: - MapKit Extensions
struct AirQualityAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let feature: AirQualityFeature
}

extension AirQualityFeature {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: properties.yWgs84,
            longitude: properties.xWgs84
        )
    }
    
    // Couleurs harmonisées
    var qualityColor: Color {
        switch properties.codeQual {
        case 1: return Color(hex: "#50F0E6") // Bon
        case 2: return Color(hex: "#50CCAA") // Moyen
        case 3: return Color(hex: "#F0E641") // Dégradé
        case 4: return Color(hex: "#FF5050") // Mauvais
        case 5: return Color(hex: "#960032") // Très mauvais
        case 6: return Color(hex: "#872181") // Extrêmement mauvais
        default: return Color.gray
        }
    }
}


// MARK: - Service API Commentaires
class CommentaireAPIService {
    private let apiToken = Bundle.main.object(forInfoDictionaryKey: "ATMO_API_TOKEN") as? String ?? ""
    private let baseURL = "https://api.atmo-aura.fr/api/v1/commentaires"
    
    func fetchCommentaire(for date: Date) async throws -> CommentaireData {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let urlString = "\(baseURL)?date_echeance=\(dateString)&api_token=\(apiToken)"
        
        guard let url = URL(string: urlString) else {
            throw CommentaireError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CommentaireError.serverError
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(CommentaireResponse.self, from: data)
        
        guard let firstData = apiResponse.data.first else {
            throw CommentaireError.noData
        }
        
        return firstData
    }
}

enum CommentaireError: Error {
    case invalidURL
    case serverError
    case noData
}

// MARK: - ViewModel Air Quality
@MainActor
class AirQualityViewModel: ObservableObject {
    @Published var airQualityData: [AirQualityFeature] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFeature: AirQualityFeature?
    @Published var showingDetail = false
    
    private let baseURL = "https://data.atmo-france.org/geoserver/ind/wfs"
    
    // Liste des villes à récupérer - facilement modifiable
    private let cities = ["Lyon", "Paris", "Marseille", "Lille", "Arras", "Amiens", "Reims", "Nancy", "Metz", "Strasbourg", "Rouen", "Caen",
    "Brest", "Rennes", "Le Mans", "Angers", "Nantes", "Chartres", "Orléans",
    "Tours", "Bourges", "Sens", "Nevers", "Dijon", "Montbéliard", "Besançon",
    "Chalon-sur-Saône", "Toulouse", "Nice", "Bordeaux", "Montpellier", "Poitier", "Limoges", "Clermont-Ferrand", "Saint-Étienne", "Grenoble", "Bayonne", "Tarbes", "Carcassonne", "Perpignan", "Avignon", "Toulon", "Rodez"]
    
    // Région optimisée pour la France métropolitaine uniquement
    let franceRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.5, longitude: 2.0),
        span: MKCoordinateSpan(latitudeDelta: 11.0, longitudeDelta: 11.0)
    )
    
    func fetchAirQualityData(for date: Date = Date()) {
        isLoading = true
        errorMessage = nil
        
        // Utiliser la date fournie au lieu d'aujourd'hui automatiquement
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Construire le filtre CQL pour toutes les villes
        let cityFilter = cities.map { "lib_zone='\($0)'" }.joined(separator: " OR ")
        let fullFilter = "date_ech='\(dateString)' AND (\(cityFilter))"
        
        // Construire l'URL avec le filtre groupé
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeName", value: "ind:ind_atmo"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "CQL_FILTER", value: fullFilter),
            URLQueryItem(name: "count", value: "50") // Limite raisonnable pour toutes les villes
        ]
        
        guard let url = components.url else {
            errorMessage = "URL invalide"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Erreur réseau: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "Aucune donnée reçue"
                    return
                }
                
                do {
                    let airQuality = try JSONDecoder().decode(AirQuality.self, from: data)
                    self?.airQualityData = airQuality.features
                    
                    // Log des villes récupérées
                    let citiesFound = Set(airQuality.features.compactMap { $0.properties.libZone })
                    print("✅ Données chargées: \(airQuality.features.count) points")
                    print("🏙️ Villes trouvées: \(citiesFound.sorted().joined(separator: ", "))")
                    
                    // Avertissement si certaines villes manquent
                    let citiesRequested = Set(self?.cities ?? [])
                    let missingCities = citiesRequested.subtracting(citiesFound)
                    if !missingCities.isEmpty {
                        print("⚠️ Villes sans données aujourd'hui: \(missingCities.sorted().joined(separator: ", "))")
                    }
                    
                } catch {
                    self?.errorMessage = "Erreur de décodage: \(error.localizedDescription)"
                    print("❌ Erreur décodage: \(error)")
                }
            }
        }.resume()
    }
    
    // Fonction pour récupérer seulement certaines villes
    func fetchAirQualityDataForCities(_ selectedCities: [String], for date: Date = Date()) {
        isLoading = true
        errorMessage = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let cityFilter = selectedCities.map { "lib_zone='\($0)'" }.joined(separator: " OR ")
        let fullFilter = "date_ech='\(dateString)' AND (\(cityFilter))"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeName", value: "ind:ind_atmo"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "CQL_FILTER", value: fullFilter),
            URLQueryItem(name: "count", value: "50")
        ]
        
        guard let url = components.url else {
            errorMessage = "URL invalide"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Erreur réseau: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "Aucune donnée reçue"
                    return
                }
                
                do {
                    let airQuality = try JSONDecoder().decode(AirQuality.self, from: data)
                    self?.airQualityData = airQuality.features
                    
                    let citiesFound = Set(airQuality.features.compactMap { $0.properties.libZone })
                    print("✅ Données chargées pour \(selectedCities.joined(separator: ", ")): \(airQuality.features.count) points")
                    print("🏙️ Villes trouvées: \(citiesFound.sorted().joined(separator: ", "))")
                    
                } catch {
                    self?.errorMessage = "Erreur de décodage: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
// MARK: - Vue principale intégrée
struct AtmoMapView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var airQualityViewModel = AirQualityViewModel()
    
    // ✅ Position caméra iOS 17+
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.5, longitude: 2.0),
        span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 7.0)
    ))

    // Limites géographiques pour la France
    private let franceCenter = CLLocationCoordinate2D(latitude: 46.5, longitude: 2.0)
    private let maxDistance: CLLocationDistance = 600_000 // 800km du centre
    
    // États pour les commentaires
    @State private var currentDate = Date()
    @State private var commentaireData: CommentaireData?
    @State private var isLoadingCommentaire = false
    @State private var commentaireErrorMessage: String?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE dd MMMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }
    
    private var canNavigateBackward: Bool {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return currentDate > yesterday
    }
    
    private var canNavigateForward: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let currentDay = Calendar.current.startOfDay(for: currentDate)
        return currentDay < tomorrow
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Navigation de dates
                    dateNavigationSection
                    
                    // Contenu du commentaire
                    if isLoadingCommentaire {
                        loadingCommentaireSection
                    } else if let error = commentaireErrorMessage {
                        errorCommentaireSection(error)
                    } else if let data = commentaireData {
                        commentaireSection(data)
                    } else {
                        emptyCommentaireSection
                    }
                    
                    // Section carte
                    mapSection
                    
                    // Source des données
                    dataSourceSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("Rapport détaillé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .onAppear {
            airQualityViewModel.fetchAirQualityData(for: currentDate)
            loadCommentaire()
        }
        .overlay(
            // Popup contextuel pour les détails de qualité d'air
            Group {
                if airQualityViewModel.showingDetail, let feature = airQualityViewModel.selectedFeature {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            airQualityViewModel.showingDetail = false
                            airQualityViewModel.selectedFeature = nil
                        }
                    
                    AirQualityPopup(feature: feature, currentDate: currentDate) {
                        airQualityViewModel.showingDetail = false
                        airQualityViewModel.selectedFeature = nil
                    }
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: airQualityViewModel.showingDetail)
                }
            }
        )
    }
    
    // MARK: - Navigation des dates
    private var dateNavigationSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button(action: navigateBackward) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(canNavigateBackward ? .black : .gray.opacity(0.5))
                }
                .disabled(!canNavigateBackward)
                
                VStack(spacing: 4) {
                    Text(dateFormatter.string(from: currentDate).capitalized)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    
                    if Calendar.current.isDateInToday(currentDate) {
                        Text("Aujourd'hui")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    } else if Calendar.current.isDateInYesterday(currentDate) {
                        Text("Hier")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    } else if Calendar.current.isDateInTomorrow(currentDate) {
                        Text("Demain")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Button(action: navigateForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(canNavigateForward ? .black : .gray.opacity(0.5))
                }
                .disabled(!canNavigateForward)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }
    
    // MARK: - Section carte
    private var mapSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Vue d'ensemble France")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
            }
            
            ZStack {
                // ✅ Map iOS 17+
                Map(position: $cameraPosition, interactionModes: [.pan]) {
                    ForEach(airQualityViewModel.airQualityData.map { feature in
                        AirQualityAnnotation(coordinate: feature.coordinate, feature: feature)
                    }) { annotation in
                        Annotation("", coordinate: annotation.coordinate) {
                            Circle()
                                .fill(annotation.feature.qualityColor)
                                .frame(width: 18, height: 18)
                                .scaleEffect(airQualityViewModel.selectedFeature?.id == annotation.feature.id ? 1.3 : 1.0)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .padding(13)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { _ in
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()

                                            airQualityViewModel.selectedFeature = annotation.feature
                                            airQualityViewModel.showingDetail = true
                                        }
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: airQualityViewModel.selectedFeature?.id)
                        }
                    }
                }
                .frame(height: 300)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onMapCameraChange { context in
                    // Calculer la distance du centre de la France
                    let currentLocation = CLLocation(latitude: context.region.center.latitude, longitude: context.region.center.longitude)
                    let franceLocation = CLLocation(latitude: franceCenter.latitude, longitude: franceCenter.longitude)
                    let distance = franceLocation.distance(from: currentLocation)

                    // Si on dépasse la limite
                    if distance > maxDistance {
                        // Calculer le point le plus proche sur le cercle de limite
                        let bearing = atan2(
                            context.region.center.longitude - franceCenter.longitude,
                            context.region.center.latitude - franceCenter.latitude
                        )

                        // Coordonnées du point limite
                        let earthRadius = 6_371_000.0
                        let deltaLat = (maxDistance * cos(bearing)) / earthRadius * (180.0 / .pi)
                        let deltaLon = (maxDistance * sin(bearing)) / (earthRadius * cos(franceCenter.latitude * .pi / 180.0)) * (180.0 / .pi)

                        let limitedCenter = CLLocationCoordinate2D(
                            latitude: franceCenter.latitude + deltaLat,
                            longitude: franceCenter.longitude + deltaLon
                        )

                        // Mise à jour douce sans animation pour éviter les conflits
                        DispatchQueue.main.async {
                            cameraPosition = .region(MKCoordinateRegion(
                                center: limitedCenter,
                                span: context.region.span
                            ))
                        }
                    }
                }
                .onAppear {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 46.5, longitude: 2.0),
                        span: MKCoordinateSpan(latitudeDelta: 6.5, longitudeDelta: 8.5)
                    ))
                }
                .onTapGesture {
                    if airQualityViewModel.showingDetail {
                        airQualityViewModel.showingDetail = false
                        airQualityViewModel.selectedFeature = nil
                    }
                }
                
                // Overlay de chargement pour la carte
                if airQualityViewModel.isLoading {
                    Color.black.opacity(0.3)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Chargement des données...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
                
                // Overlay d'erreur pour la carte
                if let errorMessage = airQualityViewModel.errorMessage {
                    Color.black.opacity(0.3)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        
                        Text("Erreur")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Réessayer") {
                            airQualityViewModel.fetchAirQualityData(for: currentDate)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Section du commentaire
    private func commentaireSection(_ data: CommentaireData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Commentaire région lyonnaise")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Text(data.commentaire)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black.opacity(0.8))
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
            
            HStack {
                Text("Mis à jour le \(formatUpdateDate(data.date_maj))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Section de chargement commentaire
    private var loadingCommentaireSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            Text("Chargement du rapport...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Section d'erreur commentaire
    private func errorCommentaireSection(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Données indisponibles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Text(error)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Réessayer") {
                loadCommentaire()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.blue)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Section vide commentaire
    private var emptyCommentaireSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("Aucun commentaire disponible")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Section source des données
    private var dataSourceSection: some View {
        VStack(spacing: 8) {
            Text("Les commentaires quotidiens sont rédigés par ATMO Auvergne-Rhône-Alpes. Les données des villes françaises proviennent d'ATMO France, plateforme nationale des organismes agréés de surveillance de la qualité de l'air.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.black.opacity(0.6))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
            
            Link("atmo-france.org", destination: URL(string: "https://www.atmo-france.org")!)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    // MARK: - Fonctions de navigation
    private func navigateBackward() {
        guard canNavigateBackward else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        loadCommentaire()
        airQualityViewModel.fetchAirQualityData(for: currentDate)
    }
    
    private func navigateForward() {
        guard canNavigateForward else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        loadCommentaire()
        airQualityViewModel.fetchAirQualityData(for: currentDate)
    }
    
    // MARK: - Chargement des données commentaire
    private func loadCommentaire() {
        let apiService = CommentaireAPIService()
        
        Task {
            await MainActor.run {
                isLoadingCommentaire = true
                commentaireErrorMessage = nil
                commentaireData = nil
            }
            
            do {
                let data = try await apiService.fetchCommentaire(for: currentDate)
                await MainActor.run {
                    self.commentaireData = data
                    self.isLoadingCommentaire = false
                }
                print("✅ Commentaire chargé pour \(currentDate)")
            } catch {
                await MainActor.run {
                    self.commentaireErrorMessage = "Impossible de charger le commentaire pour cette date"
                    self.isLoadingCommentaire = false
                }
                print("❌ Erreur commentaire: \(error)")
            }
        }
    }
    
    // MARK: - Formatage de date
    private func formatUpdateDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        inputFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd/MM/yyyy à HH:mm"
        outputFormatter.locale = Locale(identifier: "fr_FR")
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Popup harmonisé et épuré
struct AirQualityPopup: View {
    let feature: AirQualityFeature
    let currentDate: Date
    let onClose: () -> Void
    
    private var datePrefix: String {
        if Calendar.current.isDateInToday(currentDate) {
            return "Aujourd'hui à"
        } else if Calendar.current.isDateInYesterday(currentDate) {
            return "Hier à"
        } else if Calendar.current.isDateInTomorrow(currentDate) {
            return "Demain à"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            formatter.locale = Locale(identifier: "fr_FR")
            return "Le \(formatter.string(from: currentDate)) à"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header avec bouton fermer
            HStack {
                Button("Fermer") {
                    onClose()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                
                Spacer()
                
                Text("Détail")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text("")
                    .frame(width: 50)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Section 1: Ville et indice général
            VStack(spacing: 16) {
                Text("\(datePrefix) \(feature.properties.libZone)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                
                // Barre de jauge avec indice
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(getQualityText(from: feature.properties.codeQual))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Qualité de l'air")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Text("\(feature.properties.codeQual)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }
                    
                    // Barre de progression
                    HStack(spacing: 2) {
                        ForEach(1...6, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(level <= feature.properties.codeQual ? feature.qualityColor : Color.gray.opacity(0.3))
                                .frame(height: 8)
                                .animation(.easeInOut(duration: 0.3).delay(Double(level) * 0.1), value: feature.properties.codeQual)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal, 20)
            
            // Section 2: Pastilles
            VStack(spacing: 16) {
                Text("Détail par polluant")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                HStack(spacing: 12) {
                    CompactPollutantCircle(name: "PM2.5", code: feature.properties.codePm25)
                    CompactPollutantCircle(name: "PM10", code: feature.properties.codePm10)
                    CompactPollutantCircle(name: "NO2", code: feature.properties.codeNo2)
                    CompactPollutantCircle(name: "O3", code: feature.properties.codeO3)
                    CompactPollutantCircle(name: "SO2", code: feature.properties.codeSo2)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal, 20)
            
            // Section 3: Source des données (identique au design principal)
            VStack(spacing: 8) {
                Text("Les données de qualité d'air de la ville de \(feature.properties.libZone) ont été mises à jour pour la dernière fois le \(formatLastUpdateDate(feature.properties.dateMaj)) par \(feature.properties.source), organisme agréé pour la surveillance de qualité d'air dans la région.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.black.opacity(0.6))
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                
                Link("atmo-france.org", destination: URL(string: "https://www.atmo-france.org")!)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(width: 350, height: 520) // Hauteur augmentée pour la nouvelle section
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    }
    
    // Fonctions harmonisées
    private func getQualityText(from indice: Int) -> String {
        switch indice {
        case 1: return "Bon"
        case 2: return "Moyen"
        case 3: return "Dégradé"
        case 4: return "Mauvais"
        case 5: return "Très mauvais"
        case 6: return "Extrêmement mauvais"
        default: return "Inconnu"
        }
    }
    
    private func getScaleColor(level: Int) -> Color {
        switch level {
        case 1: return Color(hex: "#50F0E6")
        case 2: return Color(hex: "#50CCAA")
        case 3: return Color(hex: "#F0E641")
        case 4: return Color(hex: "#FF5050")
        case 5: return Color(hex: "#960032")
        case 6: return Color(hex: "#872181")
        default: return Color.gray
        }
    }
    
    // Formatage de la date de dernière mise à jour
    private func formatLastUpdateDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        inputFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd/MM/yyyy à HH:mm"
        outputFormatter.locale = Locale(identifier: "fr_FR")
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        // Fallback pour d'autres formats possibles
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        fallbackFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = fallbackFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Pastille compacte comme AirQualityDisplay
struct CompactPollutantCircle: View {
    let name: String
    let code: Int
    
    var body: some View {
        Circle()
            .fill(pollutantColor)
            .frame(width: 46, height: 46)
            .overlay(
                Text(name)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            )
    }
    
    private var pollutantColor: Color {
        switch code {
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

// MARK: - Preview
#Preview {
    AtmoMapView()
}
