import SwiftUI
import MapKit
import Foundation

// MARK: - BancsMapView avec structure identique à ContentView
struct BancsMapView: View {
    @StateObject private var bancService = BancAPIService()
    @StateObject private var locationService = GlobalLocationService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    @StateObject private var clusteringService = BancClusteringService()
    
    // ✅ Region initialisée avec position utilisateur si disponible
    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var addressSuggestions: [AddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?
    @State private var selectedCluster: BancCluster?
    @State private var showDetailedBancs = false
    
    // ✅ COULEUR UNIFIÉE
    private let bancThemeColor = Color(red: 0.7, green: 0.5, blue: 0.4)
    
    // ✅ Computed property pour les 3 bancs les plus proches
    private var nearestBancs: [BancLocation] {
        guard let userLocation = locationService.userLocation else { return [] }
        
        return bancService.bancs
            .map { banc in
                let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    .distance(from: CLLocation(latitude: banc.coordinate.latitude, longitude: banc.coordinate.longitude))
                return (banc: banc, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(3)
            .map { $0.banc }
    }
    
    // ✅ Computed property pour les annotations clusterisées
    private var clusteredAnnotations: [BancMapAnnotationItem] {
        let clusters = clusteringService.clusterBancs(bancService.bancs, for: region)
        var annotations: [BancMapAnnotationItem] = []
        
        // Vérifier si on doit afficher les détails d'un cluster
        let shouldShowDetails = showDetailedBancs && selectedCluster != nil
        
        if shouldShowDetails, let selectedCluster = selectedCluster {
            // Afficher uniquement les bancs du cluster sélectionné
            for banc in selectedCluster.bancs {
                annotations.append(BancMapAnnotationItem(
                    banc: banc,
                    coordinate: banc.coordinate,
                    isSearchResult: false,
                    isCluster: false,
                    clusterCount: 0,
                    clusterBancs: []
                ))
            }
        } else {
            // Affichage normal avec clusters
            for cluster in clusters {
                if cluster.bancs.count > 1 {
                    // Cluster avec plusieurs bancs
                    annotations.append(BancMapAnnotationItem(
                        banc: nil,
                        coordinate: cluster.centerCoordinate,
                        isSearchResult: false,
                        isCluster: true,
                        clusterCount: cluster.bancs.count,
                        clusterBancs: cluster.bancs,
                        clusterId: cluster.id
                    ))
                } else if let singleBanc = cluster.bancs.first {
                    // Banc isolé
                    annotations.append(BancMapAnnotationItem(
                        banc: singleBanc,
                        coordinate: singleBanc.coordinate,
                        isSearchResult: false,
                        isCluster: false,
                        clusterCount: 0,
                        clusterBancs: []
                    ))
                }
            }
        }
        
        // Ajouter le pin de recherche si présent
        if let searchedLocation = searchedLocation {
            annotations.append(BancMapAnnotationItem(
                banc: nil,
                coordinate: searchedLocation,
                isSearchResult: true,
                isCluster: false,
                clusterCount: 0,
                clusterBancs: []
            ))
        }
        
        return annotations
    }
    
    // ✅ Initializer personnalisé
    init() {
        let initialCenter: CLLocationCoordinate2D
        if let userLocation = GlobalLocationService.shared.userLocation {
            initialCenter = userLocation
            print("🎯 Bancs: Initialisation avec position utilisateur")
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
            print("🏛️ Bancs: Initialisation avec Bellecour (fallback)")
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
                        Image("Banc")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(bancThemeColor)
                        
                        Text("Bancs Publics")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // ✅ Barre de recherche
                    VStack(spacing: 0) {
                        BancSmartSearchBarView(
                            searchText: $searchText,
                            suggestions: addressSuggestions,
                            showSuggestions: $showSuggestions,
                            onSearchTextChanged: handleSearchTextChange,
                            onSuggestionTapped: handleSuggestionTap,
                            onSearchSubmitted: handleSearchSubmitted,
                            themeColor: bancThemeColor
                        )
                        
                        if showSuggestions && !addressSuggestions.isEmpty {
                            BancSuggestionsListView(
                                suggestions: addressSuggestions,
                                onSuggestionTapped: handleSuggestionTap
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Carte avec clustering
                    BancMapBoxView(
                        region: $region,
                        bancs: bancService.bancs,
                        clusteredAnnotations: clusteredAnnotations,
                        userLocation: locationService.userLocation,
                        searchedLocation: searchedLocation,
                        isLoading: bancService.isLoading,
                        themeColor: bancThemeColor,
                        onClusterTapped: handleClusterTap
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .onChange(of: region) { newRegion in
                        // Recalculer les clusters quand la région change
                        clusteringService.updateClustering()
                        
                        // Vérifier si on doit masquer les détails (zoom out de plus de 100m)
                        if showDetailedBancs, let selectedCluster = selectedCluster {
                            let currentDistance = calculateDistanceFromCenter(to: selectedCluster.centerCoordinate, in: newRegion)
                            if currentDistance > 100 {
                                showDetailedBancs = false
                                self.selectedCluster = nil
                                print("🔍 Zoom out détecté, masquage des détails du cluster")
                            }
                        }
                    }
                    
                    // ✅ Section des 3 bancs les plus proches
                    if !nearestBancs.isEmpty && locationService.userLocation != nil {
                        NearestBancsView(
                            bancs: nearestBancs,
                            userLocation: locationService.userLocation!,
                            themeColor: bancThemeColor
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
                await bancService.loadBancs()
            }
            
            // ✅ MENU DIRECTEMENT DANS LE ZSTACK - COMME CONTENTVIEW
            FixedBottomMenuView(
                isMenuExpanded: $navigationManager.isMenuExpanded,
                showToiletsMap: $navigationManager.showToiletsMap,  // ✅ CORRIGÉ
                showBancsMap: $navigationManager.showBancsMap,      // ✅ CORRIGÉ
                onHomeSelected: {
                    navigationManager.navigateToHome()              // ✅ CORRIGÉ
                },
                themeColor: Color(red: 0.7, green: 0.5, blue: 0.4)
            )
            .onAppear {
                navigationManager.currentDestination = "bancs"
                setupInitialLocation()
                loadBancs()
            }
            .onDisappear {
                locationService.stopLocationUpdates()
            }
            .onChange(of: locationService.isLocationReady) { isReady in
                if isReady, let location = locationService.userLocation {
                    centerMapOnLocation(location)
                    print("📍 Bancs: Position mise à jour automatiquement")
                }
            }
            
            .overlay {
                if bancService.isLoading && bancService.bancs.isEmpty {
                    BancLoadingOverlayView(themeColor: bancThemeColor)
                }
            }
            .overlay {
                if let errorMessage = bancService.errorMessage {
                    BancErrorOverlayView(message: errorMessage, themeColor: bancThemeColor) {
                        loadBancs()
                    }
                }
            }
        }
    }
    
    // MARK: - ✅ NOUVELLE FONCTION POUR GÉRER LE TAP SUR CLUSTER
    private func handleClusterTap(_ cluster: BancCluster) {
        selectedCluster = cluster
        showDetailedBancs = true
        
        // Zoomer sur le cluster avec une vue détaillée
        let clusterRegion = MKCoordinateRegion(
            center: cluster.centerCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002) // Zoom très proche
        )
        
        withAnimation(.easeInOut(duration: 0.6)) {
            region = clusterRegion
        }
        
        print("🎯 Zoom sur cluster: \(cluster.bancs.count) bancs à afficher en détail")
    }
    
    // MARK: - ✅ FONCTION POUR CALCULER LA DISTANCE DEPUIS LE CENTRE
    private func calculateDistanceFromCenter(to coordinate: CLLocationCoordinate2D, in region: MKCoordinateRegion) -> Double {
        let regionCenter = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return regionCenter.distance(from: targetLocation)
    }
    
    // MARK: - Fonctions optimisées (inchangées)
    
    private func setupInitialLocation() {
        print("🗺️ Setup initial - bancs")
        
        if locationService.userLocation == nil {
            print("🔄 Position pas encore disponible, refresh en cours...")
            locationService.refreshLocation()
        } else {
            print("✅ Position déjà disponible depuis l'init")
        }
    }
    
    private func loadBancs() {
        Task {
            await bancService.loadBancs()
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

// MARK: - ✅ NOUVEAU SERVICE DE CLUSTERING
@MainActor
class BancClusteringService: ObservableObject {
    private var lastRegion: MKCoordinateRegion?
    private var lastClusterTime: Date = Date.distantPast
    private let clusteringThreshold: TimeInterval = 0.5 // 500ms de délai
    
    func clusterBancs(_ bancs: [BancLocation], for region: MKCoordinateRegion) -> [BancCluster] {
        // Optimisation : ne pas recalculer si la région n'a pas changé significativement
        if let lastRegion = lastRegion,
           abs(lastRegion.center.latitude - region.center.latitude) < 0.001 &&
           abs(lastRegion.center.longitude - region.center.longitude) < 0.001 &&
           abs(lastRegion.span.latitudeDelta - region.span.latitudeDelta) < 0.001 &&
           Date().timeIntervalSince(lastClusterTime) < clusteringThreshold {
            // Retourner les clusters existants si disponibles
            if !cachedClusters.isEmpty {
                return cachedClusters
            }
        }
        
        lastRegion = region
        lastClusterTime = Date()
        
        // Filtrer les bancs visibles dans la région actuelle avec une marge
        let margin = 1.5 // Marge pour inclure les bancs légèrement hors écran
        let visibleBancs = bancs.filter { banc in
            let latDiff = abs(banc.coordinate.latitude - region.center.latitude)
            let lonDiff = abs(banc.coordinate.longitude - region.center.longitude)
            
            return latDiff <= (region.span.latitudeDelta * margin / 2) &&
                   lonDiff <= (region.span.longitudeDelta * margin / 2)
        }
        
        print("🔍 Clustering: \(visibleBancs.count) bancs visibles sur \(bancs.count) total")
        
        // Calculer la distance de clustering adaptée au zoom
        let clusterDistance = calculateClusterDistance(for: region)
        
        // Algorithme de clustering simple mais efficace
        var clusters: [BancCluster] = []
        var processedBancs = Set<UUID>()
        
        for banc in visibleBancs {
            if processedBancs.contains(banc.id) { continue }
            
            var clusterBancs = [banc]
            processedBancs.insert(banc.id)
            
            // Trouver les bancs proches
            for otherBanc in visibleBancs {
                if processedBancs.contains(otherBanc.id) { continue }
                
                let distance = banc.coordinate.distance(to: otherBanc.coordinate)
                if distance <= clusterDistance {
                    clusterBancs.append(otherBanc)
                    processedBancs.insert(otherBanc.id)
                }
            }
            
            // Créer le cluster
            let centerCoordinate = calculateCenterCoordinate(for: clusterBancs)
            clusters.append(BancCluster(
                bancs: clusterBancs,
                centerCoordinate: centerCoordinate
            ))
        }
        
        cachedClusters = clusters

        return clusters
    }
    
    private var cachedClusters: [BancCluster] = []
    
    func updateClustering() {
        // Force la mise à jour au prochain appel
        lastClusterTime = Date.distantPast
    }
    
    private func calculateClusterDistance(for region: MKCoordinateRegion) -> Double {
        // Distance de clustering adaptée au niveau de zoom
        // Plus on est zoomé, plus la distance de clustering est petite
        let baseDistance = 200.0 // 200 mètres de base
        let zoomFactor = region.span.latitudeDelta / 0.01 // Facteur basé sur le span
        
        return baseDistance * max(0.1, zoomFactor)
    }
    
    private func calculateCenterCoordinate(for bancs: [BancLocation]) -> CLLocationCoordinate2D {
        guard !bancs.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        let totalLat = bancs.reduce(0) { $0 + $1.coordinate.latitude }
        let totalLon = bancs.reduce(0) { $0 + $1.coordinate.longitude }
        
        return CLLocationCoordinate2D(
            latitude: totalLat / Double(bancs.count),
            longitude: totalLon / Double(bancs.count)
        )
    }
}

// MARK: - ✅ MODÈLES POUR LE CLUSTERING
struct BancCluster: Identifiable {
    let id = UUID()
    let bancs: [BancLocation]
    let centerCoordinate: CLLocationCoordinate2D
}

// MARK: - ✅ EXTENSIONS POUR LE CLUSTERING
extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}

// ✅ EXTENSION POUR RENDRE MKCoordinateRegion EQUATABLE
extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return abs(lhs.center.latitude - rhs.center.latitude) < 0.000001 &&
               abs(lhs.center.longitude - rhs.center.longitude) < 0.000001 &&
               abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < 0.000001 &&
               abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < 0.000001
    }
}

// MARK: - Modèles nécessaires (utilise ceux de ToiletsMapView pour éviter les conflits)

// MARK: - ✅ NOUVELLE SECTION - Bancs les plus proches
struct NearestBancsView: View {
    let bancs: [BancLocation]
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête SANS ICÔNE
            HStack {
                Text("Bancs les plus proches")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Liste des 3 bancs
            VStack(spacing: 8) {
                ForEach(bancs) { banc in
                    NearestBancRowView(
                        banc: banc,
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

struct NearestBancRowView: View {
    let banc: BancLocation
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    private var distance: String {
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let bancLocation = CLLocation(latitude: banc.coordinate.latitude, longitude: banc.coordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: bancLocation)
        
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
                // Icône Banc AGRANDIE x2 (48px au lieu de 24px)
                Image("Banc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(themeColor)
                
                // Informations banc - UNIQUEMENT L'ADRESSE
                VStack(alignment: .leading, spacing: 4) {
                    Text(banc.address)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Badges statut
                    HStack(spacing: 8) {
                        if banc.isAccessible {
                            Text("♿ Accessible")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        if banc.hasShadow {
                            Text("🌳 Ombragé")
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
                openNavigationToBanc()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers ce banc ?")
        }
    }
    
    private func openNavigationToBanc() {
        let coordinate = banc.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = banc.address // Utilise l'adresse comme nom
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation à pied lancée vers: \(banc.address) (\(coordinate.latitude), \(coordinate.longitude))")
    }
}

// MARK: - Composants UI avec couleur uniforme

struct BancMapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let bancs: [BancLocation]
    let clusteredAnnotations: [BancMapAnnotationItem]
    let userLocation: CLLocationCoordinate2D?
    let searchedLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    let themeColor: Color
    let onClusterTapped: (BancCluster) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // ✅ En-tête avec nombre de bancs et bouton "Ma position"
            HStack {
                Text("Carte des bancs (\(bancs.count))")
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
            
            // ✅ Map avec annotations clusterisées
            Map(coordinateRegion: $region,
                interactionModes: [.pan, .zoom],
                showsUserLocation: true,
                annotationItems: clusteredAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if annotation.isCluster {
                        BancClusterMarkerView(
                            count: annotation.clusterCount,
                            bancs: annotation.clusterBancs,
                            themeColor: themeColor,
                            onTapped: {
                                let cluster = BancCluster(
                                    bancs: annotation.clusterBancs,
                                    centerCoordinate: annotation.coordinate
                                )
                                onClusterTapped(cluster)
                            }
                        )
                        .id("cluster-\(annotation.id)")
                    } else if let banc = annotation.banc {
                        BancMarkerView(banc: banc, themeColor: themeColor)
                            .id("banc-\(banc.id)")
                    } else if annotation.isSearchResult {
                        BancSearchPinMarker()
                            .id("search-pin")
                    }
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

// MARK: - ✅ NOUVEAU MARQUEUR DE CLUSTER
struct BancClusterMarkerView: View {
    let count: Int
    let bancs: [BancLocation]
    let themeColor: Color
    let onTapped: () -> Void
    
    var body: some View {
        Button(action: onTapped) {
            ZStack {
                // Cercle de fond avec dégradé
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                themeColor.opacity(0.8),
                                themeColor
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 1, y: 1)
                
                // Bordure blanche
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                // Nombre de bancs
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(1.1)
    }
}

// MARK: - ✅ VUE DÉTAIL DU CLUSTER
struct BancClusterDetailView: View {
    let bancs: [BancLocation]
    let themeColor: Color
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(bancs) { banc in
                        BancClusterRowView(banc: banc, themeColor: themeColor)
                    }
                }
                .padding()
            }
            .navigationTitle("Bancs dans cette zone")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Fermer") {
                dismiss()
            })
        }
    }
}

struct BancClusterRowView: View {
    let banc: BancLocation
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    var body: some View {
        Button(action: {
            showNavigationAlert = true
        }) {
            HStack(spacing: 12) {
                // Icône Banc
                Image("Banc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(themeColor)
                
                // Informations banc
                VStack(alignment: .leading, spacing: 4) {
                    Text(banc.address)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Badges
                    HStack(spacing: 6) {
                        if banc.isAccessible {
                            Text("♿")
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        if banc.hasShadow {
                            Text("🌳")
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                // Icône navigation
                Image(systemName: "location.north.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(themeColor)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .alert("Navigation", isPresented: $showNavigationAlert) {
            Button("Ouvrir dans Plans") {
                openNavigationToBanc()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers ce banc ?")
        }
    }
    
    private func openNavigationToBanc() {
        let coordinate = banc.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = banc.address
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation lancée vers: \(banc.address)")
    }
}

struct BancMapAnnotationItem: Identifiable {
    let id = UUID()
    let banc: BancLocation?
    let coordinate: CLLocationCoordinate2D
    let isSearchResult: Bool
    let isCluster: Bool
    let clusterCount: Int
    let clusterBancs: [BancLocation]
    let clusterId: UUID?
    
    init(banc: BancLocation?, coordinate: CLLocationCoordinate2D, isSearchResult: Bool, isCluster: Bool = false, clusterCount: Int = 0, clusterBancs: [BancLocation] = [], clusterId: UUID? = nil) {
        self.banc = banc
        self.coordinate = coordinate
        self.isSearchResult = isSearchResult
        self.isCluster = isCluster
        self.clusterCount = clusterCount
        self.clusterBancs = clusterBancs
        self.clusterId = clusterId
    }
    
    var stableId: String {
        if isCluster {
            return "cluster-\(coordinate.latitude)-\(coordinate.longitude)-\(clusterCount)"
        } else if let banc = banc {
            return "banc-\(banc.id)"
        } else if isSearchResult {
            return "search-pin"
        } else {
            return "unknown-\(id)"
        }
    }
}

// MARK: - Composants UI spécifiques aux bancs (évite les conflits avec ToiletsMapView)

struct BancSmartSearchBarView: View {
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

struct BancSuggestionsListView: View {
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

struct BancLoadingOverlayView: View {
    let themeColor: Color
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(themeColor)
                
                Text("Chargement des bancs...")
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

struct BancErrorOverlayView: View {
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
struct BancMarkerView: View {
    let banc: BancLocation
    let themeColor: Color
    @State private var showNavigationAlert = false
    
    var body: some View {
        Button(action: {
            showNavigationAlert = true
        }) {
            ZStack {
                // ✅ PLUS DE BACKGROUND CIRCULAIRE - JUSTE L'ICÔNE
                Image("Banc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundColor(themeColor)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1) // Ombre pour la visibilité
                
                // Bordure verte si accessible (autour de l'icône)
                if banc.isAccessible {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                // Bordure bleue si ombragé (autour de l'icône)
                if banc.hasShadow {
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
            Text("Voulez-vous ouvrir la navigation vers \(banc.name) ?")
        }
    }
    
    private func openInMaps() {
        let coordinate = banc.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = banc.name
        mapItem.phoneNumber = nil
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation lancée vers: \(banc.name) (\(coordinate.latitude), \(coordinate.longitude))")
    }
}

struct BancSearchPinMarker: View {
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
class BancAPIService: ObservableObject {
    @Published var bancs: [BancLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrbanc_latest&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
    
    func loadBancs() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let url = URL(string: apiURL) else {
                throw BancAPIError.invalidURL
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BancAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw BancAPIError.httpError(httpResponse.statusCode)
            }
            
            let geoJsonResponse = try JSONDecoder().decode(BancGeoJSONResponse.self, from: data)
            
            let bancLocations = geoJsonResponse.features.compactMap { feature -> BancLocation? in
                guard feature.geometry.coordinates.count >= 2 else { return nil }
                
                let longitude = feature.geometry.coordinates[0]
                let latitude = feature.geometry.coordinates[1]
                let props = feature.properties
                
                return BancLocation(
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    name: props.nom ?? "Banc public",
                    address: formatAddress(props),
                    gestionnaire: props.gestionnaire ?? "Non spécifié",
                    isAccessible: props.acces_pmr == "Oui",
                    hasShadow: props.ombrage == "Oui",
                    materiau: props.materiau
                )
            }
            
            bancs = bancLocations
            isLoading = false
            
        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func formatAddress(_ props: BancProperties) -> String {
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

struct BancLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
    let address: String
    let gestionnaire: String
    let isAccessible: Bool
    let hasShadow: Bool
    let materiau: String?
}

struct BancGeoJSONResponse: Codable {
    let type: String
    let features: [BancFeature]
    let totalFeatures: Int?
}

struct BancFeature: Codable {
    let type: String
    let geometry: BancGeometry
    let properties: BancProperties
}

struct BancGeometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct BancProperties: Codable {
    let gid: Int?
    let nom: String?
    let adresse: String?
    let code_postal: String?
    let commune: String?
    let gestionnaire: String?
    let acces_pmr: String?
    let ombrage: String?
    let materiau: String?
}

enum BancAPIError: Error, LocalizedError {
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
    BancsMapView()
}
