import SwiftUI
import MapKit
import Foundation

struct RandosMapView: View {
    @StateObject private var randoService = RandoAPIService()
    @StateObject private var locationService = GlobalLocationService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    
    // Region et états
    @State private var region: MKCoordinateRegion
    @State private var hasInitialized = false // Pour éviter la réinitialisation
    
    // State pour la modale détail
    @State private var selectedBoucle: BoucleLocation?
    @State private var showBoucleDetail = false
    
    // Couleur theme
    private let randoThemeColor = Color(red: 0xD4/255.0, green: 0xBE/255.0, blue: 0xA0/255.0)
    
    // Computed property pour TOUTES les boucles triées par distance
    private var nearestBoucles: [BoucleLocation] {
        guard let userLocation = locationService.userLocation else {
            // Si pas de position utilisateur, retourner toutes les boucles sans tri
            return randoService.boucles
        }
        
        return randoService.boucles
            .map { boucle in
                let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    .distance(from: CLLocation(latitude: boucle.centerCoordinate.latitude, longitude: boucle.centerCoordinate.longitude))
                return (boucle: boucle, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .map { $0.boucle }
    }
    
    // ✅ Initializer modifié - avec détection Lyon
    init() {
        let lyonCenter = CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320)
        
        let (initialCenter, initialSpan) = Self.determineInitialMapSettings(
            userLocation: GlobalLocationService.shared.userLocation,
            lyonCenter: lyonCenter
        )
        
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCenter,
            span: initialSpan
        ))
    }
    
    // ✅ Fonction statique pour déterminer les paramètres initiaux
    private static func determineInitialMapSettings(
        userLocation: CLLocationCoordinate2D?,
        lyonCenter: CLLocationCoordinate2D
    ) -> (center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        
        guard let userLocation = userLocation else {
            print("🏛️ Randos: Pas de position utilisateur - centrage sur Lyon")
            return (
                center: lyonCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        }
        
        // Calculer la distance depuis Lyon
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let lyonCLLocation = CLLocation(latitude: lyonCenter.latitude, longitude: lyonCenter.longitude)
        let distanceFromLyon = userCLLocation.distance(from: lyonCLLocation)
        
        // Si l'utilisateur est à plus de 50km de Lyon
        if distanceFromLyon > 50000 {
            print("🌍 Randos: Utilisateur trop loin de Lyon (\(Int(distanceFromLyon/1000))km) - centrage sur Lyon")
            return (
                center: lyonCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        } else {
            print("🎯 Randos: Utilisateur proche de Lyon (\(Int(distanceFromLyon/1000))km) - centrage sur position utilisateur")
            return (
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.11, longitudeDelta: 0.11)
            )
        }
    }
}

// MARK: - Service API et modèles

