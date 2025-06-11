import SwiftUI
import MapKit
import Foundation

// MARK: - ToiletsMapView avec gestion clavier simple (layout original conservé)
struct ToiletsMapView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var toiletService = ToiletAPIService()
    @StateObject private var locationService = LocationService()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357),
        span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
    )
    @State private var searchText = ""
    @State private var addressSuggestions: [AddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?
    @State private var hasInitializedLocation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // ✅ Barre de recherche avec suggestions (LAYOUT ORIGINAL)
                VStack(spacing: 0) {
                    SmartSearchBarView(
                        searchText: $searchText,
                        suggestions: addressSuggestions,
                        showSuggestions: $showSuggestions,
                        onSearchTextChanged: handleSearchTextChange,
                        onSuggestionTapped: handleSuggestionTap,
                        onSearchSubmitted: handleSearchSubmit
                    )
                    
                    if showSuggestions && !addressSuggestions.isEmpty {
                        SuggestionsListView(
                            suggestions: addressSuggestions,
                            onSuggestionTapped: handleSuggestionTap
                        )
                    }
                }
                
                // ✅ Carte dans une box (LAYOUT ORIGINAL - 400px de hauteur)
                MapBoxView(
                    region: $region,
                    toilets: toiletService.toilets,
                    userLocation: locationService.userLocation,
                    searchedLocation: searchedLocation,
                    isLoading: toiletService.isLoading
                )
                
                // ✅ Statistiques en bas (LAYOUT ORIGINAL)
                if toiletService.isLoading && toiletService.toilets.isEmpty {
                    LoadingStatsView()
                } else {
                    ToiletStatsView(
                        count: toiletService.toilets.count,
                        userLocation: locationService.userLocation,
                        onLocationTap: centerOnUserLocation
                    )
                }
            }
            .padding() // ✅ Padding original restauré
            .navigationTitle("Toilettes Publiques")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Retour") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadToilets) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(toiletService.isLoading)
                }
            }
            .onAppear {
                setupInitialLocation()
                loadToilets()
            }
            .onChange(of: locationService.isLocationReady) { isReady in
                if isReady && !hasInitializedLocation {
                    initializeUserLocation()
                }
            }
            // ✅ SEULE MODIFICATION : Ignorer l'ajustement automatique du clavier
            .ignoresSafeArea(.keyboard, edges: .bottom)
            // Overlays globaux
            .overlay {
                if toiletService.isLoading && toiletService.toilets.isEmpty {
                    LoadingOverlayView()
                }
            }
            .overlay {
                if let errorMessage = toiletService.errorMessage {
                    ErrorOverlayView(message: errorMessage) {
                        loadToilets()
                    }
                    .background(Color(red: 248/255, green: 247/255, blue: 244/255))
                    .preferredColorScheme(.light)
                }
            }
        }
    }
    
    // MARK: - Functions (inchangées)
    
    private func setupInitialLocation() {
        print("🗺️ Initialisation de la carte des toilettes")
        locationService.requestLocationPermission()
        
        if locationService.isLocationReady {
            initializeUserLocation()
        }
    }
    
    private func initializeUserLocation() {
        guard !hasInitializedLocation else { return }
        hasInitializedLocation = true
        
        print("📍 Initialisation de la position utilisateur pour les toilettes")
        
        if locationService.isUserInLyon(), let userLocation = locationService.userLocation {
            print("✅ Utilisateur à Lyon, centrage sur sa position")
            centerMapOnLocation(userLocation)
        } else {
            print("⚠️ Utilisateur pas à Lyon ou position indisponible, garder Place Bellecour")
        }
    }
    
    private func loadToilets() {
        Task {
            await toiletService.loadToilets()
        }
    }
    
    private func handleSearchTextChange(_ text: String) {
        searchText = text
        
        if text.count >= 3 {
            showSuggestions = true
            Task {
                let allSuggestions = await locationService.searchAddresses(query: text)
                addressSuggestions = Array(allSuggestions.prefix(3))
            }
        } else {
            showSuggestions = false
            addressSuggestions = []
        }
    }
    
    private func handleSuggestionTap(_ suggestion: AddressSuggestion) {
        searchText = suggestion.title
        showSuggestions = false
        searchedLocation = suggestion.coordinate
        centerMapOnLocation(suggestion.coordinate)
    }
    
    private func handleSearchSubmit() {
        showSuggestions = false
        
        Task {
            if let coordinate = await locationService.geocodeAddress(searchText) {
                searchedLocation = coordinate
                centerMapOnLocation(coordinate)
            }
        }
    }
    
    private func centerOnUserLocation() {
        print("🎯 Demande de centrage sur utilisateur")
        
        if let userLocation = locationService.userLocation {
            print("✅ Position disponible, centrage immédiat")
            centerMapOnLocation(userLocation)
        } else {
            print("🔄 Pas de position, demande de localisation")
            locationService.getCurrentLocation()
            
            let startTime = Date()
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if let userLocation = locationService.userLocation {
                    timer.invalidate()
                    centerMapOnLocation(userLocation)
                    print("✅ Position reçue après \(Date().timeIntervalSince(startTime))s")
                } else if Date().timeIntervalSince(startTime) > 10 {
                    timer.invalidate()
                    print("⏰ Timeout: pas de position après 10s")
                }
            }
        }
    }
    
    private func centerMapOnLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
        }
    }
}

