import SwiftUI
import MapKit
import Foundation

// MARK: - PoubelleMapView ultra-optimisé avec filtrage géographique
struct PoubelleMapView: View {
    @StateObject private var poubelleService = OptimizedPoubelleAPIService()
    @StateObject private var locationService = GlobalLocationService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    
    // ✅ Region initialisée avec position utilisateur, zoom serré
    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var addressSuggestions: [PoubelleAddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?
    
    // ✅ État pour gérer le focus actuel (utilisateur ou recherche)
    @State private var focusLocation: CLLocationCoordinate2D?
    @State private var isSearchMode = false
    @State private var showInfoModal = false // ✅ Nouvelle variable pour la bulle info
    
    // ✅ COULEUR UNIFIÉE POUBELLES
    private let poubelleThemeColor = Color(red: 0.6, green: 0.6, blue: 0.6)
    
    // ✅ Location actuelle à utiliser (utilisateur ou recherche)
    private var currentFocusLocation: CLLocationCoordinate2D? {
        if isSearchMode, let searchLocation = searchedLocation {
            return searchLocation
        }
        return locationService.userLocation
    }
    
    // ✅ Computed property pour les poubelles proches du focus actuel
    private var nearbyPoubelles: [PoubelleLocation] {
        return poubelleService.nearbyPoubelles
    }
    
    // ✅ Computed property pour les 3 poubelles les plus proches (section)
    private var topThreePoubelles: [PoubelleLocation] {
        return Array(nearbyPoubelles.prefix(3))
    }
    
    // ✅ Computed property pour les annotations
    private var mapAnnotations: [PoubelleMapAnnotationItem] {
        var annotations: [PoubelleMapAnnotationItem] = []
        
        // Afficher les poubelles proches
        for poubelle in nearbyPoubelles {
            annotations.append(PoubelleMapAnnotationItem(
                poubelle: poubelle,
                coordinate: poubelle.coordinate,
                isSearchResult: false
            ))
        }
        
        // Ajouter le pin de recherche si présent
        if let searchedLocation = searchedLocation {
            annotations.append(PoubelleMapAnnotationItem(
                poubelle: nil,
                coordinate: searchedLocation,
                isSearchResult: true
            ))
        }
        
        return annotations
    }
    
    // ✅ Initializer avec zoom serré
    init() {
        let initialCenter: CLLocationCoordinate2D
        if let userLocation = GlobalLocationService.shared.userLocation {
            initialCenter = userLocation
            print("🎯 Poubelles: Initialisation avec position utilisateur")
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
            print("🏛️ Poubelles: Initialisation avec Bellecour (fallback)")
        }
        
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        ))
    }
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ✅ TITRE FIXE EN HAUT AVEC BOUTON INFO
                    HStack(spacing: 12) {
                        Image("Poubelle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(poubelleThemeColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text("Poubelles Publiques")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                // ✅ BOUTON INFO SIMPLE
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showInfoModal.toggle()
                                    }
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(poubelleThemeColor)
                                }
                            }
                            
                            if isSearchMode {
                                Text("Autour de votre recherche")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Autour de vous")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // ✅ PETITE BULLE D'INFO
                    if showInfoModal {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("La carte renvoie les 50 poubelles les plus proches dans un rayon de 800m autour de l'utilisateur ou du point de recherche sur les 12 833 poubelles référencées.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(poubelleThemeColor.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(poubelleThemeColor.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // ✅ Barre de recherche améliorée
                    VStack(spacing: 0) {
                        PoubelleSmartSearchBarView(
                            searchText: $searchText,
                            suggestions: addressSuggestions,
                            showSuggestions: $showSuggestions,
                            onSearchTextChanged: handleSearchTextChange,
                            onSuggestionTapped: handleSuggestionTap,
                            onSearchSubmitted: handleSearchSubmitted,
                            onClearSearch: handleClearSearch,
                            themeColor: poubelleThemeColor
                        )
                        
                        if showSuggestions && !addressSuggestions.isEmpty {
                            PoubelleSuggestionsListView(
                                suggestions: addressSuggestions,
                                onSuggestionTapped: handleSuggestionTap
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Carte optimisée
                    PoubelleMapBoxView(
                        region: $region,
                        poubelles: nearbyPoubelles,
                        mapAnnotations: mapAnnotations,
                        userLocation: locationService.userLocation,
                        searchedLocation: searchedLocation,
                        isLoading: poubelleService.isLoading,
                        isSearchMode: isSearchMode,
                        themeColor: poubelleThemeColor
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Section des 3 poubelles les plus proches
                    if !topThreePoubelles.isEmpty {
                        NearestPoubellseView(
                            poubelles: topThreePoubelles,
                            referenceLocation: currentFocusLocation ?? region.center,
                            isSearchMode: isSearchMode,
                            themeColor: poubelleThemeColor
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    
                    Spacer(minLength: 120)
                }
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            .refreshable {
                await refreshCurrentLocation()
            }
            .onTapGesture {
                // Fermer la bulle info si on tape ailleurs
                if showInfoModal {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInfoModal = false
                    }
                }
            }
            
            // ✅ MENU DIRECTEMENT DANS LE ZSTACK
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
                themeColor: poubelleThemeColor
            )
        }
        .onAppear {
            navigationManager.currentDestination = "poubelles"
            setupInitialLocation()
        }
        .onDisappear {
            locationService.stopLocationUpdates()
        }
        .onChange(of: locationService.isLocationReady) { isReady in
            if isReady, let location = locationService.userLocation, !isSearchMode {
                centerMapOnLocation(location)
                Task {
                    await poubelleService.loadPoubellsAroundLocation(location)
                }
            }
        }
        .overlay {
            if poubelleService.isLoading && poubelleService.nearbyPoubelles.isEmpty {
                PoubelleLoadingOverlayView(themeColor: poubelleThemeColor)
            }
        }
        .overlay {
            if let errorMessage = poubelleService.errorMessage {
                PoubelleErrorOverlayView(message: errorMessage, themeColor: poubelleThemeColor) {
                    Task {
                        await refreshCurrentLocation()
                    }
                }
            }
        }
    }
    
    // MARK: - ✅ GESTION DE LA RECHERCHE AMÉLIORÉE
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
    
    private func handleSuggestionTap(_ suggestion: PoubelleAddressSuggestion) {
        searchText = suggestion.title
        showSuggestions = false
        
        // ✅ ACTIVER LE MODE RECHERCHE
        isSearchMode = true
        searchedLocation = suggestion.coordinate
        focusLocation = suggestion.coordinate
        
        // ✅ CHARGER LES POUBELLES AUTOUR DE LA RECHERCHE
        Task {
            await poubelleService.loadPoubellsAroundLocation(suggestion.coordinate)
        }
        
        centerMapOnLocation(suggestion.coordinate)
        print("🔍 Mode recherche activé: \(suggestion.title)")
    }
    
    private func handleSearchSubmitted() {
        showSuggestions = false
        
        Task {
            if let coordinate = await geocodeAddress(searchText) {
                isSearchMode = true
                searchedLocation = coordinate
                focusLocation = coordinate
                
                await poubelleService.loadPoubellsAroundLocation(coordinate)
                centerMapOnLocation(coordinate)
                print("🔍 Recherche soumise: \(searchText)")
            }
        }
    }
    
    // ✅ NOUVELLE FONCTION POUR EFFACER LA RECHERCHE
    private func handleClearSearch() {
        searchText = ""
        searchedLocation = nil
        isSearchMode = false
        showSuggestions = false
        
        // Retourner à la position utilisateur
        if let userLocation = locationService.userLocation {
            focusLocation = userLocation
            centerMapOnLocation(userLocation)
            Task {
                await poubelleService.loadPoubellsAroundLocation(userLocation)
            }
            print("🏠 Retour au mode utilisateur")
        }
    }
    
    // MARK: - Fonctions conservées et optimisées
    
    private func setupInitialLocation() {
        print("🗺️ Setup initial - poubelles optimisé")
        
        if let userLocation = locationService.userLocation {
            focusLocation = userLocation
            Task {
                await poubelleService.loadPoubellsAroundLocation(userLocation)
            }
        } else {
            locationService.refreshLocation()
        }
    }
    
    private func refreshCurrentLocation() async {
        if let currentLocation = currentFocusLocation {
            await poubelleService.loadPoubellsAroundLocation(currentLocation)
        }
    }
    
    private func centerMapOnLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        }
    }
    
    // MARK: - Fonctions de géocodage (corrigées)
    private func searchAddresses(query: String) async -> [PoubelleAddressSuggestion] {
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
                    PoubelleAddressSuggestion(
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

// MARK: - ✅ SERVICE API ULTRA-OPTIMISÉ AVEC FILTRAGE GÉOGRAPHIQUE
@MainActor
class OptimizedPoubelleAPIService: ObservableObject {
    @Published var nearbyPoubelles: [PoubelleLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // ✅ Cache intelligent par zones avec expiration longue
    private var zoneCache: [String: CachedZone] = [:]
    private let cacheExpiryTime: TimeInterval = 3600 // ✅ 1 heure au lieu de 5 minutes
    private let maxPoubellesToShow = 50
    
    // ✅ Cache global pour éviter les requêtes répétées
    private static var globalPoubellesCache: [PoubelleLocation] = []
    private static var globalCacheTimestamp: Date = Date.distantPast
    private static let globalCacheExpiry: TimeInterval = 86400 // 24 heures
    
    struct CachedZone {
        let poubelles: [PoubelleLocation]
        let timestamp: Date
        let centerLocation: CLLocationCoordinate2D
    }
    
    // ✅ FONCTION PRINCIPALE - AVEC CACHE GLOBAL
    func loadPoubellsAroundLocation(_ location: CLLocationCoordinate2D) async {
        // ✅ VÉRIFIER LE CACHE GLOBAL D'ABORD
        if !Self.globalPoubellesCache.isEmpty,
           Date().timeIntervalSince(Self.globalCacheTimestamp) < Self.globalCacheExpiry {
            
            // Utiliser le cache global et filtrer localement
            let nearbyPoubelles = Self.globalPoubellesCache
                .map { poubelle in
                    let distance = location.distanceToPoubelle(poubelle.coordinate)
                    return (poubelle: poubelle, distance: distance)
                }
                .filter { $0.distance <= 800 }
                .sorted { $0.distance < $1.distance }
                .map { $0.poubelle }
            
            self.nearbyPoubelles = Array(nearbyPoubelles.prefix(maxPoubellesToShow))
            print("🌍 Cache global utilisé: \(self.nearbyPoubelles.count) poubelles trouvées")
            return
        }
        
        // ✅ VÉRIFIER LE CACHE LOCAL
        let zoneKey = generateZoneKey(for: location)
        if let cachedZone = zoneCache[zoneKey],
           Date().timeIntervalSince(cachedZone.timestamp) < cacheExpiryTime,
           cachedZone.centerLocation.distanceToPoubelle(location) < 200 {
            
            nearbyPoubelles = Array(cachedZone.poubelles.prefix(maxPoubellesToShow))
            print("📦 Cache local utilisé: \(nearbyPoubelles.count) poubelles depuis le cache")
            return
        }
        
        // ✅ CHARGER DEPUIS L'API SEULEMENT SI NÉCESSAIRE
        await loadPoubellsFromAPIFallback(around: location)
    }
    
    // ✅ MÉTHODE FALLBACK SANS BBOX
    private func loadPoubellsFromAPIFallback(around location: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fallbackURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gin_nettoiement.gincorbeille&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
            
            guard let url = URL(string: fallbackURL) else {
                throw PoubelleAPIError.invalidURL
            }
            
            print("🔄 Fallback: chargement de toutes les poubelles...")
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PoubelleAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw PoubelleAPIError.httpError(httpResponse.statusCode)
            }
            
            let geoJsonResponse = try JSONDecoder().decode(PoubelleGeoJSONResponse.self, from: data)
            
            print("📊 Total poubelles reçues (fallback): \(geoJsonResponse.features.count)")
            
            let allPoubelleLocations = geoJsonResponse.features.compactMap { feature -> PoubelleLocation? in
                guard feature.geometry.coordinates.count >= 2 else { return nil }
                
                let longitude = feature.geometry.coordinates[0]
                let latitude = feature.geometry.coordinates[1]
                let props = feature.properties
                
                return PoubelleLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    name: props.nom ?? "Poubelle publique",
                    address: formatAddress(props),
                    gestionnaire: props.gestionnaire ?? "Non spécifié",
                    isAccessible: props.acces_pmr == "Oui" || props.acces_pmr == "oui",
                    type: props.type_corbeille ?? "",
                    capacite: props.capacite,
                    commune: props.commune ?? ""
                )
            }
            
            // ✅ METTRE À JOUR LE CACHE GLOBAL
            Self.globalPoubellesCache = allPoubelleLocations
            Self.globalCacheTimestamp = Date()
            
            print("🌍 Cache global mis à jour avec \(allPoubelleLocations.count) poubelles")
            
            // ✅ Filtrer par distance côté client (rayon 800m)
            let nearbyPoubelleLocations = allPoubelleLocations
                .map { poubelle in
                    let distance = location.distanceToPoubelle(poubelle.coordinate)
                    return (poubelle: poubelle, distance: distance)
                }
                .filter { $0.distance <= 800 } // ✅ Rayon de 800m
                .sorted { $0.distance < $1.distance }
                .map { $0.poubelle }
            
            let limitedPoubelles = Array(nearbyPoubelleLocations.prefix(maxPoubellesToShow))
            
            // ✅ Mettre en cache
            let zoneKey = generateZoneKey(for: location)
            zoneCache[zoneKey] = CachedZone(
                poubelles: nearbyPoubelleLocations,
                timestamp: Date(),
                centerLocation: location
            )
            
            nearbyPoubelles = limitedPoubelles
            isLoading = false
            
            print("✅ Fallback réussi: \(limitedPoubelles.count) poubelles proches trouvées")
            
        } catch {
            errorMessage = "Erreur de chargement (fallback): \(error.localizedDescription)"
            isLoading = false
            print("❌ Erreur fallback: \(error)")
        }
    }
    
    // ✅ GÉNÉRATION DE CLÉ DE ZONE
    private func generateZoneKey(for location: CLLocationCoordinate2D) -> String {
        let gridSize = 0.01 // ~1km de grille
        let gridLat = Int(location.latitude / gridSize)
        let gridLon = Int(location.longitude / gridSize)
        return "zone_\(gridLat)_\(gridLon)"
    }
    
    private func formatAddress(_ props: PoubelleProperties) -> String {
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

// MARK: - ✅ SECTION POUBELLES PROCHES AMÉLIORÉE
struct NearestPoubellseView: View {
    let poubelles: [PoubelleLocation]
    let referenceLocation: CLLocationCoordinate2D
    let isSearchMode: Bool
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isSearchMode ? "Poubelles proches de votre recherche" : "Poubelles les plus proches")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSearchMode {
                    Text("")
                        .font(.title2)
                } else {
                    Text("")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            VStack(spacing: 8) {
                ForEach(poubelles) { poubelle in
                    NearestPoubelleRowView(
                        poubelle: poubelle,
                        referenceLocation: referenceLocation,
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

struct NearestPoubelleRowView: View {
    let poubelle: PoubelleLocation
    let referenceLocation: CLLocationCoordinate2D
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    private var distance: String {
        let referenceCLLocation = CLLocation(latitude: referenceLocation.latitude, longitude: referenceLocation.longitude)
        let poubelleLocation = CLLocation(latitude: poubelle.coordinate.latitude, longitude: poubelle.coordinate.longitude)
        let distanceInMeters = referenceCLLocation.distance(from: poubelleLocation)
        
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
                Image("Poubelle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(themeColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(poubelle.address)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
                
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
                openNavigationToPoubelle()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers cette poubelle ?")
        }
    }
    
    private func openNavigationToPoubelle() {
        let coordinate = poubelle.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = poubelle.address
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation à pied lancée vers: \(poubelle.address)")
    }
}

// MARK: - Composants UI optimisés

struct PoubelleMapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let poubelles: [PoubelleLocation]
    let mapAnnotations: [PoubelleMapAnnotationItem]
    let userLocation: CLLocationCoordinate2D?
    let searchedLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    let isSearchMode: Bool
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if isSearchMode {
                    Text("Poubelles autour de votre recherche (\(poubelles.count))")
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("Poubelles autour de vous (\(poubelles.count))")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(themeColor)
                    }
                    
                    Button(action: {
                        centerOnCurrentFocus()
                    }) {
                        HStack(spacing: 4) {
                            Group {
                                if isSearchMode {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.blue)
                                } else if userLocation != nil {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "location.slash")
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Text(isSearchMode ? "Recherche" : "Ma position")
                                .font(.caption)
                        }
                        .foregroundColor(isSearchMode ? .blue : (userLocation != nil ? .green : .orange))
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
            
            Map(coordinateRegion: $region,
                interactionModes: [.pan, .zoom],
                showsUserLocation: true,
                annotationItems: mapAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if let poubelle = annotation.poubelle {
                        PoubelleMarkerView(poubelle: poubelle, themeColor: themeColor)
                            .id("poubelle-\(poubelle.id)")
                    } else if annotation.isSearchResult {
                        PoubelleSearchPinMarker()
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
    
    private func centerOnCurrentFocus() {
        let targetLocation: CLLocationCoordinate2D?
        
        if isSearchMode, let searchLocation = searchedLocation {
            targetLocation = searchLocation
        } else {
            targetLocation = userLocation
        }
        
        guard let location = targetLocation else {
            print("🔄 Aucune position disponible pour le centrage")
            return
        }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = location
            region.span = MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        }
        
        print("🎯 Carte centrée sur \(isSearchMode ? "recherche" : "position utilisateur")")
    }
}

struct PoubelleMapAnnotationItem: Identifiable {
    let id = UUID()
    let poubelle: PoubelleLocation?
    let coordinate: CLLocationCoordinate2D
    let isSearchResult: Bool
    
    init(poubelle: PoubelleLocation?, coordinate: CLLocationCoordinate2D, isSearchResult: Bool) {
        self.poubelle = poubelle
        self.coordinate = coordinate
        self.isSearchResult = isSearchResult
    }
}

// MARK: - Composants UI spécifiques aux poubelles

struct PoubelleSmartSearchBarView: View {
    @Binding var searchText: String
    let suggestions: [PoubelleAddressSuggestion]
    @Binding var showSuggestions: Bool
    let onSearchTextChanged: (String) -> Void
    let onSuggestionTapped: (PoubelleAddressSuggestion) -> Void
    let onSearchSubmitted: () -> Void
    let onClearSearch: () -> Void
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
                Button("✕") {
                    onClearSearch()
                }
                .foregroundColor(themeColor)
                .font(.caption)
                .padding(.horizontal, 4)
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

struct PoubelleSuggestionsListView: View {
    let suggestions: [PoubelleAddressSuggestion]
    let onSuggestionTapped: (PoubelleAddressSuggestion) -> Void
    
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

struct PoubelleLoadingOverlayView: View {
    let themeColor: Color
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(themeColor)
                
                Text("Chargement des poubelles proches...")
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

struct PoubelleErrorOverlayView: View {
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

struct PoubelleMarkerView: View {
    let poubelle: PoubelleLocation
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    var body: some View {
        Button(action: {
            showNavigationAlert = true
        }) {
            Image("Poubelle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .foregroundColor(themeColor)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
        }
        .alert("Navigation", isPresented: $showNavigationAlert) {
            Button("Ouvrir dans Plans") {
                openInMaps()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers cette poubelle ?")
        }
    }
    
    private func openInMaps() {
        let coordinate = poubelle.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = poubelle.name
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation lancée vers: \(poubelle.name)")
    }
}

struct PoubelleSearchPinMarker: View {
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

// MARK: - Modèles de données

struct PoubelleLocation: Identifiable {
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

struct PoubelleGeoJSONResponse: Codable {
    let type: String
    let features: [PoubelleFeature]
    let totalFeatures: Int?
}

struct PoubelleFeature: Codable {
    let type: String
    let geometry: PoubelleGeometry
    let properties: PoubelleProperties
}

struct PoubelleGeometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct PoubelleProperties: Codable {
    let gid: Int?
    let nom: String?
    let adresse: String?
    let code_postal: String?
    let commune: String?
    let gestionnaire: String?
    let acces_pmr: String?
    let type_corbeille: String?
    let capacite: String?
}

// MARK: - Modèle local pour éviter les conflits
struct PoubelleAddressSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

enum PoubelleAPIError: Error, LocalizedError {
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

// MARK: - Extensions pour les calculs de distance (PoubelleMapView)

extension CLLocationCoordinate2D {
    func distanceToPoubelle(_ coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}

#Preview {
    PoubelleMapView()
}