@MainActor
class RandoAPIService: ObservableObject {
    @Published var boucles: [BoucleLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:boucle-de-randonnee&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
    
    func loadBoucles() async {
        print("🔄 Début loadBoucles - isLoading: \(isLoading)")
        
        guard !isLoading else {
            print("⚠️ Chargement déjà en cours, abandon")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🌐 Tentative de connexion à l'API...")
            guard let url = URL(string: apiURL) else {
                throw RandoAPIError.invalidURL
            }
            
            // Configuration avec timeout
            var request = URLRequest(url: url)
            request.timeoutInterval = 30.0 // 30 secondes de timeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RandoAPIError.invalidResponse
            }
            
            print("📡 Réponse HTTP: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                throw RandoAPIError.httpError(httpResponse.statusCode)
            }
            
            print("📊 Taille des données reçues: \(data.count) bytes")
            
            let geoJsonResponse = try JSONDecoder().decode(RandoGeoJSONResponse.self, from: data)
            
            print("🔍 Nombre de features dans la réponse: \(geoJsonResponse.features.count)")
            
            let boucleLocations = geoJsonResponse.features.compactMap { feature -> BoucleLocation? in
                guard !feature.geometry.coordinates.isEmpty else { return nil }
                
                let props = feature.properties
                
                // Extraction des coordonnées depuis MultiLineString
                var allCoordinates: [CLLocationCoordinate2D] = []
                
                for lineString in feature.geometry.coordinates {
                    for coordinate in lineString {
                        if coordinate.count >= 2 {
                            let longitude = coordinate[0]
                            let latitude = coordinate[1]
                            allCoordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                        }
                    }
                }
                
                guard !allCoordinates.isEmpty else { return nil }
                
                // Calcul du centre de la boucle
                let centerLat = allCoordinates.map { $0.latitude }.reduce(0, +) / Double(allCoordinates.count)
                let centerLon = allCoordinates.map { $0.longitude }.reduce(0, +) / Double(allCoordinates.count)
                let centerCoordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
                
                return BoucleLocation(
                    coordinates: allCoordinates,
                    centerCoordinate: centerCoordinate,
                    nom: props.nom ?? "Boucle de randonnée",
                    commune: props.commune ?? "Non spécifiée",
                    vocation: props.vocation ?? "",
                    difficulte: props.difficulte ?? "Non spécifiée",
                    temps: props.temps ?? "Non spécifié",
                    longueur: props.longueur ?? "Non spécifiée",
                    denivele: props.denivele ?? "Non spécifié",
                    depart: props.depart ?? "Non spécifié",
                    descriptif: props.descriptif ?? "",
                    cheminement: props.cheminement ?? ""
                )
            }
            
            boucles = boucleLocations
            isLoading = false
            
            print("✅ \(boucles.count) boucles de randonnée chargées avec succès")
            
        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            isLoading = false
            print("❌ Erreur chargement boucles: \(error)")
        }
    }
}

struct BoucleLocation: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let centerCoordinate: CLLocationCoordinate2D
    let nom: String
    let commune: String
    let vocation: String
    let difficulte: String
    let temps: String
    let longueur: String
    let denivele: String
    let depart: String
    let descriptif: String
    let cheminement: String
}

struct RandoGeoJSONResponse: Codable {
    let type: String
    let features: [RandoFeature]
    let totalFeatures: Int?
}

struct RandoFeature: Codable {
    let type: String
    let geometry: RandoGeometry
    let properties: RandoProperties
}

struct RandoGeometry: Codable {
    let type: String
    let coordinates: [[[Double]]]
}

struct RandoProperties: Codable {
    let identifiant: Int?
    let nom: String?
    let vocation: String?
    let commune: String?
    let insee: String?
    let difficulte: String?
    let temps: String?
    let longueur: String?
    let denivele: String?
    let depart: String?
    let descriptif: String?
    let cheminement: String?
}

