import SwiftUI
import MapKit
import Foundation

// MARK: - SilosMapView CORRIGÉ pour la nouvelle navigation
struct SilosMapView: View {
    @StateObject private var silosService = SilosAPIService()
    @StateObject private var locationService = GlobalLocationService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    
    // Region et états
    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var addressSuggestions: [SilosAddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?
    
    // ✅ COULEUR UNIFIÉE SILOS
    private let silosThemeColor = Color(red: 0.5, green: 0.7, blue: 0.7)
    
    // ✅ Computed property pour les 3 silos les plus proches
    private var nearestSilos: [SilosLocation] {
        guard let userLocation = locationService.userLocation else { return [] }
        
        return silosService.silos
            .map { silo in
                let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    .distance(from: CLLocation(latitude: silo.coordinate.latitude, longitude: silo.coordinate.longitude))
                return (silo: silo, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(3)
            .map { $0.silo }
    }
    
    // ✅ Initializer personnalisé
    init() {
        let initialCenter: CLLocationCoordinate2D
        if let userLocation = GlobalLocationService.shared.userLocation {
            initialCenter = userLocation
            print("🎯 Silos: Initialisation avec position utilisateur")
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
            print("🏛️ Silos: Initialisation avec Bellecour (fallback)")
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
                        Image("Silos")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(silosThemeColor)
                        
                        Text("Silos à Verre")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // ✅ Barre de recherche
                    VStack(spacing: 0) {
                        SilosSmartSearchBarView(
                            searchText: $searchText,
                            suggestions: addressSuggestions,
                            showSuggestions: $showSuggestions,
                            onSearchTextChanged: handleSearchTextChange,
                            onSuggestionTapped: handleSuggestionTap,
                            onSearchSubmitted: handleSearchSubmitted,
                            themeColor: silosThemeColor
                        )
                        
                        if showSuggestions && !addressSuggestions.isEmpty {
                            SilosSuggestionsListView(
                                suggestions: addressSuggestions,
                                onSuggestionTapped: handleSuggestionTap
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Carte
                    SilosMapBoxView(
                        region: $region,
                        silos: silosService.silos,
                        userLocation: locationService.userLocation,
                        searchedLocation: searchedLocation,
                        isLoading: silosService.isLoading,
                        themeColor: silosThemeColor
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Section des 3 silos les plus proches
                    if !nearestSilos.isEmpty && locationService.userLocation != nil {
                        NearestSilosView(
                            silos: nearestSilos,
                            userLocation: locationService.userLocation!,
                            themeColor: silosThemeColor
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
                await silosService.loadSilos()
            }
            
            // ✅ MENU DIRECTEMENT DANS LE ZSTACK - COMME CONTENTVIEW
            FixedBottomMenuView(
                isMenuExpanded: $navigationManager.isMenuExpanded,
                showToiletsMap: $navigationManager.showToiletsMap,
                showBancsMap: $navigationManager.showBancsMap,
                onHomeSelected: {
                    navigationManager.navigateToHome()
                },
                themeColor: silosThemeColor
            )
            
            .onAppear {
                navigationManager.currentDestination = "silos"
                setupInitialLocation()
                loadSilos()
            }
            .onDisappear {
                locationService.stopLocationUpdates()
            }
            .onChange(of: locationService.isLocationReady) { isReady in
                if isReady, let location = locationService.userLocation {
                    centerMapOnLocation(location)
                    print("📍 Silos: Position mise à jour automatiquement")
                }
            }
            .overlay {
                if silosService.isLoading && silosService.silos.isEmpty {
                    SilosLoadingOverlayView(themeColor: silosThemeColor)
                }
            }
            .overlay {
                if let errorMessage = silosService.errorMessage {
                    SilosErrorOverlayView(message: errorMessage, themeColor: silosThemeColor) {
                        loadSilos()
                    }
                }
            }
        }
    }
    
    // MARK: - Fonctions optimisées
    
    private func setupInitialLocation() {
        print("🗺️ Setup initial - silos")
        
        if locationService.userLocation == nil {
            print("🔄 Position pas encore disponible, refresh en cours...")
            locationService.refreshLocation()
        } else {
            print("✅ Position déjà disponible depuis l'init")
        }
    }
    
    private func loadSilos() {
        Task {
            await silosService.loadSilos()
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
    
    private func handleSuggestionTap(_ suggestion: SilosAddressSuggestion) {
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
    
    private func centerMapOnLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
        }
    }
    
    // Fonctions de géocodage
    private func searchAddresses(query: String) async -> [SilosAddressSuggestion] {
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
                    SilosAddressSuggestion(
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

// MARK: - Modèles nécessaires
struct SilosAddressSuggestion: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SilosAddressSuggestion, rhs: SilosAddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ✅ NOUVELLE SECTION - Silos les plus proches
struct NearestSilosView: View {
    let silos: [SilosLocation]
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête SANS ICÔNE
            HStack {
                Text("Silos les plus proches")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Liste des 3 silos
            VStack(spacing: 8) {
                ForEach(silos) { silo in
                    NearestSilosRowView(
                        silo: silo,
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

struct NearestSilosRowView: View {
    let silo: SilosLocation
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    private var distance: String {
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let siloLocation = CLLocation(latitude: silo.coordinate.latitude, longitude: silo.coordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: siloLocation)
        
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
                // Icône Silos AGRANDIE x2 (48px au lieu de 24px)
                Image("Silos")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(themeColor)
                
                // Informations silo - UNIQUEMENT L'ADRESSE
                VStack(alignment: .leading, spacing: 4) {
                    Text(silo.address)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Badges statut
                    HStack(spacing: 8) {
                        if silo.isAccessible {
                            Text("♿ Accessible")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        if !silo.type.isEmpty {
                            Text("📦 \(silo.type)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
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
                openNavigationToSilo()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers ce silo ?")
        }
    }
    
    private func openNavigationToSilo() {
        let coordinate = silo.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = silo.address // Utilise l'adresse comme nom
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation à pied lancée vers: \(silo.address) (\(coordinate.latitude), \(coordinate.longitude))")
    }
}

// MARK: - Composants UI avec couleur uniforme

struct SilosMapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let silos: [SilosLocation]
    let userLocation: CLLocationCoordinate2D?
    let searchedLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    let themeColor: Color
    
    private var stableAnnotations: [SilosMapAnnotationItem] {
        var annotations = silos.map { silo in
            SilosMapAnnotationItem(silo: silo, coordinate: silo.coordinate, isSearchResult: false)
        }
        
        if let searchedLocation = searchedLocation {
            annotations.append(SilosMapAnnotationItem(silo: nil, coordinate: searchedLocation, isSearchResult: true))
        }
        
        return annotations
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ✅ En-tête avec nombre de silos et bouton "Ma position"
            HStack {
                Text("Carte des silos (\(silos.count))")
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
            
            // ✅ Map avec icônes Silos personnalisées
            Map(coordinateRegion: $region,
                interactionModes: [.pan, .zoom],
                showsUserLocation: true,
                annotationItems: stableAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if let silo = annotation.silo {
                        SilosMarkerView(silo: silo, themeColor: themeColor)
                            .id("silo-\(silo.id)")
                    } else if annotation.isSearchResult {
                        SilosSearchPinMarker()
                            .id("search-pin")
                    }
                }
            }
        
            .frame(height: 350)
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

struct SilosMapAnnotationItem: Identifiable {
    let id = UUID()
    let silo: SilosLocation?
    let coordinate: CLLocationCoordinate2D
    let isSearchResult: Bool
    
    var stableId: String {
        if let silo = silo {
            return "silo-\(silo.id)"
        } else if isSearchResult {
            return "search-pin"
        } else {
            return "unknown-\(id)"
        }
    }
}

struct SilosSmartSearchBarView: View {
    @Binding var searchText: String
    let suggestions: [SilosAddressSuggestion]
    @Binding var showSuggestions: Bool
    let onSearchTextChanged: (String) -> Void
    let onSuggestionTapped: (SilosAddressSuggestion) -> Void
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

struct SilosSuggestionsListView: View {
    let suggestions: [SilosAddressSuggestion]
    let onSuggestionTapped: (SilosAddressSuggestion) -> Void
    
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

struct SilosLoadingOverlayView: View {
    let themeColor: Color
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(themeColor)
                
                Text("Chargement des silos...")
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

struct SilosErrorOverlayView: View {
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
struct SilosMarkerView: View {
    let silo: SilosLocation
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    var body: some View {
        Button(action: {
            showNavigationAlert = true
        }) {
            ZStack {
                // ✅ PLUS DE BACKGROUND CIRCULAIRE - JUSTE L'ICÔNE
                Image("Silos")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundColor(themeColor)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1) // Ombre pour la visibilité
                
                // Bordure verte si accessible (autour de l'icône)
                if silo.isAccessible {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                // Bordure bleue pour type spécial (autour de l'icône)
                if !silo.type.isEmpty {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, lineWidth: 2)
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
            Text("Voulez-vous ouvrir la navigation vers \(silo.name) ?")
        }
    }
    
    private func openInMaps() {
        let coordinate = silo.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = silo.name
        mapItem.phoneNumber = nil
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation lancée vers: \(silo.name) (\(coordinate.latitude), \(coordinate.longitude))")
    }
}

struct SilosSearchPinMarker: View {
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

// MARK: - Service API et modèles

@MainActor
class SilosAPIService: ObservableObject {
    @Published var silos: [SilosLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gic_collecte.siloverre&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
    
    func loadSilos() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let url = URL(string: apiURL) else {
                throw SilosAPIError.invalidURL
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SilosAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw SilosAPIError.httpError(httpResponse.statusCode)
            }
            
            let geoJsonResponse = try JSONDecoder().decode(SilosGeoJSONResponse.self, from: data)
            
            let silosLocations = geoJsonResponse.features.compactMap { feature -> SilosLocation? in
                guard feature.geometry.coordinates.count >= 2 else { return nil }
                
                let longitude = feature.geometry.coordinates[0]
                let latitude = feature.geometry.coordinates[1]
                let props = feature.properties
                
                return SilosLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    name: props.nom ?? "Silo à verre",
                    address: formatAddress(props),
                    gestionnaire: props.gestionnaire ?? "Non spécifié",
                    isAccessible: props.acces_pmr == "Oui" || props.acces_pmr == "oui",
                    type: props.type_silo ?? "",
                    capacite: props.capacite,
                    commune: props.commune ?? ""
                )
            }
            
            silos = silosLocations
            isLoading = false
            
            print("✅ \(silos.count) silos chargés avec succès")
            
        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            isLoading = false
            print("❌ Erreur chargement silos: \(error)")
        }
    }
    
    private func formatAddress(_ props: SilosProperties) -> String {
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
}

struct SilosLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
    let address: String
    let gestionnaire: String
    let isAccessible: Bool
    let type: String
    let capacite: String?
    let commune: String
}

struct SilosGeoJSONResponse: Codable {
    let type: String
    let features: [SilosFeature]
    let totalFeatures: Int?
}

struct SilosFeature: Codable {
    let type: String
    let geometry: SilosGeometry
    let properties: SilosProperties
}

struct SilosGeometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct SilosProperties: Codable {
    let gid: Int?
    let nom: String?
    let adresse: String?
    let code_postal: String?
    let commune: String?
    let gestionnaire: String?
    let acces_pmr: String?
    let type_silo: String?
    let capacite: String?
}

enum SilosAPIError: Error, LocalizedError {
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
    SilosMapView()
}