// MARK: - Composants UI (LAYOUT ORIGINAL restauré)

struct MapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let toilets: [ToiletLocation]
    let userLocation: CLLocationCoordinate2D?
    let searchedLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête de la box (ORIGINAL)
            HStack {
                Text("Carte des toilettes")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // ✅ Carte avec hauteur ORIGINALE fixe de 400px
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: mapAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if let toilet = annotation.toilet {
                        ToiletMarkerView(toilet: toilet)
                    } else if annotation.isSearchResult {
                        SearchPinMarker()
                    } else {
                        UserLocationMarker()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    region.span = MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
                }
            }
            .frame(height: 400) // ✅ HAUTEUR ORIGINALE RESTAURÉE
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var mapAnnotations: [MapAnnotationItem] {
        var annotations = toilets.map { toilet in
            MapAnnotationItem(toilet: toilet, coordinate: toilet.coordinate, isSearchResult: false)
        }
        
        if let userLocation = userLocation {
            annotations.append(MapAnnotationItem(toilet: nil, coordinate: userLocation, isSearchResult: false))
        }
        
        if let searchedLocation = searchedLocation {
            annotations.append(MapAnnotationItem(toilet: nil, coordinate: searchedLocation, isSearchResult: true))
        }
        
        return annotations
    }
}

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let toilet: ToiletLocation?
    let coordinate: CLLocationCoordinate2D
    let isSearchResult: Bool
}

struct SmartSearchBarView: View {
    @Binding var searchText: String
    let suggestions: [AddressSuggestion]
    @Binding var showSuggestions: Bool
    let onSearchTextChanged: (String) -> Void
    let onSuggestionTapped: (AddressSuggestion) -> Void
    let onSearchSubmitted: () -> Void
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Rechercher une adresse à Lyon...", text: $searchText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .onChange(of: searchText) { newValue in
                    onSearchTextChanged(newValue)
                }
                .onSubmit {
                    onSearchSubmitted()
                    isSearchFocused = false
                }
            
            if !searchText.isEmpty {
                Button("Annuler") {
                    searchText = ""
                    showSuggestions = false
                    isSearchFocused = false
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onChange(of: isSearchFocused) { focused in
            if !focused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showSuggestions = false
                }
            }
        }
    }
}