enum RandoAPIError: Error, LocalizedError {
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

// MARK: - Vue principale
extension RandosMapView {
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Titre en haut
                    HStack(spacing: 12) {
                        Image("Rando")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(randoThemeColor)
                        
                        Text("Boucles de Randonnée")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // Carte
                    RandoMapBoxView(
                        region: $region,
                        boucles: randoService.boucles,
                        userLocation: locationService.userLocation,
                        isLoading: randoService.isLoading,
                        themeColor: randoThemeColor,
                        onBoucleSelected: { boucle in
                            print("🎯 Boucle sélectionnée: \(boucle.nom)")
                            selectedBoucle = boucle
                            showBoucleDetail = true
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // Section de TOUTES les boucles triées par distance
                    if !nearestBoucles.isEmpty {
                        NearestBouclesView(
                            boucles: nearestBoucles,
                            userLocation: locationService.userLocation,
                            themeColor: randoThemeColor,
                            onBoucleSelected: { boucle in
                                print("🎯 Boucle sélectionnée: \(boucle.nom)")
                                selectedBoucle = boucle
                                showBoucleDetail = true
                            }
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    
                    // Espace pour le menu en bas
                    Spacer(minLength: 120)
                }
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            .refreshable {
                await randoService.loadBoucles()
            }
            
            // Menu fixe en bas
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
                themeColor: randoThemeColor
            )
        }
        .onAppear {
            navigationManager.currentDestination = "randos"
            
            // Initialiser seulement la première fois
            if !hasInitialized {
                setupInitialLocation()
                hasInitialized = true
                
                if randoService.boucles.isEmpty && !randoService.isLoading {
                    loadBoucles()
                }
            }
        }
        .onDisappear {
            locationService.stopLocationUpdates()
        }
        // ✅ Ajout de onChange avec vérification distance Lyon
        .onChange(of: locationService.isLocationReady) { isReady in
            if isReady, let location = locationService.userLocation {
                // Centrer seulement si on n'a pas encore initialisé
                if !hasInitialized {
                    let lyonCenter = CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320)
                    let userCLLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    let lyonCLLocation = CLLocation(latitude: lyonCenter.latitude, longitude: lyonCenter.longitude)
                    let distanceFromLyon = userCLLocation.distance(from: lyonCLLocation)
                    
                    if distanceFromLyon > 50000 {
                        // Utilisateur trop loin - centrer sur Lyon avec vue large
                        print("🌍 Randos: Mise à jour - utilisateur trop loin (\(Int(distanceFromLyon/1000))km), centrage sur Lyon")
                        centerMapOnLyon()
                    } else {
                        // Utilisateur proche - centrer sur sa position
                        print("📍 Randos: Mise à jour - utilisateur proche (\(Int(distanceFromLyon/1000))km), centrage sur position")
                        centerMapOnLocation(location)
                    }
                }
            }
        }
        .overlay {
            if randoService.isLoading && randoService.boucles.isEmpty {
                RandoLoadingOverlayView(themeColor: randoThemeColor)
            }
        }
        .overlay {
            if let errorMessage = randoService.errorMessage {
                RandoErrorOverlayView(message: errorMessage, themeColor: randoThemeColor) {
                    loadBoucles()
                }
            }
        }
        .sheet(isPresented: $showBoucleDetail) {
            if let boucle = selectedBoucle {
                BoucleDetailModalView(
                    boucle: boucle,
                    userLocation: locationService.userLocation,
                    themeColor: randoThemeColor
                )
            }
        }
        .onChange(of: showBoucleDetail) { isShowing in
            print("📱 État modale: \(isShowing ? "Ouverte" : "Fermée")")
            if !isShowing {
                // Reset de la boucle sélectionnée après fermeture
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedBoucle = nil
                }
            }
        }
    }
    
    // ✅ Ajout des fonctions comme dans BornesMapView
    private func setupInitialLocation() {
        print("🗺️ Setup initial - randos")
        
        if locationService.userLocation == nil {
            print("🔄 Position pas encore disponible, refresh en cours...")
            locationService.refreshLocation()
        } else {
            print("✅ Position déjà disponible depuis l'init")
        }
    }
    
    private func centerMapOnLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.07, longitudeDelta: 0.07)
        }
    }
    
    // ✅ Nouvelle fonction pour centrer sur Lyon avec vue large
    private func centerMapOnLyon() {
        let lyonCenter = CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320)
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = lyonCenter
            region.span = MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
        }
    }
    
    private func loadBoucles() {
        Task {
            await randoService.loadBoucles()
        }
    }
}

