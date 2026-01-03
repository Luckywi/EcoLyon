import SwiftUI
import MapKit
import CoreLocation

// MARK: - RandosMapView

struct RandosMapView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var randoService = RandoAPIService()
    @ObservedObject private var locationService = GlobalLocationService.shared
    @ObservedObject private var weatherService = AppWeatherService.shared
    @ObservedObject private var navigationManager = NavigationManager.shared

    @State private var cameraPosition: MapCameraPosition
    @State private var isHeaderExpanded = false
    @State private var selectedBoucle: BoucleLocation?

    // État de l'îlot flottant
    @State private var isIslandExpanded = false

    // État du mode liste (comme le mode recherche dans FontainesMapView)
    @State private var isListMode = false

    // États pour les contrôles carte
    @State private var mapHeading: Double = 0
    @State private var isMapCenteredOnUser = false

    private let themeColor = Color(red: 0.30, green: 0.69, blue: 0.31)

    // État de chargement initial
    @State private var hasLoadedOnce = false

    // Computed property pour l'overlay de chargement
    private var showLoadingOverlay: Bool {
        !hasLoadedOnce && randoService.boucles.isEmpty
    }

    // MARK: - Computed Properties pour l'îlot

    private var islandState: IslandState {
        if isListMode { return .keyboard }
        if isIslandExpanded { return .expanded }
        return .collapsed
    }

    private var islandMaxHeight: CGFloat? {
        switch islandState {
        case .collapsed: return nil
        case .expanded: return UIScreen.main.bounds.height * 0.55
        case .keyboard: return UIScreen.main.bounds.height * 0.7
        }
    }

    private var islandCornerRadius: CGFloat { 20 }

    private var islandBottomRadius: CGFloat {
        islandState == .keyboard ? 0 : islandCornerRadius
    }

    private var islandHorizontalPadding: CGFloat {
        islandState == .keyboard ? 0 : 10
    }

    private var showDimOverlay: Bool {
        islandState == .keyboard
    }

    // Boucle la plus proche de l'utilisateur
    private var closestBoucle: BoucleLocation? {
        guard let userLoc = locationService.userLocation else {
            return randoService.boucles.first
        }
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return randoService.boucles.min { b1, b2 in
            let loc1 = CLLocation(latitude: b1.centerCoordinate.latitude, longitude: b1.centerCoordinate.longitude)
            let loc2 = CLLocation(latitude: b2.centerCoordinate.latitude, longitude: b2.centerCoordinate.longitude)
            return userCL.distance(from: loc1) < userCL.distance(from: loc2)
        }
    }

    // Liste triée avec la boucle sélectionnée en premier
    private var sortedBoucles: [BoucleLocation] {
        guard let selected = selectedBoucle else {
            return randoService.boucles
        }
        var sorted = randoService.boucles.filter { $0.id != selected.id }
        sorted.insert(selected, at: 0)
        return sorted
    }

    init() {
        let lyonCenter = CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320)
        _cameraPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: lyonCenter,
            distance: 50000,
            heading: 0,
            pitch: 0
        )))
    }

    var body: some View {
        ZStack {
            // Carte avec tous les tracés
            MapReader { proxy in
                Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
                    ForEach(randoService.boucles) { boucle in
                        if !boucle.coordinates.isEmpty {
                            MapPolyline(coordinates: boucle.coordinates)
                                .stroke(
                                    selectedBoucle?.id == boucle.id ? Color.blue : Color.gray.opacity(0.7),
                                    style: StrokeStyle(
                                        lineWidth: selectedBoucle?.id == boucle.id ? 6 : 4,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                        }
                    }

                    UserAnnotation()
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls { }
                .onTapGesture { screenPoint in
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        handleMapTap(at: coordinate)
                    }
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    mapHeading = context.camera.heading
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 120)
                    .allowsHitTesting(false)
            }

            // Header
            VStack {
                headerIsland

                Spacer()
            }

            // Boutons météo/boussole/localisation/recherche à droite
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 10) {
                        // Widget météo + qualité d'air
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if let location = locationService.userLocation {
                                Task {
                                    await weatherService.fetchWeather(for: location)
                                }
                            }
                        }) {
                            VStack(alignment: .center, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: weatherService.weatherData.conditionSymbol)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .symbolRenderingMode(.multicolor)

                                    Text(weatherService.weatherData.formattedTemperature)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }

                                HStack(spacing: 4) {
                                    Text("Air")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)

                                    Circle()
                                        .fill(weatherService.weatherData.airQualityColor)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .frame(width: 52, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                            )
                        }

                        // Boussole
                        Button(action: resetMapToNorth) {
                            CompassView(heading: mapHeading)
                                .frame(width: 52, height: 44)
                        }
                        .buttonStyle(.plain)

                        // Bouton localisation
                        Button(action: recenterOnUser) {
                            Image(systemName: "location")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 52, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                                )
                        }

                        // Bouton recherche
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(IslandState.animation) {
                                isListMode = true
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                                )
                        }
                    }
                    .padding(.trailing, 12)
                }
                .padding(.bottom, 160)
            }

            // Overlay sombre quand mode liste
            Color.black.opacity(showDimOverlay ? 0.3 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(showDimOverlay)
                .onTapGesture {
                    withAnimation(IslandState.animation) {
                        isListMode = false
                    }
                }
                .animation(IslandState.animation, value: islandState)

            // Îlot flottant en bas
            VStack {
                Spacer()
                boucleIsland
            }
            .ignoresSafeArea(.container, edges: isListMode ? .bottom : [])

            // Overlay de chargement
            if showLoadingOverlay {
                MapLoadingOverlay(
                    imageName: "Rando",
                    title: "Randonnées",
                    themeColor: themeColor,
                    hasError: false
                )
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.2)),
                    removal: .opacity.combined(with: .scale(scale: 1.1)).animation(.easeOut(duration: 0.4))
                ))
                .zIndex(100)
            }
        }
        .onAppear {
            navigationManager.currentDestination = .randos
            Task {
                await randoService.loadBoucles()
                hasLoadedOnce = true
                // Sélectionner la boucle la plus proche par défaut (sans zoom)
                if selectedBoucle == nil {
                    selectedBoucle = closestBoucle
                    if let boucle = selectedBoucle {
                        centerOnBoucle(boucle)
                    }
                }
            }
            // Charger les données météo
            if let location = locationService.userLocation {
                Task {
                    await weatherService.fetchWeather(for: location)
                }
            }
        }
        .onChange(of: randoService.boucles.count) { _, newCount in
            if newCount > 0 {
                hasLoadedOnce = true
            }
        }
    }

    // MARK: - Header Island

    @ViewBuilder
    private var headerIsland: some View {
        HStack(alignment: .top) {
            Button(action: { navigationManager.navigateToHome() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isHeaderExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 10) {
                        Text("Randonnées")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Image("Rando")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)

                        // Séparateur vertical
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 1, height: 20)

                        // Icône info iOS native
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                if isHeaderExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("À propos")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text("Découvrez les \(randoService.boucles.count) boucles de randonnée balisées de la Métropole de Lyon. Accessibles en transports en commun, ces sentiers vous invitent à explorer nature et patrimoine.")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 6) {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)

                                Text("Données ouvertes Grand Lyon")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)

                            Link(destination: URL(string: "https://data.grandlyon.com")!) {
                                HStack(spacing: 4) {
                                    Text("data.grandlyon.com")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                    }
                    .frame(width: 260)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    // MARK: - Îlot Boucle Flottant

    @ViewBuilder
    private var boucleIsland: some View {
        VStack(spacing: 0) {
            // Handle de drag
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            withAnimation(IslandState.animation) {
                                if value.translation.height < -50 {
                                    if !isListMode {
                                        isIslandExpanded = true
                                    }
                                } else if value.translation.height > 50 {
                                    isListMode = false
                                    isIslandExpanded = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if isListMode {
                        withAnimation(IslandState.animation) {
                            isListMode = false
                        }
                    } else {
                        withAnimation(IslandState.animation) {
                            isIslandExpanded.toggle()
                        }
                    }
                }

            // Contenu de l'îlot
            if isListMode {
                // Mode liste : afficher toutes les boucles
                allBouclesListContent
            } else if let boucle = selectedBoucle {
                // Vue compacte ou étendue
                if isIslandExpanded {
                    expandedBoucleContent(boucle)
                } else {
                    compactBoucleContent(boucle)
                }
            } else {
                // État de chargement
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Chargement des boucles...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(maxHeight: islandMaxHeight)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: islandCornerRadius,
                bottomLeadingRadius: islandBottomRadius,
                bottomTrailingRadius: islandBottomRadius,
                topTrailingRadius: islandCornerRadius
            )
            .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: islandCornerRadius,
                bottomLeadingRadius: islandBottomRadius,
                bottomTrailingRadius: islandBottomRadius,
                topTrailingRadius: islandCornerRadius
            )
        )
        .padding(.horizontal, islandHorizontalPadding)
        .padding(.bottom, 0)
        .animation(IslandState.animation, value: islandState)
    }

    // MARK: - Contenu Compact

    @ViewBuilder
    private func compactBoucleContent(_ boucle: BoucleLocation) -> some View {
        VStack(spacing: 12) {
            // Ligne principale
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(boucle.nom)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(boucle.commune)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image("Rando")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
            }

            // Métriques compactes
            HStack(spacing: 16) {
                if let distance = distanceFromUser(to: boucle) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(distance)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                if !boucle.longueur.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "ruler")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(boucle.longueur)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                if !boucle.temps.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(boucle.temps)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Contenu Étendu

    @ViewBuilder
    private func expandedBoucleContent(_ boucle: BoucleLocation) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // En-tête
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(boucle.nom)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)

                        Text(boucle.commune)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image("Rando")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                }
                .padding(.horizontal, 20)

                // Métriques
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    BoucleMetricPill(icon: "ruler", value: boucle.longueur, label: "Distance")
                    BoucleMetricPill(icon: "clock", value: boucle.temps, label: "Durée")
                    BoucleMetricPill(icon: "arrow.up.right", value: boucle.denivele, label: "Dénivelé")
                    BoucleMetricPill(icon: "figure.hiking", value: boucle.difficulte, label: "Difficulté")
                }
                .padding(.horizontal, 20)

                // Distance utilisateur
                if let distance = distanceFromUser(to: boucle) {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Text("À \(distance) de vous")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }

                // Point de départ
                if !boucle.depart.isEmpty {
                    BoucleInfoSection(title: "Point de départ", content: boucle.depart)
                }

                // Vocation
                if !boucle.vocation.isEmpty {
                    BoucleInfoSection(title: "Vocation", content: boucle.vocation)
                }

                // Description
                if !boucle.descriptif.isEmpty {
                    BoucleInfoSection(title: "Description", content: boucle.descriptif)
                }

                // Cheminement
                if !boucle.cheminement.isEmpty {
                    BoucleInfoSection(title: "Cheminement", content: boucle.cheminement)
                }

                // Bouton Itinéraire
                Button(action: { openDirections(to: boucle) }) {
                    Text("Itinéraire vers le départ")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.15))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Liste de toutes les boucles

    @ViewBuilder
    private var allBouclesListContent: some View {
        VStack(spacing: 0) {
            // Titre
            HStack {
                Text("Les 54 boucles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Liste scrollable (boucle sélectionnée en premier)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(sortedBoucles) { boucle in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedBoucle = boucle
                            withAnimation(IslandState.animation) {
                                isListMode = false
                                isIslandExpanded = false
                            }
                            centerOnBoucle(boucle)
                        }) {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(boucle.nom)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 8) {
                                        Text(boucle.commune)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)

                                        if !boucle.longueur.isEmpty {
                                            Text("•")
                                                .foregroundColor(.secondary)
                                            Text(boucle.longueur)
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                if selectedBoucle?.id == boucle.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }

                        if boucle.id != sortedBoucles.last?.id {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Helpers

    private func distanceFromUser(to boucle: BoucleLocation) -> String? {
        guard let userLoc = locationService.userLocation else { return nil }
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let boucleCL = CLLocation(latitude: boucle.centerCoordinate.latitude, longitude: boucle.centerCoordinate.longitude)
        let distance = userCL.distance(from: boucleCL)
        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    private func resetMapToNorth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let lyonCenter = CLLocationCoordinate2D(latitude: 45.7578, longitude: 4.8320)
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: selectedBoucle?.centerCoordinate ?? lyonCenter,
                distance: 50000,
                heading: 0,
                pitch: 0
            ))
        }
    }

    private func recenterOnUser() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let userLocation = locationService.userLocation else { return }
        isMapCenteredOnUser = true
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: userLocation,
                distance: 15000,
                heading: 0,
                pitch: 0
            ))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isMapCenteredOnUser = false
        }
    }

    private func selectBoucle(_ boucle: BoucleLocation) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        selectedBoucle = boucle
        centerOnBoucle(boucle)
    }

    private func centerOnBoucle(_ boucle: BoucleLocation) {
        // Centre sur la boucle sans changer le zoom
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: boucle.centerCoordinate,
                distance: 50000,
                heading: 0,
                pitch: 0
            ))
        }
    }

    private func focusOnBoucle(_ boucle: BoucleLocation) {
        // Calculer le bounding box de la boucle
        guard !boucle.coordinates.isEmpty else { return }

        let lats = boucle.coordinates.map { $0.latitude }
        let lons = boucle.coordinates.map { $0.longitude }

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        let latSpan = maxLat - minLat
        let lonSpan = maxLon - minLon
        let maxSpan = max(latSpan, lonSpan)

        // Calculer la distance en fonction de l'étendue
        let distance = maxSpan * 111000 * 2.5 // Facteur pour avoir une marge

        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                distance: max(distance, 3000),
                heading: 0,
                pitch: 0
            ))
        }
    }

    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        let tapLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let threshold: Double = 150

        var closestBoucle: BoucleLocation?
        var closestDistance: Double = .infinity

        for boucle in randoService.boucles {
            let distance = minDistanceToPolyline(from: tapLocation, polyline: boucle.coordinates)
            if distance < closestDistance && distance < threshold {
                closestDistance = distance
                closestBoucle = boucle
            }
        }

        if let boucle = closestBoucle {
            selectBoucle(boucle)
        }
    }

    private func minDistanceToPolyline(from point: CLLocation, polyline: [CLLocationCoordinate2D]) -> Double {
        var minDistance: Double = .infinity
        for coord in polyline {
            let polylinePoint = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distance = point.distance(from: polylinePoint)
            minDistance = min(minDistance, distance)
        }
        return minDistance
    }

    private func openDirections(to boucle: BoucleLocation) {
        let startCoordinate = boucle.coordinates.first ?? boucle.centerCoordinate
        let placemark = MKPlacemark(coordinate: startCoordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Départ: \(boucle.nom)"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Boucle Metric Pill

struct BoucleMetricPill: View {
    let icon: String
    let value: String
    let label: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        )
    }
}

