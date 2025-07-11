import SwiftUI
import MapKit
import Foundation

// MARK: - ParcsMapView CORRIGÉ pour la nouvelle navigation et polygones
struct ParcsMapView: View {
    @StateObject private var parcsService = ParcsAPIService()
    @StateObject private var locationService = GlobalLocationService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    
    // Region et états
    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var addressSuggestions: [ParcsAddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?
    
    // ✅ COULEUR UNIFIÉE PARCS
    private let parcsThemeColor = Color(red: 0xAF/255.0, green: 0xD0/255.0, blue: 0xA3/255.0)
    
    // ✅ Computed property pour les 3 parcs les plus proches
    private var nearestParcs: [ParcLocation] {
        guard let userLocation = locationService.userLocation else { return [] }

// MARK: - ✅ MODALE DÉTAILS DU PARC
struct ParcDetailModalView: View {
    let parc: ParcLocation
    let themeColor: Color
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // En-tête avec icône et nom
                    HStack(spacing: 16) {
                        Image("PetJ")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(themeColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(parc.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(parc.commune)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(themeColor.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Informations principales
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRowView(
                            icon: "location",
                            title: "Adresse",
                            value: parc.address.isEmpty ? "Non renseignée" : parc.address,
                            themeColor: themeColor
                        )
                        
                        if let surface = parc.surface {
                            DetailRowView(
                                icon: "ruler",
                                title: "Surface",
                                value: formatSurface(surface),
                                themeColor: themeColor
                            )
                        }
                        
                        DetailRowView(
                            icon: "person.3",
                            title: "Gestionnaire",
                            value: parc.gestionnaire.isEmpty ? "Non renseigné" : parc.gestionnaire,
                            themeColor: themeColor
                        )
                        
                        if !parc.type.isEmpty {
                            DetailRowView(
                                icon: "gamecontroller",
                                title: "Équipements",
                                value: parc.type,
                                themeColor: themeColor
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: themeColor.opacity(0.2), radius: 4)
                    
                    // Badges équipements
                    if parc.hasPlayground || parc.hasSportsArea {
                        HStack(spacing: 12) {
                            if parc.hasPlayground {
                                EquipmentBadge(
                                    icon: "figure.play",
                                    text: "Aires de jeux",
                                    color: .orange
                                )
                            }
                            
                            if parc.hasSportsArea {
                                EquipmentBadge(
                                    icon: "figure.run",
                                    text: "Équipements sportifs",
                                    color: .blue
                                )
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: themeColor.opacity(0.2), radius: 4)
                    }
                    
                    // Bouton navigation
                    Button(action: {
                        openInMaps()
                    }) {
                        HStack {
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 18))
                            
                            Text("Ouvrir dans Plans")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .cornerRadius(12)
                    }
                    .padding(.top)
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Détails du parc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(themeColor)
                }
            }
        }
    }
    
    private func formatSurface(_ surface: Double) -> String {
        if surface >= 10000 {
            return String(format: "%.1f ha", surface / 10000)
        } else {
            return String(format: "%.0f m²", surface)
        }
    }
    
    private func openInMaps() {
        let coordinate = parc.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = parc.name
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        dismiss()
    }
}

struct DetailRowView: View {
    let icon: String
    let title: String
    let value: String
    let themeColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct EquipmentBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(20)
    }
}
        
        return parcsService.parcs
            .map { parc in
                let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    .distance(from: CLLocation(latitude: parc.coordinate.latitude, longitude: parc.coordinate.longitude))
                return (parc: parc, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(3)
            .map { $0.parc }
    }
    
    // ✅ Initializer personnalisé
    init() {
        let initialCenter: CLLocationCoordinate2D
        if let userLocation = GlobalLocationService.shared.userLocation {
            initialCenter = userLocation
            print("🎯 Parcs: Initialisation avec position utilisateur")
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
            print("🏛️ Parcs: Initialisation avec Bellecour (fallback)")
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
                        Image("PetJ")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(parcsThemeColor)
                        
                        Text("Parcs & Jardins")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // ✅ Barre de recherche
                    VStack(spacing: 0) {
                        ParcsSmartSearchBarView(
                            searchText: $searchText,
                            suggestions: addressSuggestions,
                            showSuggestions: $showSuggestions,
                            onSearchTextChanged: handleSearchTextChange,
                            onSuggestionTapped: handleSuggestionTap,
                            onSearchSubmitted: handleSearchSubmitted,
                            themeColor: parcsThemeColor
                        )
                        
                        if showSuggestions && !addressSuggestions.isEmpty {
                            ParcsSuggestionsListView(
                                suggestions: addressSuggestions,
                                onSuggestionTapped: handleSuggestionTap
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Carte
                    ParcsMapBoxView(
                        region: $region,
                        parcs: parcsService.parcs,
                        userLocation: locationService.userLocation,
                        searchedLocation: searchedLocation,
                        isLoading: parcsService.isLoading,
                        themeColor: parcsThemeColor
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Section des 3 parcs les plus proches
                    if !nearestParcs.isEmpty && locationService.userLocation != nil {
                        NearestParcsView(
                            parcs: nearestParcs,
                            userLocation: locationService.userLocation!,
                            themeColor: parcsThemeColor
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
                await parcsService.loadParcs()
            }
            
            // ✅ MENU DIRECTEMENT DANS LE ZSTACK - COMME CONTENTVIEW
            FixedBottomMenuView(
                isMenuExpanded: $navigationManager.isMenuExpanded,
                showToiletsMap: $navigationManager.showToiletsMap,
                showBancsMap: $navigationManager.showBancsMap,
                showFontainesMap: $navigationManager.showFontainesMap, 
                showSilosMap: $navigationManager.showSilosMap,
                showBornesMap: $navigationManager.showBornesMap,
                showCompostMap: $navigationManager.showCompostMap,
                showParcsMap: $navigationManager.showParcsMap,
                showPoubelleMap: $navigationManager.showPoubelleMap,
                showRandosMap: $navigationManager.showRandosMap,
                onHomeSelected: {
                    navigationManager.navigateToHome()
                },
                themeColor: parcsThemeColor
            )
            
            .onAppear {
                navigationManager.currentDestination = "parcs"
                setupInitialLocation()
                loadParcs()
            }
            .onDisappear {
                locationService.stopLocationUpdates()
            }
            .onChange(of: locationService.isLocationReady) { isReady in
                if isReady, let location = locationService.userLocation {
                    centerMapOnLocation(location)
                    print("📍 Parcs: Position mise à jour automatiquement")
                }
            }
            .overlay {
                if parcsService.isLoading && parcsService.parcs.isEmpty {
                    ParcsLoadingOverlayView(themeColor: parcsThemeColor)
                }
            }
            .overlay {
                if let errorMessage = parcsService.errorMessage {
                    ParcsErrorOverlayView(message: errorMessage, themeColor: parcsThemeColor) {
                        loadParcs()
                    }
                }
            }
        }
    }
    
    // MARK: - Fonctions optimisées
    
    private func setupInitialLocation() {
        print("🗺️ Setup initial - parcs")
        
        if locationService.userLocation == nil {
            print("🔄 Position pas encore disponible, refresh en cours...")
            locationService.refreshLocation()
        } else {
            print("✅ Position déjà disponible depuis l'init")
        }
    }
    
    private func loadParcs() {
        Task {
            await parcsService.loadParcs()
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
    
    private func handleSuggestionTap(_ suggestion: ParcsAddressSuggestion) {
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
    private func searchAddresses(query: String) async -> [ParcsAddressSuggestion] {
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
                    ParcsAddressSuggestion(
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
struct ParcsAddressSuggestion: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ParcsAddressSuggestion, rhs: ParcsAddressSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ✅ NOUVELLE SECTION - Parcs les plus proches
struct NearestParcsView: View {
    let parcs: [ParcLocation]
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête SANS ICÔNE
            HStack {
                Text("Parcs & Jardins les plus proches")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Liste des 3 parcs
            VStack(spacing: 8) {
                ForEach(parcs) { parc in
                    NearestParcRowView(
                        parc: parc,
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

struct NearestParcRowView: View {
    let parc: ParcLocation
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    private var distance: String {
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let parcLocation = CLLocation(latitude: parc.coordinate.latitude, longitude: parc.coordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: parcLocation)
        
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
                // Icône Parc AGRANDIE x2 (48px au lieu de 24px)
                Image("PetJ")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(themeColor)
                
                // Informations parc - UNIQUEMENT LE NOM
                VStack(alignment: .leading, spacing: 4) {
                    Text(parc.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
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
                openNavigationToParc()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers ce parc ?")
        }
    }
    
    private func openNavigationToParc() {
        let coordinate = parc.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = parc.name
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation à pied lancée vers: \(parc.name) (\(coordinate.latitude), \(coordinate.longitude))")
    }
}

// MARK: - Composants UI avec couleur uniforme

struct ParcsMapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let parcs: [ParcLocation]
    let userLocation: CLLocationCoordinate2D?
    let searchedLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    let themeColor: Color
    
    private var stableAnnotations: [ParcsMapAnnotationItem] {
        var annotations = parcs.map { parc in
            ParcsMapAnnotationItem(parc: parc, coordinate: parc.coordinate, isSearchResult: false)
        }
        
        if let searchedLocation = searchedLocation {
            annotations.append(ParcsMapAnnotationItem(parc: nil, coordinate: searchedLocation, isSearchResult: true))
        }
        
        return annotations
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ✅ En-tête avec nombre de parcs et bouton "Ma position"
            HStack {
                Text("Carte des parcs (\(parcs.count))")
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
            
            // ✅ Map avec icônes Parcs personnalisées
            Map(coordinateRegion: $region,
                interactionModes: [.pan, .zoom],
                showsUserLocation: true,
                annotationItems: stableAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if let parc = annotation.parc {
                        ParcsMarkerView(parc: parc, themeColor: themeColor)
                            .id("parc-\(parc.id)")
                    } else if annotation.isSearchResult {
                        ParcsSearchPinMarker()
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

struct ParcsMapAnnotationItem: Identifiable {
    let id = UUID()
    let parc: ParcLocation?
    let coordinate: CLLocationCoordinate2D
    let isSearchResult: Bool
    
    var stableId: String {
        if let parc = parc {
            return "parc-\(parc.id)"
        } else if isSearchResult {
            return "search-pin"
        } else {
            return "unknown-\(id)"
        }
    }
}

struct ParcsSmartSearchBarView: View {
    @Binding var searchText: String
    let suggestions: [ParcsAddressSuggestion]
    @Binding var showSuggestions: Bool
    let onSearchTextChanged: (String) -> Void
    let onSuggestionTapped: (ParcsAddressSuggestion) -> Void
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

struct ParcsSuggestionsListView: View {
    let suggestions: [ParcsAddressSuggestion]
    let onSuggestionTapped: (ParcsAddressSuggestion) -> Void
    
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

struct ParcsLoadingOverlayView: View {
    let themeColor: Color
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(themeColor)
                
                Text("Chargement des parcs...")
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

struct ParcsErrorOverlayView: View {
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

// MARK: - ✅ MODALE DÉTAILS DU PARC
struct ParcDetailModalView: View {
    let parc: ParcLocation
    let themeColor: Color
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // En-tête avec icône et nom
                    HStack(spacing: 16) {
                        Image("PetJ")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(themeColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(parc.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(parc.commune)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(themeColor.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Informations principales
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRowView(
                            icon: "location",
                            title: "Adresse",
                            value: parc.address.isEmpty ? "Non renseignée" : parc.address,
                            themeColor: themeColor
                        )
                        
                        if let surface = parc.surface {
                            DetailRowView(
                                icon: "ruler",
                                title: "Surface",
                                value: formatSurface(surface),
                                themeColor: themeColor
                            )
                        }
                        
                        DetailRowView(
                            icon: "person.3",
                            title: "Gestionnaire",
                            value: parc.gestionnaire.isEmpty ? "Non renseigné" : parc.gestionnaire,
                            themeColor: themeColor
                        )
                        
                        if !parc.type.isEmpty {
                            DetailRowView(
                                icon: "gamecontroller",
                                title: "Équipements",
                                value: parc.type,
                                themeColor: themeColor
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: themeColor.opacity(0.2), radius: 4)
                    
                   
                    
                    // Bouton navigation
                    Button(action: {
                        openInMaps()
                    }) {
                        HStack {
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 18))
                            
                            Text("Ouvrir dans Plans")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .cornerRadius(12)
                    }
                    .padding(.top)
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Détails du parc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(themeColor)
                }
            }
        }
    }
    
    private func formatSurface(_ surface: Double) -> String {
        if surface >= 10000 {
            return String(format: "%.1f ha", surface / 10000)
        } else {
            return String(format: "%.0f m²", surface)
        }
    }
    
    private func openInMaps() {
        let coordinate = parc.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = parc.name
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        dismiss()
    }
}

struct DetailRowView: View {
    let icon: String
    let title: String
    let value: String
    let themeColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct EquipmentBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(20)
    }
}

// ✅ MARQUEUR SIMPLIFIÉ - ICÔNE SEULE SANS BORDURES
struct ParcsMarkerView: View {
    let parc: ParcLocation
    let themeColor: Color
    @State private var showParcDetails = false
    
    var body: some View {
        Button(action: {
            showParcDetails = true
        }) {
            // ✅ JUSTE L'ICÔNE SANS BORDURES
            Image("PetJ")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .foregroundColor(themeColor)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1) // Ombre pour la visibilité
        }
        .sheet(isPresented: $showParcDetails) {
            ParcDetailModalView(parc: parc, themeColor: themeColor)
        }
    }
}

struct ParcsSearchPinMarker: View {
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
class ParcsAPIService: ObservableObject {
    @Published var parcs: [ParcLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:com_donnees_communales.comparcjardin_1_0_0&SRSNAME=EPSG:4171&outputFormat=application/json&startIndex=0&sortby=gid"
    
    func loadParcs() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let url = URL(string: apiURL) else {
                throw ParcsAPIError.invalidURL
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ParcsAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw ParcsAPIError.httpError(httpResponse.statusCode)
            }
            
            let geoJsonResponse = try JSONDecoder().decode(ParcsGeoJSONResponse.self, from: data)
            
            let parcLocations = geoJsonResponse.features.compactMap { feature -> ParcLocation? in
                // Extraire le centre du polygone/multipolygon
                guard let centerCoordinate = extractCenterFromGeometry(feature.geometry) else {
                    print("⚠️ Impossible d'extraire les coordonnées pour: \(feature.properties.nom ?? "Parc sans nom")")
                    return nil
                }
                
                let props = feature.properties
                
                return ParcLocation(
                    coordinate: centerCoordinate,
                    name: props.nom ?? "Parc",
                    address: formatAddress(props),
                    commune: props.commune ?? "",
                    surface: props.surf_tot_m2,
                    hasPlayground: hasPlaygroundEquipment(props),
                    hasSportsArea: hasSportsEquipment(props),
                    type: props.type_equip ?? "",
                    gestionnaire: props.gestion ?? ""
                )
            }
            
            parcs = parcLocations
            isLoading = false
            
            print("✅ \(parcs.count) parcs chargés avec succès")
            
        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            isLoading = false
            print("❌ Erreur chargement parcs: \(error)")
        }
    }
    
    // ✅ FONCTION CLÉE - Extraction du centre des polygones
    private func extractCenterFromGeometry(_ geometry: ParcsGeometry) -> CLLocationCoordinate2D? {
        // Gestion des différents types de géométrie GeoJSON
        switch geometry.type {
        case "MultiPolygon":
            // Prendre le premier polygone du multipolygon
            guard let firstPolygon = geometry.coordinates.first,
                  let outerRing = firstPolygon.first else {
                print("⚠️ MultiPolygon vide ou mal formé")
                return nil
            }
            return calculatePolygonCenter(outerRing)
            
        case "Polygon":
            // Pour un polygone simple - adapter selon la structure réelle
            print("⚠️ Type Polygon détecté - structure non testée")
            return nil
            
        default:
            print("⚠️ Type de géométrie non supporté: \(geometry.type)")
            return nil
        }
    }
    
    // ✅ CALCUL DU CENTROÏDE D'UN POLYGONE
    private func calculatePolygonCenter(_ coordinates: [[Double]]) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else {
            print("⚠️ Tableau de coordonnées vide")
            return nil
        }
        
        var totalLat = 0.0
        var totalLon = 0.0
        var validCount = 0
        
        for coord in coordinates {
            guard coord.count >= 2 else {
                print("⚠️ Coordonnée invalide: \(coord)")
                continue
            }
            let longitude = coord[0]
            let latitude = coord[1]
            
            // Vérification que les coordonnées sont valides (région Lyon)
            if latitude >= 45.0 && latitude <= 46.0 && longitude >= 4.0 && longitude <= 5.0 {
                totalLon += longitude
                totalLat += latitude
                validCount += 1
            } else {
                print("⚠️ Coordonnée hors zone Lyon: [\(longitude), \(latitude)]")
            }
        }
        
        guard validCount > 0 else {
            print("⚠️ Aucune coordonnée valide trouvée")
            return nil
        }
        
        let centerLat = totalLat / Double(validCount)
        let centerLon = totalLon / Double(validCount)
        
        print("✅ Centre calculé: [\(centerLon), \(centerLat)] à partir de \(validCount) points")
        return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }
    
    private func formatAddress(_ props: ParcsProperties) -> String {
        var addressParts: [String] = []
        
        if let voie = props.voie, !voie.isEmpty {
            if let numvoie = props.numvoie, !numvoie.isEmpty {
                addressParts.append("\(numvoie) \(voie)")
            } else {
                addressParts.append(voie)
            }
        }
        
        if let codepost = props.codepost, let commune = props.commune {
            addressParts.append("\(codepost) \(commune)")
        } else if let commune = props.commune {
            addressParts.append(commune)
        }
        
        return addressParts.isEmpty ? "Adresse non disponible" : addressParts.joined(separator: ", ")
    }
    
    private func hasPlaygroundEquipment(_ props: ParcsProperties) -> Bool {
        let name = props.nom?.lowercased() ?? ""
        let typeEquip = props.type_equip?.lowercased() ?? ""
        
        return name.contains("jeux") ||
               name.contains("enfant") ||
               name.contains("aire") ||
               typeEquip.contains("jeux") ||
               typeEquip.contains("aire")
    }
    
    private func hasSportsEquipment(_ props: ParcsProperties) -> Bool {
        let name = props.nom?.lowercased() ?? ""
        let typeEquip = props.type_equip?.lowercased() ?? ""
        
        return name.contains("sport") ||
               name.contains("terrain") ||
               name.contains("stade") ||
               name.contains("foot") ||
               name.contains("basket") ||
               name.contains("parcours") ||
               typeEquip.contains("sport") ||
               typeEquip.contains("terrain") ||
               typeEquip.contains("parcours")
    }
}

struct ParcLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
    let address: String
    let commune: String
    let surface: Double?
    let hasPlayground: Bool
    let hasSportsArea: Bool
    let type: String
    let gestionnaire: String
}

// ✅ STRUCTURES CORRIGÉES POUR L'API PARCS
struct ParcsGeoJSONResponse: Codable {
    let type: String
    let features: [ParcsFeature]
    let totalFeatures: Int?
}

struct ParcsFeature: Codable {
    let type: String
    let geometry: ParcsGeometry
    let properties: ParcsProperties
}

// ✅ GÉOMÉTRIE ADAPTÉE AUX MULTIPOLYGONES
struct ParcsGeometry: Codable {
    let type: String
    let coordinates: [[[[Double]]]]  // MultiPolygon: 4 niveaux d'imbrication
}

// ✅ PROPRIÉTÉS BASÉES SUR LES VRAIES DONNÉES DE L'API
struct ParcsProperties: Codable {
    let uid: String?
    let id_ariane: String?
    let nom: String?
    let num: Int?
    let numvoie: String?
    let voie: String?
    let codepost: Int?
    let commune: String?
    let code_insee: Int?
    let reglement: String?
    let surf_tot_m2: Double?
    let gestion: String?
    let ann_ouvert: Int?
    let clos: String?
    let openinghoursspecification: String?
    let precision_horaires: String?
    let acces: String?
    let circulation: String?
    let label: String?
    let type_equip: String?
    let eau: String?
    let toilettes: String?
    let chien: String?
    let esp_can: String?
    let photo: String?
    let gid: Int?
    let openinghours: String?
    let last_update_fme: String?
    let horaires: String?
}

enum ParcsAPIError: Error, LocalizedError {
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
    ParcsMapView()
}