// MARK: - Section toutes les boucles triées par distance
struct NearestBouclesView: View {
    let boucles: [BoucleLocation]
    let userLocation: CLLocationCoordinate2D?
    let themeColor: Color
    let onBoucleSelected: (BoucleLocation) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(userLocation != nil ? "Boucles les plus proches" : "Toutes les boucles")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(boucles) { boucle in
                        NearestBoucleRowView(
                            boucle: boucle,
                            userLocation: userLocation,
                            themeColor: themeColor,
                            onBoucleSelected: onBoucleSelected
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 400) // Limiter la hauteur pour éviter que ça prenne tout l'écran
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct NearestBoucleRowView: View {
    let boucle: BoucleLocation
    let userLocation: CLLocationCoordinate2D?
    let themeColor: Color
    let onBoucleSelected: (BoucleLocation) -> Void
    
    private var distance: String? {
        guard let userLocation = userLocation else { return nil }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let boucleLocation = CLLocation(latitude: boucle.centerCoordinate.latitude, longitude: boucle.centerCoordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: boucleLocation)
        
        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters))m"
        } else {
            return String(format: "%.1fkm", distanceInMeters / 1000)
        }
    }
    
    var body: some View {
        Button(action: {
            onBoucleSelected(boucle)
        }) {
            HStack(spacing: 12) {
                Image("Rando")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(themeColor)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(boucle.nom)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text(boucle.commune)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    if let distance = distance {
                        Text(distance)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeColor)
                    }
                    
                    Image(systemName: "info.circle.fill")
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
    }
}

// MARK: - Composant carte
struct RandoMapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let boucles: [BoucleLocation]
    let userLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    let themeColor: Color
    let onBoucleSelected: (BoucleLocation) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête avec nombre de boucles et bouton "Ma position"
            HStack {
                Text("Carte des boucles (\(boucles.count))")
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
            
            // Map sans annotations de recherche
            Map(coordinateRegion: $region,
                interactionModes: [.pan, .zoom],
                showsUserLocation: true)
            .overlay(
                RandoClickablePolylinesOverlay(
                    region: $region,
                    boucles: boucles,
                    themeColor: themeColor,
                    onBoucleSelected: onBoucleSelected
                )
            )
            .frame(height: 350)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private func centerOnUserLocation() {
        guard let userLocation = userLocation else { return }
        
        // ✅ Vérifier si l'utilisateur est proche de Lyon
        let lyonCenter = CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320)
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let lyonCLLocation = CLLocation(latitude: lyonCenter.latitude, longitude: lyonCenter.longitude)
        let distanceFromLyon = userCLLocation.distance(from: lyonCLLocation)
        
        if distanceFromLyon > 50000 {
            print("📍 Bouton position: Utilisateur trop loin (\(Int(distanceFromLyon/1000))km) - centrage sur Lyon")
            withAnimation(.easeInOut(duration: 0.5)) {
                region.center = lyonCenter
                region.span = MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
            }
        } else {
            print("📍 Bouton position: Centrage sur position utilisateur (\(Int(distanceFromLyon/1000))km de Lyon)")
            withAnimation(.easeInOut(duration: 0.5)) {
                region.center = userLocation
                region.span = MKCoordinateSpan(latitudeDelta: 0.07, longitudeDelta: 0.07)
            }
        }
    }
}

