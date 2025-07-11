import SwiftUI
import MapKit
import Foundation

// MARK: - CompostMapView ultra-optimisé avec filtrage géographique
struct CompostMapView: View {
    @StateObject private var compostService = OptimizedCompostAPIService()
    @StateObject private var locationService = GlobalLocationService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    
    // ✅ Region initialisée avec position utilisateur, zoom serré
    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var addressSuggestions: [CompostAddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?
    
    // ✅ État pour gérer le focus actuel (utilisateur ou recherche)
    @State private var focusLocation: CLLocationCoordinate2D?
    @State private var isSearchMode = false
    @State private var showInfoModal = false // ✅ Nouvelle variable pour la bulle info
    
    // ✅ COULEUR UNIFIÉE COMPOST
    private let compostThemeColor = Color(red: 0.5, green: 0.35, blue: 0.25)
    
    // ✅ Location actuelle à utiliser (utilisateur ou recherche)
    private var currentFocusLocation: CLLocationCoordinate2D? {
        if isSearchMode, let searchLocation = searchedLocation {
            return searchLocation
        }
        return locationService.userLocation
    }
    
    // ✅ Computed property pour les bornes proches du focus actuel
    private var nearbyCompostBins: [CompostLocation] {
        return compostService.nearbyCompostBins
    }
    
    // ✅ Computed property pour les 3 bornes les plus proches (section)
    private var topThreeCompostBins: [CompostLocation] {
        return Array(nearbyCompostBins.prefix(3))
    }
    
    // ✅ Computed property pour les annotations
    private var mapAnnotations: [CompostMapAnnotationItem] {
        var annotations: [CompostMapAnnotationItem] = []
        
        // Afficher les bornes proches
        for bin in nearbyCompostBins {
            annotations.append(CompostMapAnnotationItem(
                compostBin: bin,
                coordinate: bin.coordinate,
                isSearchResult: false
            ))
        }
        
        // Ajouter le pin de recherche si présent
        if let searchedLocation = searchedLocation {
            annotations.append(CompostMapAnnotationItem(
                compostBin: nil,
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
            print("🎯 Compost: Initialisation avec position utilisateur")
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
            print("🏛️ Compost: Initialisation avec Bellecour (fallback)")
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
                        Image("Compost")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(compostThemeColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text("Bornes à Compost")
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
                                        .foregroundColor(compostThemeColor)
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
                            Text("La carte renvoie les 50 bornes les plus proches dans un rayon de 800m autour de l'utilisateur ou du point de recherche sur les 2 701 bornes à compost référencées.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(compostThemeColor.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(compostThemeColor.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // ✅ Barre de recherche améliorée
                    VStack(spacing: 0) {
                        CompostSmartSearchBarView(
                            searchText: $searchText,
                            suggestions: addressSuggestions,
                            showSuggestions: $showSuggestions,
                            onSearchTextChanged: handleSearchTextChange,
                            onSuggestionTapped: handleSuggestionTap,
                            onSearchSubmitted: handleSearchSubmitted,
                            onClearSearch: handleClearSearch,
                            themeColor: compostThemeColor
                        )
                        
                        if showSuggestions && !addressSuggestions.isEmpty {
                            CompostSuggestionsListView(
                                suggestions: addressSuggestions,
                                onSuggestionTapped: handleSuggestionTap
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Carte optimisée
                    CompostMapBoxView(
                        region: $region,
                        compostBins: nearbyCompostBins,
                        mapAnnotations: mapAnnotations,
                        userLocation: locationService.userLocation,
                        searchedLocation: searchedLocation,
                        isLoading: compostService.isLoading,
                        isSearchMode: isSearchMode,
                        themeColor: compostThemeColor
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Section des 3 bornes les plus proches
                    if !topThreeCompostBins.isEmpty {
                        NearestCompostBinsView(
                            compostBins: topThreeCompostBins,
                            referenceLocation: currentFocusLocation ?? region.center,
                            isSearchMode: isSearchMode,
                            themeColor: compostThemeColor
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
                themeColor: compostThemeColor
            )
        }
        .onAppear {
            navigationManager.currentDestination = "compost"
            setupInitialLocation()
        }
        .onDisappear {
            locationService.stopLocationUpdates()
        }
        .onChange(of: locationService.isLocationReady) { isReady in
            if isReady, let location = locationService.userLocation, !isSearchMode {
                centerMapOnLocation(location)
                Task {
                    await compostService.loadCompostBinsAroundLocation(location)
                }
            }
        }
        .overlay {
            if compostService.isLoading && compostService.nearbyCompostBins.isEmpty {
                CompostLoadingOverlayView(themeColor: compostThemeColor)
            }
        }
        .overlay {
            if let errorMessage = compostService.errorMessage {
                CompostErrorOverlayView(message: errorMessage, themeColor: compostThemeColor) {
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
    
    private func handleSuggestionTap(_ suggestion: CompostAddressSuggestion) {
        searchText = suggestion.title
        showSuggestions = false
        
        // ✅ ACTIVER LE MODE RECHERCHE
        isSearchMode = true
        searchedLocation = suggestion.coordinate
        focusLocation = suggestion.coordinate
        
        // ✅ CHARGER LES BORNES AUTOUR DE LA RECHERCHE
        Task {
            await compostService.loadCompostBinsAroundLocation(suggestion.coordinate)
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
                
                await compostService.loadCompostBinsAroundLocation(coordinate)
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
                await compostService.loadCompostBinsAroundLocation(userLocation)
            }
            print("🏠 Retour au mode utilisateur")
        }
    }
    
    // MARK: - Fonctions conservées et optimisées
    
    private func setupInitialLocation() {
        print("🗺️ Setup initial - compost optimisé")
        
        if let userLocation = locationService.userLocation {
            focusLocation = userLocation
            Task {
                await compostService.loadCompostBinsAroundLocation(userLocation)
            }
        } else {
            locationService.refreshLocation()
        }
    }
    
    private func refreshCurrentLocation() async {
        if let currentLocation = currentFocusLocation {
            await compostService.loadCompostBinsAroundLocation(currentLocation)
        }
    }
    
    private func centerMapOnLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        }
    }
    
    // MARK: - Fonctions de géocodage (corrigées)
    private func searchAddresses(query: String) async -> [CompostAddressSuggestion] {
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
                    CompostAddressSuggestion(
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
class OptimizedCompostAPIService: ObservableObject {
    @Published var nearbyCompostBins: [CompostLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // ✅ Cache intelligent par zones avec expiration longue
    private var zoneCache: [String: CachedZone] = [:]
    private let cacheExpiryTime: TimeInterval = 3600 // ✅ 1 heure au lieu de 5 minutes
    private let maxCompostBinsToShow = 50
    
    // ✅ Cache global pour éviter les requêtes répétées
    private static var globalCompostCache: [CompostLocation] = []
    private static var globalCacheTimestamp: Date = Date.distantPast
    private static let globalCacheExpiry: TimeInterval = 86400 // 24 heures
    
    struct CachedZone {
        let compostBins: [CompostLocation]
        let timestamp: Date
        let centerLocation: CLLocationCoordinate2D
    }
    
    // ✅ FONCTION PRINCIPALE - AVEC CACHE GLOBAL
    func loadCompostBinsAroundLocation(_ location: CLLocationCoordinate2D) async {
        // ✅ VÉRIFIER LE CACHE GLOBAL D'ABORD
        if !Self.globalCompostCache.isEmpty,
           Date().timeIntervalSince(Self.globalCacheTimestamp) < Self.globalCacheExpiry {
            
            // Utiliser le cache global et filtrer localement
            let nearbyCompostBins = Self.globalCompostCache
                .map { bin in
                    let distance = location.distanceToCompost(bin.coordinate)
                    return (bin: bin, distance: distance)
                }
                .filter { $0.distance <= 800 }
                .sorted { $0.distance < $1.distance }
                .map { $0.bin }
            
            self.nearbyCompostBins = Array(nearbyCompostBins.prefix(maxCompostBinsToShow))
            print("🌍 Cache global utilisé: \(self.nearbyCompostBins.count) bornes trouvées")
            return
        }
        
        // ✅ VÉRIFIER LE CACHE LOCAL
        let zoneKey = generateZoneKey(for: location)
        if let cachedZone = zoneCache[zoneKey],
           Date().timeIntervalSince(cachedZone.timestamp) < cacheExpiryTime,
           cachedZone.centerLocation.distanceToCompost(location) < 200 {
            
            nearbyCompostBins = Array(cachedZone.compostBins.prefix(maxCompostBinsToShow))
            print("📦 Cache local utilisé: \(nearbyCompostBins.count) bornes depuis le cache")
            return
        }
        
        // ✅ CHARGER DEPUIS L'API SEULEMENT SI NÉCESSAIRE
        await loadCompostBinsFromAPIFallback(around: location)
    }
    
    // ✅ CHARGEMENT OPTIMISÉ AVEC BBOX ET DEBUG
    private func loadCompostBinsFromAPI(around location: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // ✅ ESSAYER D'ABORD AVEC BBOX
            let optimizedURL = buildOptimizedURL(center: location, radiusMeters: 800)
            
            guard let url = URL(string: optimizedURL) else {
                throw CompostAPIError.invalidURL
            }
            
            print("🌐 URL générée: \(optimizedURL)")
            print("🎯 Coordonnées: lat=\(location.latitude), lon=\(location.longitude)")
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CompostAPIError.invalidResponse
            }
            
            print("📡 Status HTTP: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Erreur HTTP \(httpResponse.statusCode), essai avec requête complète...")
                await loadCompostBinsFromAPIFallback(around: location)
                return
            }
            
            let geoJsonResponse = try JSONDecoder().decode(CompostGeoJSONResponse.self, from: data)
            
            print("📊 Features reçues: \(geoJsonResponse.features.count)")
            
            // ✅ SI PAS DE RÉSULTATS AVEC BBOX, ESSAYER SANS BBOX
            if geoJsonResponse.features.isEmpty {
                print("⚠️ Aucun résultat avec BBOX, essai sans filtrage...")
                await loadCompostBinsFromAPIFallback(around: location)
                return
            }
            
            let compostLocations = geoJsonResponse.features.compactMap { feature -> CompostLocation? in
                guard feature.geometry.coordinates.count >= 2 else { return nil }
                
                let longitude = feature.geometry.coordinates[0]
                let latitude = feature.geometry.coordinates[1]
                let props = feature.properties
                
                return CompostLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    identifiant: props.identifiant ?? "Non spécifié",
                    address: formatAddress(props),
                    commune: props.commune ?? "Non spécifiée",
                    gestionnaire: props.gestionnaire ?? "Non spécifié",
                    collecteur: props.collecteur ?? "Non spécifié",
                    numeroCircuit: props.numerocircuit ?? "",
                    observationLocalisante: props.observation_localisante ?? "",
                    dateDebutExploitation: props.datedebutexploitation ?? "",
                    insee: props.insee ?? ""
                )
            }
            
            print("🏗️ Bornes créées: \(compostLocations.count)")
            
            // ✅ Trier par distance et limiter
            let sortedCompostBins = compostLocations
                .map { bin in
                    let distance = location.distanceToCompost(bin.coordinate)
                    return (bin: bin, distance: distance)
                }
                .sorted { $0.distance < $1.distance }
                .map { $0.bin }
            
            let limitedCompostBins = Array(sortedCompostBins.prefix(maxCompostBinsToShow))
            
            // ✅ Mettre en cache
            let zoneKey = generateZoneKey(for: location)
            zoneCache[zoneKey] = CachedZone(
                compostBins: sortedCompostBins,
                timestamp: Date(),
                centerLocation: location
            )
            
            nearbyCompostBins = limitedCompostBins
            isLoading = false
            
            print("✅ \(limitedCompostBins.count) bornes chargées et triées par distance")
            
        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            isLoading = false
            print("❌ Erreur chargement bornes: \(error)")
            
            // ✅ ESSAYER EN FALLBACK SI ERREUR
            print("🔄 Tentative de fallback...")
            await loadCompostBinsFromAPIFallback(around: location)
        }
    }
    
    // ✅ MÉTHODE FALLBACK SANS BBOX
    private func loadCompostBinsFromAPIFallback(around location: CLLocationCoordinate2D) async {
        do {
            let fallbackURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gic_collecte.bornecompost&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
            
            guard let url = URL(string: fallbackURL) else {
                throw CompostAPIError.invalidURL
            }
            
            print("🔄 Fallback: chargement de toutes les bornes...")
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CompostAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw CompostAPIError.httpError(httpResponse.statusCode)
            }
            
            let geoJsonResponse = try JSONDecoder().decode(CompostGeoJSONResponse.self, from: data)
            
            print("📊 Total bornes reçues (fallback): \(geoJsonResponse.features.count)")
            
            let allCompostLocations = geoJsonResponse.features.compactMap { feature -> CompostLocation? in
                guard feature.geometry.coordinates.count >= 2 else { return nil }
                
                let longitude = feature.geometry.coordinates[0]
                let latitude = feature.geometry.coordinates[1]
                let props = feature.properties
                
                return CompostLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    identifiant: props.identifiant ?? "Non spécifié",
                    address: formatAddress(props),
                    commune: props.commune ?? "Non spécifiée",
                    gestionnaire: props.gestionnaire ?? "Non spécifié",
                    collecteur: props.collecteur ?? "Non spécifié",
                    numeroCircuit: props.numerocircuit ?? "",
                    observationLocalisante: props.observation_localisante ?? "",
                    dateDebutExploitation: props.datedebutexploitation ?? "",
                    insee: props.insee ?? ""
                )
            }
            
            // ✅ METTRE À JOUR LE CACHE GLOBAL
            Self.globalCompostCache = allCompostLocations
            Self.globalCacheTimestamp = Date()
            
            print("🌍 Cache global mis à jour avec \(allCompostLocations.count) bornes")
            
            // ✅ Filtrer par distance côté client (rayon 800m)
            let nearbyCompostLocations = allCompostLocations
                .map { bin in
                    let distance = location.distanceToCompost(bin.coordinate)
                    return (bin: bin, distance: distance)
                }
                .filter { $0.distance <= 800 } // ✅ Rayon de 800m
                .sorted { $0.distance < $1.distance }
                .map { $0.bin }
            
            let limitedCompostBins = Array(nearbyCompostLocations.prefix(maxCompostBinsToShow))
            
            // ✅ Mettre en cache
            let zoneKey = generateZoneKey(for: location)
            zoneCache[zoneKey] = CachedZone(
                compostBins: nearbyCompostLocations,
                timestamp: Date(),
                centerLocation: location
            )
            
            nearbyCompostBins = limitedCompostBins
            isLoading = false
            
            print("✅ Fallback réussi: \(limitedCompostBins.count) bornes proches trouvées")
            
        } catch {
            errorMessage = "Erreur de chargement (fallback): \(error.localizedDescription)"
            isLoading = false
            print("❌ Erreur fallback: \(error)")
        }
    }
    
    // ✅ CONSTRUCTION D'URL AVEC BBOX POUR FILTRER GÉOGRAPHIQUEMENT (DEBUG)
    private func buildOptimizedURL(center: CLLocationCoordinate2D, radiusMeters: Double) -> String {
        let bbox = calculateBoundingBox(center: center, radiusMeters: radiusMeters)
        
        print("🧮 BBOX calculé: \(bbox)")
        
        let baseURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows"
        let params = [
            "SERVICE=WFS",
            "VERSION=2.0.0",
            "request=GetFeature",
            "typename=metropole-de-lyon:gic_collecte.bornecompost",
            "outputFormat=application/json",
            "SRSNAME=EPSG:4171",
            "BBOX=\(bbox)",
            "maxFeatures=100" // ✅ Augmenté pour avoir plus de choix dans la zone
        ].joined(separator: "&")
        
        let fullURL = "\(baseURL)?\(params)"
        print("🔗 URL complète: \(fullURL)")
        
        return fullURL
    }
    
    // ✅ CALCUL DE BOUNDING BOX (AMÉLIORÉ)
    private func calculateBoundingBox(center: CLLocationCoordinate2D, radiusMeters: Double) -> String {
        // Conversion plus précise mètres -> degrés
        let metersPerDegreeLat = 111000.0
        let metersPerDegreeLon = 111000.0 * cos(center.latitude * .pi / 180)
        
        let deltaLat = radiusMeters / metersPerDegreeLat
        let deltaLon = radiusMeters / metersPerDegreeLon
        
        let minLon = center.longitude - deltaLon
        let minLat = center.latitude - deltaLat
        let maxLon = center.longitude + deltaLon
        let maxLat = center.latitude + deltaLat
        
        print("🌍 Centre: (\(center.latitude), \(center.longitude))")
        print("📐 Deltas: lat=\(deltaLat), lon=\(deltaLon)")
        print("📦 Bounds: minLat=\(minLat), minLon=\(minLon), maxLat=\(maxLat), maxLon=\(maxLon)")
        
        return "\(minLon),\(minLat),\(maxLon),\(maxLat)"
    }
    
    // ✅ GÉNÉRATION DE CLÉ DE ZONE
    private func generateZoneKey(for location: CLLocationCoordinate2D) -> String {
        let gridSize = 0.01 // ~1km de grille
        let gridLat = Int(location.latitude / gridSize)
        let gridLon = Int(location.longitude / gridSize)
        return "zone_\(gridLat)_\(gridLon)"
    }
    
    private func formatAddress(_ props: CompostProperties) -> String {
        if let adresse = props.adresse, !adresse.isEmpty {
            var fullAddress = adresse
            
            if let commune = props.commune, !commune.isEmpty {
                fullAddress += ", \(commune)"
            }
            
            return fullAddress
        }
        
        // Fallback si pas d'adresse principale
        var addressParts: [String] = []
        
        if let commune = props.commune, !commune.isEmpty {
            addressParts.append(commune)
        }
        
        if let identifiant = props.identifiant, !identifiant.isEmpty {
            addressParts.append("ID: \(identifiant)")
        }
        
        return addressParts.isEmpty ? "Adresse non disponible" : addressParts.joined(separator: ", ")
    }
}

// MARK: - ✅ SECTION BORNES PROCHES AMÉLIORÉE
struct NearestCompostBinsView: View {
    let compostBins: [CompostLocation]
    let referenceLocation: CLLocationCoordinate2D
    let isSearchMode: Bool
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isSearchMode ? "Bornes proches de votre recherche" : "Bornes les plus proches")
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
                ForEach(compostBins) { bin in
                    NearestCompostBinRowView(
                        compostBin: bin,
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

struct NearestCompostBinRowView: View {
    let compostBin: CompostLocation
    let referenceLocation: CLLocationCoordinate2D
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    private var distance: String {
        let referenceCLLocation = CLLocation(latitude: referenceLocation.latitude, longitude: referenceLocation.longitude)
        let binLocation = CLLocation(latitude: compostBin.coordinate.latitude, longitude: compostBin.coordinate.longitude)
        let distanceInMeters = referenceCLLocation.distance(from: binLocation)
        
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
                Image("Compost")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(themeColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(compostBin.address)
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
                openNavigationToCompostBin()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers cette borne à compost ?")
        }
    }
    
    private func openNavigationToCompostBin() {
        let coordinate = compostBin.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = compostBin.address
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation à pied lancée vers: \(compostBin.address)")
    }
}

// MARK: - Composants UI optimisés

struct CompostMapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let compostBins: [CompostLocation]
    let mapAnnotations: [CompostMapAnnotationItem]
    let userLocation: CLLocationCoordinate2D?
    let searchedLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    let isSearchMode: Bool
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if isSearchMode {
                    Text("Bornes autour de votre recherche (\(compostBins.count))")
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("Bornes autour de vous (\(compostBins.count))")
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
                    if let compostBin = annotation.compostBin {
                        CompostMarkerView(compostBin: compostBin, themeColor: themeColor)
                            .id("compost-\(compostBin.id)")
                    } else if annotation.isSearchResult {
                        CompostSearchPinMarker()
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

struct CompostMapAnnotationItem: Identifiable {
    let id = UUID()
    let compostBin: CompostLocation?
    let coordinate: CLLocationCoordinate2D
    let isSearchResult: Bool
    
    init(compostBin: CompostLocation?, coordinate: CLLocationCoordinate2D, isSearchResult: Bool) {
        self.compostBin = compostBin
        self.coordinate = coordinate
        self.isSearchResult = isSearchResult
    }
}

// MARK: - Composants UI spécifiques aux bornes compost

struct CompostSmartSearchBarView: View {
    @Binding var searchText: String
    let suggestions: [CompostAddressSuggestion]
    @Binding var showSuggestions: Bool
    let onSearchTextChanged: (String) -> Void
    let onSuggestionTapped: (CompostAddressSuggestion) -> Void
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

struct CompostSuggestionsListView: View {
    let suggestions: [CompostAddressSuggestion]
    let onSuggestionTapped: (CompostAddressSuggestion) -> Void
    
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

struct CompostLoadingOverlayView: View {
    let themeColor: Color
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(themeColor)
                
                Text("Chargement des bornes proches...")
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

struct CompostErrorOverlayView: View {
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

struct CompostMarkerView: View {
    let compostBin: CompostLocation
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    var body: some View {
        Button(action: {
            showNavigationAlert = true
        }) {
            Image("Compost")
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
            Text("Voulez-vous ouvrir la navigation vers cette borne à compost ?")
        }
    }
    
    private func openInMaps() {
        let coordinate = compostBin.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = compostBin.address
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation lancée vers: \(compostBin.address)")
    }
}

struct CompostSearchPinMarker: View {
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

struct CompostLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let identifiant: String
    let address: String
    let commune: String
    let gestionnaire: String
    let collecteur: String
    let numeroCircuit: String
    let observationLocalisante: String
    let dateDebutExploitation: String
    let insee: String
}

struct CompostGeoJSONResponse: Codable {
    let type: String
    let features: [CompostFeature]
    let totalFeatures: Int?
}

struct CompostFeature: Codable {
    let type: String
    let geometry: CompostGeometry
    let properties: CompostProperties
}

struct CompostGeometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct CompostProperties: Codable {
    let idemplacementsilo: String?
    let identifiant: String?
    let adresse: String?
    let commune: String?
    let codefuv: String?
    let observation_localisante: String?
    let numerocircuit: String?
    let gestionnaire: String?
    let collecteur: String?
    let datedebutexploitation: String?
    let datecreation: String?
    let maj_alphanumerique: String?
    let maj_geometrie: String?
    let insee: String?
    let gid: Int?
}

// MARK: - Modèle local pour éviter les conflits
struct CompostAddressSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

enum CompostAPIError: Error, LocalizedError {
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

// MARK: - Extensions pour les calculs de distance (CompostMapView)

extension CLLocationCoordinate2D {
    func distanceToCompost(_ coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}

#Preview {
    CompostMapView()
}
