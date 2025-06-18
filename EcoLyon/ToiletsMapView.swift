import SwiftUI
import MapKit
import Foundation

// MARK: - ToiletsMapView avec structure identique à ContentView
struct ToiletsMapView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var toiletService = ToiletAPIService()
    @StateObject private var locationService = GlobalLocationService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    
    
    // ✅ Region initialisée avec position utilisateur si disponible
    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var addressSuggestions: [AddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?

    
    // ✅ COULEUR UNIFIÉE
    private let toiletThemeColor = Color(red: 0.7, green: 0.7, blue: 0.7)
    
    // ✅ Computed property pour les 3 toilettes les plus proches
    private var nearestToilets: [ToiletLocation] {
        guard let userLocation = locationService.userLocation else { return [] }
        
        return toiletService.toilets
            .map { toilet in
                let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    .distance(from: CLLocation(latitude: toilet.coordinate.latitude, longitude: toilet.coordinate.longitude))
                return (toilet: toilet, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(3)
            .map { $0.toilet }
    }
    
    // ✅ Initializer personnalisé
    init() {
        let initialCenter: CLLocationCoordinate2D
        if let userLocation = GlobalLocationService.shared.userLocation {
            initialCenter = userLocation
            print("🎯 Toilettes: Initialisation avec position utilisateur")
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
            print("🏛️ Toilettes: Initialisation avec Bellecour (fallback)")
        }
        
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
        ))
    }
    
    var body: some View {
        // ✅ STRUCTURE IDENTIQUE À CONTENTVIEW
        ZStack {
            // ✅ Contenu principal dans ScrollView
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ✅ TITRE FIXE EN HAUT
                    HStack(spacing: 12) {
                        Image("Wc")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(toiletThemeColor)
                        
                        Text("Toilettes Publiques")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // ✅ Barre de recherche
                    VStack(spacing: 0) {
                        SmartSearchBarView(
                            searchText: $searchText,
                            suggestions: addressSuggestions,
                            showSuggestions: $showSuggestions,
                            onSearchTextChanged: handleSearchTextChange,
                            onSuggestionTapped: handleSuggestionTap,
                            onSearchSubmitted: handleSearchSubmitted,
                            themeColor: toiletThemeColor
                        )
                        
                        if showSuggestions && !addressSuggestions.isEmpty {
                            SuggestionsListView(
                                suggestions: addressSuggestions,
                                onSuggestionTapped: handleSuggestionTap
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Carte
                    MapBoxView(
                        region: $region,
                        toilets: toiletService.toilets,
                        userLocation: locationService.userLocation,
                        searchedLocation: searchedLocation,
                        isLoading: toiletService.isLoading,
                        themeColor: toiletThemeColor
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Section des 3 toilettes les plus proches
                    if !nearestToilets.isEmpty && locationService.userLocation != nil {
                        NearestToiletsView(
                            toilets: nearestToilets,
                            userLocation: locationService.userLocation!,
                            themeColor: toiletThemeColor
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    
                    // ✅ ESPACE POUR LE MENU EN BAS - IDENTIQUE À CONTENTVIEW
                    Spacer(minLength: 120)
                }
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            .refreshable {
                await toiletService.loadToilets()
            }
            
            // ✅ MENU DIRECTEMENT DANS LE ZSTACK - COMME CONTENTVIEW
            FixedBottomMenuView(
                isMenuExpanded: $navigationManager.isMenuExpanded,
                showToiletsMap: .constant(false),
                showBancsMap: .constant(false),
                onHomeSelected: { dismiss() },
                themeColor: Color(red: 0.7, green: 0.7, blue: 0.7)
            )
        }
        .onAppear {
            navigationManager.currentDestination = "toilets"
            setupInitialLocation()
            loadToilets()
        }
        .onDisappear {
            locationService.stopLocationUpdates()
        }
        .onChange(of: locationService.isLocationReady) { isReady in
            if isReady, let location = locationService.userLocation {
                centerMapOnLocation(location)
                print("📍 Toilettes: Position mise à jour automatiquement")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToBancs"))) { _ in
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHome"))) { _ in
            dismiss()
        }
        .overlay {
            if toiletService.isLoading && toiletService.toilets.isEmpty {
                LoadingOverlayView(themeColor: toiletThemeColor)
            }
        }
        .overlay {
            if let errorMessage = toiletService.errorMessage {
                ErrorOverlayView(message: errorMessage, themeColor: toiletThemeColor) {
                    loadToilets()
                }
            }
        }
    }
    
    // MARK: - Fonctions optimisées (inchangées)
    
    private func setupInitialLocation() {
        print("🗺️ Setup initial - toilettes")
        
        if locationService.userLocation == nil {
            print("🔄 Position pas encore disponible, refresh en cours...")
            locationService.refreshLocation()
        } else {
            print("✅ Position déjà disponible depuis l'init")
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
                let allSuggestions = await searchAddresses(query: text)
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
    
    private func handleSearchSubmitted() {
        showSuggestions = false
        
        Task {
            if let coordinate = await geocodeAddress(searchText) {
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
            print("🔄 Position indisponible, demande de refresh")
            locationService.refreshLocation()
            
            let startTime = Date()
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
                if let userLocation = locationService.userLocation {
                    timer.invalidate()
                    centerMapOnLocation(userLocation)
                    print("✅ Position reçue après \(Date().timeIntervalSince(startTime))s")
                } else if Date().timeIntervalSince(startTime) > 2.0 {
                    timer.invalidate()
                    print("⏰ Pas de position après 2s - garder position actuelle")
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
    
    // Fonctions de géocodage (inchangées)
    private func searchAddresses(query: String) async -> [AddressSuggestion] {
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
    
    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
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

// MARK: - Modèles nécessaires (inchangés)
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

// MARK: - ✅ NOUVELLE SECTION - Toilettes les plus proches
struct NearestToiletsView: View {
    let toilets: [ToiletLocation]
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête SANS ICÔNE
            HStack {
                Text("Toilettes les plus proches")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Liste des 3 toilettes
            VStack(spacing: 8) {
                ForEach(toilets) { toilet in
                    NearestToiletRowView(
                        toilet: toilet,
                        userLocation: userLocation,
                        themeColor: themeColor
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct NearestToiletRowView: View {
    let toilet: ToiletLocation
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    private var distance: String {
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let toiletLocation = CLLocation(latitude: toilet.coordinate.latitude, longitude: toilet.coordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: toiletLocation)
        
        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters))m"
        } else {
            return String(format: "%.1fkm", distanceInMeters / 1000)
        }
    }
    
    var body: some View {
        Button(action: {
            showNavigationAlert = true
        }) {
            HStack(spacing: 12) {
                // Icône WC AGRANDIE x2 (48px au lieu de 24px)
                Image("Wc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(toilet.isOpen ? themeColor : themeColor.opacity(0.5))
                
                // Informations toilette - UNIQUEMENT L'ADRESSE
                VStack(alignment: .leading, spacing: 4) {
                    Text(toilet.address)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Badges statut
                    HStack(spacing: 8) {
                        if toilet.isAccessible {
                            Text("♿ Accessible")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        if !toilet.isOpen {
                            Text("🔒 Fermé")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                // Distance et icône navigation
                VStack(spacing: 8) {
                    Text(distance)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(themeColor)
                    
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(themeColor)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .alert("Navigation", isPresented: $showNavigationAlert) {
            Button("Ouvrir dans Plans") {
                openNavigationToToilet()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers cette toilette ?")
        }
    }
    
    private func openNavigationToToilet() {
        let coordinate = toilet.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = toilet.address // Utilise l'adresse comme nom
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation à pied lancée vers: \(toilet.address) (\(coordinate.latitude), \(coordinate.longitude))")
    }
}

// MARK: - Composants UI avec couleur uniforme

struct MapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let toilets: [ToiletLocation]
    let userLocation: CLLocationCoordinate2D?
    let searchedLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    let themeColor: Color
    
    private var stableAnnotations: [MapAnnotationItem] {
        var annotations = toilets.map { toilet in
            MapAnnotationItem(toilet: toilet, coordinate: toilet.coordinate, isSearchResult: false)
        }
        
        if let searchedLocation = searchedLocation {
            annotations.append(MapAnnotationItem(toilet: nil, coordinate: searchedLocation, isSearchResult: true))
        }
        
        return annotations
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ✅ En-tête avec nombre de toilettes et bouton "Ma position"
            HStack {
                Text("Carte des toilettes (\(toilets.count))")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(themeColor)
                    }
                    
                    Button(action: {
                        centerOnUserLocation()
                    }) {
                        HStack(spacing: 4) {
                            Group {
                                if userLocation != nil {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "location.slash")
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Text("Ma position")
                                .font(.caption)
                        }
                        .foregroundColor(userLocation != nil ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(themeColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            .padding()
            .background(themeColor.opacity(0.2))
            
            // ✅ Map avec icônes WC personnalisées
            Map(coordinateRegion: $region,
                interactionModes: [.pan, .zoom],
                showsUserLocation: true,
                annotationItems: stableAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if let toilet = annotation.toilet {
                        ToiletWcMarkerView(toilet: toilet, themeColor: themeColor)
                            .id("toilet-\(toilet.id)")
                    } else if annotation.isSearchResult {
                        SearchPinMarker()
                            .id("search-pin")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    region.span = MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
                }
            }
            .frame(height: 350) // ✅ Réduit la hauteur pour faire de la place
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // ✅ Fonction pour centrer sur la position utilisateur
    private func centerOnUserLocation() {
        guard let userLocation = userLocation else {
            print("🔄 Position utilisateur non disponible")
            return
        }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = userLocation
            region.span = MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
        }
        
        print("🎯 Carte centrée sur position utilisateur")
    }
}

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let toilet: ToiletLocation?
    let coordinate: CLLocationCoordinate2D
    let isSearchResult: Bool
    
    var stableId: String {
        if let toilet = toilet {
            return "toilet-\(toilet.id)"
        } else if isSearchResult {
            return "search-pin"
        } else {
            return "unknown-\(id)"
        }
    }
}

struct SmartSearchBarView: View {
    @Binding var searchText: String
    let suggestions: [AddressSuggestion]
    @Binding var showSuggestions: Bool
    let onSearchTextChanged: (String) -> Void
    let onSuggestionTapped: (AddressSuggestion) -> Void
    let onSearchSubmitted: () -> Void
    let themeColor: Color
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeColor)
            
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
                .foregroundColor(themeColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: themeColor.opacity(0.2), radius: 4, x: 0, y: 2)
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
    let themeColor: Color
    
    var body: some View {
        HStack {
            // ✅ Icône WC + couleur unifiée pour le nombre
            HStack(spacing: 8) {
                Image("Wc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(themeColor)
                
                Text("\(count) toilettes")
                    .foregroundColor(themeColor)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
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
                .background(themeColor.opacity(0.1))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: themeColor.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct LoadingStatsView: View {
    let themeColor: Color
    
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
                .tint(themeColor)
            Text("Chargement des toilettes...")
                .font(.caption)
                .foregroundColor(themeColor)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: themeColor.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct LoadingOverlayView: View {
    let themeColor: Color
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(themeColor)
                
                Text("Chargement des toilettes...")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeColor.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: themeColor.opacity(0.3), radius: 8)
        }
    }
}

struct ErrorOverlayView: View {
    let message: String
    let themeColor: Color
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
                .background(themeColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeColor.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: themeColor.opacity(0.3), radius: 8)
        }
    }
}

// ✅ MARQUEUR MODIFIÉ - ICÔNE SEULE SANS BACKGROUND
struct ToiletWcMarkerView: View {
    let toilet: ToiletLocation
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    var body: some View {
        Button(action: {
            showNavigationAlert = true
        }) {
            ZStack {
                // ✅ PLUS DE BACKGROUND CIRCULAIRE - JUSTE L'ICÔNE
                Image("Wc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundColor(toilet.isOpen ? themeColor : themeColor.opacity(0.5))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1) // Ombre pour la visibilité
                
                // Bordure verte si accessible (autour de l'icône)
                if toilet.isAccessible {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                // Bordure rouge si fermé (autour de l'icône)
                if !toilet.isOpen {
                    RoundedRectangle(cornerRadius: 4)
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