struct SuggestionsListView: View {
    let suggestions: [AddressSuggestion]
    let onSuggestionTapped: (AddressSuggestion) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button(action: {
                    onSuggestionTapped(suggestion)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .background(Color(.systemBackground))
                
                if suggestion.id != suggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ToiletStatsView: View {
    let count: Int
    let userLocation: CLLocationCoordinate2D?
    let onLocationTap: () -> Void
    
    var body: some View {
        HStack {
            Label("\(count) toilettes", systemImage: "drop.fill")
                .foregroundColor(.blue)
                .font(.headline)
            
            Spacer()
            
            Button(action: onLocationTap) {
                HStack {
                    Group {
                        if userLocation != nil {
                            Image(systemName: "location.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "location.slash")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Text(userLocation != nil ? "Ma position" : "Localiser")
                        .font(.caption)
                }
                .foregroundColor(userLocation != nil ? .green : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct LoadingStatsView: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Chargement des toilettes...")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct LoadingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                Text("Chargement des toilettes...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 8)
        }
    }
}

struct ErrorOverlayView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                
                Text("Erreur")
                    .font(.headline)
                
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                
                Button("Réessayer") {
                    onRetry()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 8)
        }
    }
}

struct ToiletMarkerView: View {
    let toilet: ToiletLocation
    @State private var showNavigationAlert = false
    
    var body: some View {
        Button(action: {
            showNavigationAlert = true
        }) {
            ZStack {
                Circle()
                    .fill(toilet.isOpen ? Color.blue : Color.gray)
                    .frame(width: 30, height: 30)
                    .shadow(radius: 3)
                
                Text("🚽")
                    .font(.caption)
                
                if toilet.isAccessible {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                if !toilet.isOpen {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 34, height: 34)
                }
            }
        }
        .alert("Navigation", isPresented: $showNavigationAlert) {
            Button("Ouvrir dans Plans") {
                openInMaps()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers \(toilet.name) ?")
        }
    }
    
    private func openInMaps() {
        let coordinate = toilet.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = toilet.name
        mapItem.phoneNumber = nil
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation lancée vers: \(toilet.name) (\(coordinate.latitude), \(coordinate.longitude))")
    }
}

struct SearchPinMarker: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 30, height: 30)
                    .shadow(radius: 3)
                
                Image(systemName: "location.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }
            
            Rectangle()
                .fill(Color.red)
                .frame(width: 3, height: 10)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 3, y: 5))
                path.addLine(to: CGPoint(x: -3, y: 5))
                path.closeSubpath()
            }
            .fill(Color.red)
            .frame(width: 6, height: 5)
        }
        .scaleEffect(1.2)
    }
}

struct UserLocationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 40, height: 40)
            
            Circle()
                .fill(Color.blue)
                .frame(width: 20, height: 20)
            
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Service API et modèles (inchangés)

@MainActor
class ToiletAPIService: ObservableObject {
    @Published var toilets: [ToiletLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrtoilettepublique_latest&SRSNAME=EPSG:4171&outputFormat=application/json&startIndex=0&sortby=gid"
    
    func loadToilets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let url = URL(string: apiURL) else {
                throw ToiletAPIError.invalidURL
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ToiletAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw ToiletAPIError.httpError(httpResponse.statusCode)
            }
            
            let geoJsonResponse = try JSONDecoder().decode(ToiletGeoJSONResponse.self, from: data)
            
            let toiletLocations = geoJsonResponse.features.compactMap { feature -> ToiletLocation? in
                guard feature.geometry.coordinates.count >= 2 else { return nil }
                
                let longitude = feature.geometry.coordinates[0]
                let latitude = feature.geometry.coordinates[1]
                let props = feature.properties
                
                return ToiletLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    name: props.nom ?? "Toilette publique",
                    address: formatAddress(props),
                    gestionnaire: props.gestionnaire ?? "Non spécifié",
                    isAccessible: props.acces_pmr == "Oui",
                    isOpen: determineOpenStatus(props),
                    horaires: props.horaires
                )
            }
            
            toilets = toiletLocations
            isLoading = false
            
        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func formatAddress(_ props: ToiletProperties) -> String {
        var addressParts: [String] = []
        
        if let adresse = props.adresse {
            addressParts.append(adresse)
        }
        
        if let codePostal = props.code_postal {
            addressParts.append(codePostal)
        }
        
        if let commune = props.commune {
            addressParts.append(commune)
        }
        
        return addressParts.isEmpty ? "Adresse non disponible" : addressParts.joined(separator: ", ")
    }
    
    private func determineOpenStatus(_ props: ToiletProperties) -> Bool {
        return true
    }
}

struct ToiletLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
    let address: String
    let gestionnaire: String
    let isAccessible: Bool
    let isOpen: Bool
    let horaires: String?
}

struct ToiletGeoJSONResponse: Codable {
    let type: String
    let features: [ToiletFeature]
    let totalFeatures: Int?
}

struct ToiletFeature: Codable {
    let type: String
    let geometry: ToiletGeometry
    let properties: ToiletProperties
}

struct ToiletGeometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct ToiletProperties: Codable {
    let gid: Int?
    let nom: String?
    let adresse: String?
    let code_postal: String?
    let commune: String?
    let gestionnaire: String?
    let acces_pmr: String?
    let horaires: String?
}

enum ToiletAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Réponse serveur invalide"
        case .httpError(let code):
            return "Erreur HTTP \(code)"
        }
    }
}

#Preview {
    ToiletsMapView()
}