// MARK: - Overlay avec polylines cliquables
struct RandoClickablePolylinesOverlay: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let boucles: [BoucleLocation]
    let themeColor: Color
    let onBoucleSelected: (BoucleLocation) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = true
        mapView.backgroundColor = .clear
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // ✅ MODIFICATION: Ne forcer la région QUE si c'est un changement important
        let currentCenter = mapView.region.center
        let targetCenter = region.center
        
        // Calculer la distance entre les centres
        let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
            .distance(from: CLLocation(latitude: targetCenter.latitude, longitude: targetCenter.longitude))
        
        // Ne forcer la région que si la distance est > 1km (changement intentionnel)
        if distance > 1000 {
            print("🗺️ Mise à jour région forcée - distance: \(distance)m")
            mapView.setRegion(region, animated: true)
        }
        
        // Toujours mettre à jour les overlays
        mapView.removeOverlays(mapView.overlays)
        
        for boucle in boucles {
            // Bordure pour le contraste
            let borderPolyline = MKPolyline(coordinates: boucle.coordinates, count: boucle.coordinates.count)
            borderPolyline.title = "\(boucle.id.uuidString)_border"
            mapView.addOverlay(borderPolyline)
            
            // Ligne principale cliquable
            let mainPolyline = ClickableMKPolyline(coordinates: boucle.coordinates, count: boucle.coordinates.count)
            mainPolyline.boucle = boucle
            mainPolyline.title = boucle.id.uuidString
            mapView.addOverlay(mainPolyline)
        }
        
        context.coordinator.onBoucleSelected = onBoucleSelected
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(themeColor: themeColor)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let themeColor: Color
        var onBoucleSelected: ((BoucleLocation) -> Void)?
        
        init(themeColor: Color) {
            self.themeColor = themeColor
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                if polyline.title?.hasSuffix("_border") == true {
                    renderer.strokeColor = UIColor.darkGray.withAlphaComponent(0.6)
                    renderer.lineWidth = 8.0
                    renderer.alpha = 1.0
                } else {
                    renderer.strokeColor = UIColor(themeColor)
                    renderer.lineWidth = 6.0
                    renderer.alpha = 0.9
                }
                
                renderer.lineCap = .round
                renderer.lineJoin = .round
                
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let touchPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            var closestBoucle: BoucleLocation?
            var minDistance: Double = Double.infinity
            
            for overlay in mapView.overlays {
                if let clickablePolyline = overlay as? ClickableMKPolyline,
                   let boucle = clickablePolyline.boucle {
                    
                    let distance = distanceFromCoordinateToPolyline(coordinate, polyline: clickablePolyline)
                    
                    if distance < 100 && distance < minDistance {
                        minDistance = distance
                        closestBoucle = boucle
                    }
                }
            }
            
            if let boucle = closestBoucle {
                onBoucleSelected?(boucle)
            }
        }
        
        private func distanceFromCoordinateToPolyline(_ coordinate: CLLocationCoordinate2D, polyline: MKPolyline) -> Double {
            let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            var minDistance: Double = Double.infinity
            
            let coordinates = polyline.coordinates()
            for i in 0..<coordinates.count - 1 {
                let start = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
                let end = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
                
                let distance = distanceFromPointToLineSegment(point: point, start: start, end: end)
                minDistance = min(minDistance, distance)
            }
            
            return minDistance
        }
        
        private func distanceFromPointToLineSegment(point: CLLocation, start: CLLocation, end: CLLocation) -> Double {
            let startDistance = point.distance(from: start)
            let endDistance = point.distance(from: end)
            let segmentDistance = start.distance(from: end)
            
            if segmentDistance < 1 {
                return min(startDistance, endDistance)
            }
            
            let dx = end.coordinate.longitude - start.coordinate.longitude
            let dy = end.coordinate.latitude - start.coordinate.latitude
            
            let px = point.coordinate.longitude - start.coordinate.longitude
            let py = point.coordinate.latitude - start.coordinate.latitude
            
            let dotProduct = px * dx + py * dy
            let lengthSquared = dx * dx + dy * dy
            
            let t = max(0, min(1, dotProduct / lengthSquared))
            
            let projectionLat = start.coordinate.latitude + t * dy
            let projectionLon = start.coordinate.longitude + t * dx
            let projection = CLLocation(latitude: projectionLat, longitude: projectionLon)
            
            return point.distance(from: projection)
        }
    }
}

// MARK: - Polyline cliquable avec référence à la boucle
class ClickableMKPolyline: MKPolyline {
    var boucle: BoucleLocation?
}

// MARK: - Extension pour récupérer les coordonnées d'une MKPolyline
extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Extension pour comparer les coordonnées
extension CLLocationCoordinate2D {
    func isEqual(to coordinate: CLLocationCoordinate2D, tolerance: Double) -> Bool {
        return abs(self.latitude - coordinate.latitude) < tolerance &&
               abs(self.longitude - coordinate.longitude) < tolerance
    }
}

