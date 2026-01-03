import SwiftUI
import MapKit
import Foundation

// MARK: - PoubelleMapView Style Apple Maps iOS 26

struct PoubelleMapView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var poubelleService = MapDataService(configuration: PoubelleConfiguration())
    @ObservedObject private var weatherService = AppWeatherService.shared
    @ObservedObject private var locationService = GlobalLocationService.shared
    @ObservedObject private var navigationManager = NavigationManager.shared

    // Position caméra 3D avec pitch
    @State private var cameraPosition: MapCameraPosition
    @State private var searchText = ""
    @State private var addressSuggestions: [AddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?
    @State private var isSearchMode = false
    @State private var selectedPoubelle: PoubelleLocation?

    // État de l'îlot de recherche
    @State private var isSheetExpanded = false

    // État de centrage sur l'utilisateur
    @State private var isMapCenteredOnUser = true
    @State private var isAnimatingToUser = false

    // Heading de la carte pour la boussole custom
    @State private var mapHeading: Double = 0

    // Map scope
    @Namespace private var mapScope

    @FocusState private var isSearchFocused: Bool

    // Couleur thème poubelles
    private let themeColor = Color(red: 0.55, green: 0.55, blue: 0.55)

    // État de chargement initial
    @State private var hasLoadedOnce = false

    // Computed properties pour l'overlay de chargement
    private var showLoadingOverlay: Bool {
        (!hasLoadedOnce && poubelleService.items.isEmpty) || hasLoadingError
    }

    private var hasLoadingError: Bool {
        poubelleService.errorMessage != nil && poubelleService.items.isEmpty
    }

    // MARK: - Computed Properties

    private var islandState: IslandState {
        if isSearchFocused { return .keyboard }
        if isSheetExpanded { return .expanded }
        return .collapsed
    }

    private var islandMaxHeight: CGFloat? {
        switch islandState {
        case .collapsed: return nil
        case .expanded: return UIScreen.main.bounds.height * 0.5
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

    private var currentFocusLocation: CLLocationCoordinate2D? {
        if isSearchMode, let searchLocation = searchedLocation {
            return searchLocation
        }
        return locationService.userLocation
    }

    private var nearbyPoubelles: [PoubelleLocation] {
        guard let refLoc = currentFocusLocation else { return poubelleService.items }

        return poubelleService.items
            .map { poubelle in
                let distance = CLLocation(latitude: refLoc.latitude, longitude: refLoc.longitude)
                    .distance(from: CLLocation(latitude: poubelle.coordinate.latitude, longitude: poubelle.coordinate.longitude))
                return (poubelle: poubelle, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .map { $0.poubelle }
    }

    private var topThreePoubelles: [PoubelleLocation] {
        return Array(nearbyPoubelles.prefix(5))
    }

    init() {
        let initialCenter: CLLocationCoordinate2D
        if let userLocation = GlobalLocationService.shared.userLocation {
            initialCenter = userLocation
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
        }

        _cameraPosition = State(initialValue: .camera(MapCamera(
            centerCoordinate: initialCenter,
            distance: 1000,
            heading: 0,
            pitch: 45
        )))
    }

    var body: some View {
        ZStack {
            // Carte plein écran
            modernMap
                .ignoresSafeArea(edges: .top)
                .ignoresSafeArea(.keyboard)

            // Overlay des contrôles
            VStack {
                // Header island
                MapHeaderIsland(
                    title: "Poubelles",
                    imageName: "Poubelle",
                    iconSize: 22,
                    themeColor: themeColor,
                    description: "Cette carte affiche jusqu'à 50 poubelles publiques dans un rayon de 800 m autour de votre position ou de votre recherche.",
                    dataSource: "Données ouvertes Grand Lyon",
                    dataSourceURL: "https://data.grandlyon.com",
                    onBackTapped: {
                        navigationManager.navigateToHome()
                    }
                )

                Spacer()
            }

            // Boutons météo/air + boussole + localisation à droite
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    MapControlButtons(
                        themeColor: themeColor,
                        mapHeading: mapHeading,
                        isMapCenteredOnUser: isMapCenteredOnUser,
                        weatherData: WeatherDisplayData(
                            conditionSymbol: weatherService.weatherData.conditionSymbol,
                            formattedTemperature: weatherService.weatherData.formattedTemperature,
                            airQualityColor: weatherService.weatherData.airQualityColor
                        ),
                        onWeatherTapped: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if let location = locationService.userLocation {
                                Task {
                                    await weatherService.fetchWeather(for: location)
                                }
                            }
                        },
                        onCompassTapped: resetMapToNorth,
                        onLocationTapped: recenterOnUser
                    )
                }
                .padding(.bottom, 130)
            }

            // Overlay sombre quand clavier ouvert
            Color.black.opacity(showDimOverlay ? 0.3 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(showDimOverlay)
                .onTapGesture {
                    isSearchFocused = false
                }
                .animation(IslandState.animation, value: islandState)

            // Îlot de recherche en bas
            VStack {
                Spacer()
                searchIsland
            }

            // Overlay de chargement
            if showLoadingOverlay {
                MapLoadingOverlay(
                    imageName: "Poubelle",
                    title: "Poubelles",
                    themeColor: themeColor,
                    hasError: hasLoadingError
                )
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.2)),
                    removal: .opacity.combined(with: .scale(scale: 1.1)).animation(.easeOut(duration: 0.4))
                ))
                .zIndex(100)
            }
        }
        .preferredColorScheme(nil)
        .onAppear {
            navigationManager.currentDestination = .poubelle
            setupInitialLocation()
            if let location = locationService.userLocation {
                Task {
                    await weatherService.fetchWeather(for: location)
                }
            }
        }
        .onDisappear {
            locationService.stopLocationUpdates()
        }
        .onChange(of: locationService.isLocationReady) { _, isReady in
            if isReady, let location = locationService.userLocation, !isSearchMode {
                animateToLocation(location)
                Task {
                    await poubelleService.loadAroundLocation(location)
                    await weatherService.fetchWeather(for: location)
                    hasLoadedOnce = true
                }
            }
        }
        .onChange(of: poubelleService.items.count) { _, newCount in
            if newCount > 0 {
                hasLoadedOnce = true
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            if focused {
                isSheetExpanded = true
            }
        }
        .sheet(item: $selectedPoubelle) { poubelle in
            PoubelleDetailSheet(poubelle: poubelle, userLocation: currentFocusLocation)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Search Island

    @ViewBuilder
    private var searchIsland: some View {
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
                                    isSheetExpanded = true
                                } else if value.translation.height > 50 {
                                    isSheetExpanded = false
                                    isSearchFocused = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if !isSheetExpanded && !isSearchFocused {
                        withAnimation(IslandState.animation) {
                            isSheetExpanded = true
                        }
                    }
                }

            // Champ de recherche + Logo
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Poubelles", text: $searchText)
                        .font(.system(size: 16))
                        .focused($isSearchFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { _, newValue in
                            handleSearchTextChange(newValue)
                        }
                        .onSubmit {
                            handleSearchSubmitted()
                        }

                    if !searchText.isEmpty {
                        Button(action: handleClearSearch) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.15))
                )

                Button(action: {
                    if isSearchFocused {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isSearchFocused = false
                    }
                }) {
                    ZStack {
                        Image("Poubelle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .opacity(isSearchFocused ? 0 : 1)
                            .scaleEffect(isSearchFocused ? 0.5 : 1)

                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .opacity(isSearchFocused ? 1 : 0)
                            .scaleEffect(isSearchFocused ? 1 : 0.5)
                    }
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Contenu étendu
            if isSheetExpanded {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if !searchText.isEmpty && searchedLocation != nil {
                            // Mode recherche avec pin
                            HStack {
                                Text("Poubelles proches")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                            if !topThreePoubelles.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(topThreePoubelles.prefix(3).enumerated()), id: \.element.id) { _, poubelle in
                                        Button(action: {
                                            selectPoubelleFromList(poubelle)
                                        }) {
                                            poubelleRowContent(poubelle: poubelle)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                MapEmptyStateView(imageName: "trash", message: "Aucune poubelle à proximité")
                            }

                        } else if !searchText.isEmpty {
                            // Suggestions d'adresses
                            if !addressSuggestions.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(addressSuggestions) { suggestion in
                                        AddressSuggestionRow(suggestion: suggestion) {
                                            handleSuggestionTap(suggestion)
                                        }
                                    }
                                }
                            } else {
                                MapLoadingStateView(message: "Recherche en cours...")
                            }
                        } else {
                            // Mode normal
                            HStack {
                                Text("À proximité")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                            if !topThreePoubelles.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(topThreePoubelles.prefix(3).enumerated()), id: \.element.id) { _, poubelle in
                                        Button(action: {
                                            selectPoubelleFromList(poubelle)
                                        }) {
                                            poubelleRowContent(poubelle: poubelle)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                MapEmptyStateView(imageName: "trash", message: "Aucune poubelle à proximité")
                            }

                            // Section raccourcis
                            MapShortcutsSection(currentDestination: .poubelle)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: .infinity)
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

    // MARK: - Row Content

    @ViewBuilder
    private func poubelleRowContent(poubelle: PoubelleLocation) -> some View {
        HStack(spacing: 14) {
            Image("Poubelle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 35, height: 35)

            VStack(alignment: .leading, spacing: 4) {
                Text("Poubelle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let refLoc = currentFocusLocation {
                    Text("\(formatDistance(from: refLoc, to: poubelle.coordinate)) · \(poubelle.address)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "arrow.turn.up.right")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Modern Map

    @ViewBuilder
    private var modernMap: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
            UserAnnotation()

            ForEach(nearbyPoubelles) { poubelle in
                Annotation("", coordinate: poubelle.coordinate) {
                    ModernMarkerView(imageName: "Poubelle", size: 32) {
                        selectPoubelleFromMap(poubelle)
                    }
                }
            }

            if let searchLocation = searchedLocation {
                Marker("", coordinate: searchLocation)
                    .tint(.red)
            }
        }
        .mapStyle(colorScheme == .dark ? .standard(elevation: .realistic, emphasis: .muted) : .standard(elevation: .realistic))
        .mapScope(mapScope)
        .mapControls { }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 100)
                .allowsHitTesting(false)
        }
        .onMapCameraChange(frequency: .continuous) { context in
            mapHeading = context.camera.heading

            if isMapCenteredOnUser && !isAnimatingToUser {
                isMapCenteredOnUser = false
            }
        }
    }

    // MARK: - Actions

    // Pour les marqueurs sur la map → ouvre la modale d'info
    private func selectPoubelleFromMap(_ poubelle: PoubelleLocation) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(IslandState.animation) {
            isSheetExpanded = false
            isSearchFocused = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            selectedPoubelle = poubelle
        }
    }

    // Pour les recommandations dans l'îlot → lance Maps directement
    private func selectPoubelleFromList(_ poubelle: PoubelleLocation) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        openDirections(to: poubelle)
    }

    private func openDirections(to poubelle: PoubelleLocation) {
        openDirectionsTo(coordinate: poubelle.coordinate, name: "Poubelle")
    }

    private func setupInitialLocation() {
        if let userLocation = locationService.userLocation {
            Task {
                await poubelleService.loadAroundLocation(userLocation)
                hasLoadedOnce = true
            }
        } else {
            locationService.refreshLocation()
        }
    }

    private func resetMapToNorth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let currentCenter = currentFocusLocation ?? locationService.userLocation else { return }

        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: currentCenter,
                distance: 1000,
                heading: 0,
                pitch: 45
            ))
        }
    }

    private func recenterOnUser() {
        guard let userLocation = locationService.userLocation else { return }

        if searchedLocation != nil {
            handleClearSearch()
        }

        isAnimatingToUser = true
        animateToLocation(userLocation)

        withAnimation(.easeInOut(duration: 0.2)) {
            isMapCenteredOnUser = true
        }

        Task {
            await poubelleService.loadAroundLocation(userLocation)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isAnimatingToUser = false
        }
    }

    private func animateToLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: coordinate,
                distance: 1000,
                heading: 0,
                pitch: 45
            ))
        }
    }

    private func handleSearchTextChange(_ text: String) {
        if text.count >= 1 {
            showSuggestions = true
            Task {
                let allSuggestions = await GeocodingService.shared.searchAddresses(query: text)
                addressSuggestions = Array(allSuggestions.prefix(6))
            }
        } else {
            showSuggestions = false
            addressSuggestions = []
        }
    }

    private func handleSuggestionTap(_ suggestion: AddressSuggestion) {
        searchText = suggestion.title
        showSuggestions = false
        isSearchFocused = false
        isSearchMode = true

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            if let coordinate = await GeocodingService.shared.getCoordinate(for: suggestion) {
                searchedLocation = coordinate
                await poubelleService.loadAroundLocation(coordinate)
                animateToLocation(coordinate)
            }
        }
    }

    private func handleSearchSubmitted() {
        showSuggestions = false
        isSearchFocused = false

        Task {
            if let coordinate = await GeocodingService.shared.geocodeAddress(searchText) {
                isSearchMode = true
                searchedLocation = coordinate
                await poubelleService.loadAroundLocation(coordinate)
                animateToLocation(coordinate)
            }
        }
    }

    private func handleClearSearch() {
        searchText = ""
        searchedLocation = nil
        isSearchMode = false
        showSuggestions = false
        isSearchFocused = false

        if let userLocation = locationService.userLocation {
            Task {
                await poubelleService.loadAroundLocation(userLocation)
            }
            animateToLocation(userLocation)
        }
    }
}

// MARK: - Poubelle Detail Sheet

struct PoubelleDetailSheet: View {
    let poubelle: PoubelleLocation
    let userLocation: CLLocationCoordinate2D?
    @Environment(\.colorScheme) var colorScheme

    private var distanceText: String {
        guard let userLoc = userLocation else { return "" }
        return formatDistance(from: userLoc, to: poubelle.coordinate)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Icône
            Image("Poubelle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .padding(.top, 40)

            // Infos
            VStack(spacing: 8) {
                Text("Poubelle")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)

                Text(poubelle.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if !distanceText.isEmpty {
                    Text(distanceText)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            Spacer()

            // Bouton Itinéraire
            Button(action: openNavigation) {
                Text("Itinéraire")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func openNavigation() {
        openDirectionsTo(coordinate: poubelle.coordinate, name: "Poubelle")
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
    let voie: String?
    let numerodansvoie: String?
    let commune: String?
    let gestionnaire: String?
    let support: String?
    let nom: String?
    let adresse: String?
    let code_postal: String?
    let acces_pmr: String?
    let type_corbeille: String?
    let capacite: String?
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

#Preview {
    PoubelleMapView()
}