// MARK: - Boucle Info Section

struct BoucleInfoSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

// MARK: - Boucle Location Model

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

// MARK: - Rando API Service

@MainActor
class RandoAPIService: ObservableObject {
    @Published var boucles: [BoucleLocation] = []
    @Published var isLoading = false

    private let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:boucle-de-randonnee&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"

    func loadBoucles() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            guard let url = URL(string: apiURL) else { return }

            let (data, _) = try await URLSession.shared.data(from: url)
            let geoJsonResponse = try JSONDecoder().decode(RandoGeoJSONResponse.self, from: data)

            boucles = geoJsonResponse.features.compactMap { feature -> BoucleLocation? in
                guard !feature.geometry.coordinates.isEmpty else { return nil }

                var allCoordinates: [CLLocationCoordinate2D] = []
                for lineString in feature.geometry.coordinates {
                    for coordinate in lineString {
                        if coordinate.count >= 2 {
                            allCoordinates.append(CLLocationCoordinate2D(
                                latitude: coordinate[1],
                                longitude: coordinate[0]
                            ))
                        }
                    }
                }

                guard !allCoordinates.isEmpty else { return nil }

                let props = feature.properties
                let centerLat = allCoordinates.map { $0.latitude }.reduce(0, +) / Double(allCoordinates.count)
                let centerLon = allCoordinates.map { $0.longitude }.reduce(0, +) / Double(allCoordinates.count)

                return BoucleLocation(
                    coordinates: allCoordinates,
                    centerCoordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    nom: props.nom ?? "Boucle sans nom",
                    commune: props.commune ?? "",
                    vocation: props.vocation ?? "",
                    difficulte: props.difficulte ?? "",
                    temps: props.temps ?? "",
                    longueur: props.longueur ?? "",
                    denivele: props.denivele ?? "",
                    depart: props.depart ?? "",
                    descriptif: props.descriptif ?? "",
                    cheminement: props.cheminement ?? ""
                )
            }

            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

// MARK: - GeoJSON Models

struct RandoGeoJSONResponse: Codable {
    let features: [RandoFeature]
}

struct RandoFeature: Codable {
    let geometry: RandoGeometry
    let properties: RandoProperties
}

struct RandoGeometry: Codable {
    let coordinates: [[[Double]]]
}

struct RandoProperties: Codable {
    let nom: String?
    let vocation: String?
    let commune: String?
    let difficulte: String?
    let temps: String?
    let longueur: String?
    let denivele: String?
    let depart: String?
    let descriptif: String?
    let cheminement: String?
}

#Preview {
    RandosMapView()
}