// MARK: - Modale détail de boucle
struct BoucleDetailModalView: View {
    let boucle: BoucleLocation
    let userLocation: CLLocationCoordinate2D?
    let themeColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var showNavigationAlert = false
    
    private var distance: String? {
        guard let userLocation = userLocation else { return nil }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let boucleLocation = CLLocation(latitude: boucle.centerCoordinate.latitude, longitude: boucle.centerCoordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: boucleLocation)
        
        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters)) m"
        } else {
            return String(format: "%.1f km", distanceInMeters / 1000)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header avec icône et titre
                    VStack(spacing: 12) {
                        Image("Rando")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(themeColor)
                        
                        Text(boucle.nom)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        
                        Text(boucle.commune)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(themeColor.opacity(0.1))
                    .cornerRadius(16)
                    
                    // Stats avec emojis - disposition 3+2
                    VStack(spacing: 16) {
                        // Première ligne : 3 cartes
                        HStack(spacing: 12) {
                            EmojiStatCard(
                                emoji: "🥾",
                                title: "Distance",
                                value: boucle.longueur
                            )
                            
                            EmojiStatCard(
                                emoji: "⏱️",
                                title: "Durée",
                                value: boucle.temps
                            )
                            
                            EmojiStatCard(
                                emoji: "⛰️",
                                title: "Dénivelé",
                                value: boucle.denivele
                            )
                        }
                        
                        // Deuxième ligne : 2 cartes
                        HStack(spacing: 12) {
                            EmojiStatCard(
                                emoji: "📊",
                                title: "Difficulté",
                                value: boucle.difficulte
                            )
                            
                            // Distance de l'utilisateur si disponible
                            if let distance = distance {
                                EmojiStatCard(
                                    emoji: "🧭",
                                    title: "Distance de vous",
                                    value: distance
                                )
                            } else {
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Point de départ
                    if !boucle.depart.isEmpty && boucle.depart != "Non spécifié" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(.red)
                                Text("Point de départ")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            Text(boucle.depart)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Description
                    if !boucle.descriptif.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(themeColor)
                                Text("Description")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            Text(boucle.descriptif)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Cheminement
                    if !boucle.cheminement.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "map")
                                    .foregroundColor(themeColor)
                                Text("Itinéraire")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            Text(boucle.cheminement)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Vocation
                    if !boucle.vocation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.2")
                                    .foregroundColor(themeColor)
                                Text("Vocation")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            Text(boucle.vocation)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Bouton navigation
                    Button(action: {
                        showNavigationAlert = true
                    }) {
                        HStack {
                            Image(systemName: "location.north.fill")
                                .font(.title2)
                            Text("Ouvrir la navigation")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitle("Détails de la boucle", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Fermer") {
                    dismiss()
                }
                .foregroundColor(themeColor)
            )
        }
        .alert("Navigation", isPresented: $showNavigationAlert) {
            Button("Ouvrir dans Plans") {
                openNavigationToBoucle()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Voulez-vous ouvrir la navigation vers cette boucle de randonnée ?")
        }
    }
    
    private func openNavigationToBoucle() {
        let coordinate = boucle.centerCoordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = boucle.nom
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
            MKLaunchOptionsShowsTrafficKey: false
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
    }
}

// MARK: - Carte avec emoji pour les stats
struct EmojiStatCard: View {
    let emoji: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 34))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(red: 0xD4/255.0, green: 0xBE/255.0, blue: 0xA0/255.0).opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Pin de recherche
struct RandoSearchPinMarker: View {
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

// MARK: - Composants d'overlay
struct RandoLoadingOverlayView: View {
    let themeColor: Color
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(themeColor)
                
                Text("Chargement des boucles...")
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

struct RandoErrorOverlayView: View {
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

// MARK: - Preview
#Preview {
    RandosMapView()
}
