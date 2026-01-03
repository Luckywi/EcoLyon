import SwiftUI
import MapKit
import Foundation

// MARK: - ParcsMapView Style Apple Maps iOS 26

struct ParcsMapView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var parcsService = ParcsAPIService()
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
    @State private var selectedParc: ParcLocation?

    // État de l'îlot de recherche
    @State private var isSheetExpanded = false

    // MARK: - Computed Properties pour l'îlot (animations fluides)

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

    // État de centrage sur l'utilisateur
    @State private var isMapCenteredOnUser = true
    @State private var isAnimatingToUser = false

    // Heading de la carte pour la boussole custom
    @State private var mapHeading: Double = 0

    // Map scope pour la boussole native
    @Namespace private var mapScope

    @FocusState private var isSearchFocused: Bool

    // Couleur thème parcs
    private let themeColor = Color(red: 0xAF/255.0, green: 0xD0/255.0, blue: 0xA3/255.0)

    // État de chargement initial
    @State private var hasLoadedOnce = false

    // Computed properties pour l'overlay de chargement
    private var showLoadingOverlay: Bool {
        (!hasLoadedOnce && parcsService.parcs.isEmpty) || hasLoadingError
    }

    private var hasLoadingError: Bool {
        parcsService.errorMessage != nil && parcsService.parcs.isEmpty
    }

    // Location de référence
    private var currentFocusLocation: CLLocationCoordinate2D? {
        if isSearchMode, let searchLocation = searchedLocation {
            return searchLocation
        }
        return locationService.userLocation
    }

    private var nearbyParcs: [ParcLocation] {
        guard let refLoc = currentFocusLocation else { return parcsService.parcs }

        return parcsService.parcs
            .map { parc in
                let distance = CLLocation(latitude: refLoc.latitude, longitude: refLoc.longitude)
                    .distance(from: CLLocation(latitude: parc.coordinate.latitude, longitude: parc.coordinate.longitude))
                return (parc: parc, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .map { $0.parc }
    }

    private var topThreeParcs: [ParcLocation] {
        return Array(nearbyParcs.prefix(5))
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
            distance: 1600,
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
                // Header partagé
                MapHeaderIsland(
                    title: "Parcs & Jardins",
                    imageName: "PetJ",
                    iconSize: 28,
                    themeColor: themeColor,
                    description: "Cette carte affiche tous les parcs et jardins de la Métropole de Lyon.",
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

            // Îlot de recherche en bas (Bottom Sheet style Apple Maps)
            VStack {
                Spacer()
                searchIsland
            }

            // Overlay de chargement
            if showLoadingOverlay {
                MapLoadingOverlay(
                    imageName: "PetJ",
                    title: "Parcs",
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
            navigationManager.currentDestination = .parcs
            setupInitialLocation()
            // Charger les données météo
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
                    await parcsService.loadParcs()
                    await weatherService.fetchWeather(for: location)
                    hasLoadedOnce = true
                }
            }
        }
        .onChange(of: parcsService.parcs.count) { _, newCount in
            if newCount > 0 {
                hasLoadedOnce = true
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            if focused {
                isSheetExpanded = true
            }
        }
        .sheet(item: $selectedParc) { parc in
            ParcDetailSheet(parc: parc, userLocation: currentFocusLocation)
                .presentationDetents([.height(sheetHeight(for: parc))])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Îlot de recherche style Apple Maps iOS 26

    @ViewBuilder
    private var searchIsland: some View {
        VStack(spacing: 0) {
            // Handle de drag (gesture uniquement ici)
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

            // Champ de recherche + Logo Parc
            HStack(spacing: 12) {
                // Champ input compact
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Parcs & Jardins", text: $searchText)
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

                // Logo Parc ou bouton fermer
                Button(action: {
                    if isSearchFocused {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isSearchFocused = false
                    }
                }) {
                    ZStack {
                        Image("PetJ")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 38, height: 38)
                            .opacity(isSearchFocused ? 0 : 1)
                            .scaleEffect(isSearchFocused ? 0.5 : 1)

                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 38, height: 38)
                            .opacity(isSearchFocused ? 1 : 0)
                            .scaleEffect(isSearchFocused ? 1 : 0.5)
                    }
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Contenu étendu - scrollable
            if isSheetExpanded {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Mode recherche avec pin placé : afficher les parcs proches du pin
                        if !searchText.isEmpty && searchedLocation != nil {
                            // Titre section
                            HStack {
                                Text("Parcs proches")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                            // Liste des 3 parcs les plus proches du pin
                            if !topThreeParcs.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(topThreeParcs.prefix(3).enumerated()), id: \.element.id) { index, parc in
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            openDirections(to: parc)
                                        }) {
                                            HStack(spacing: 14) {
                                                Image("PetJ")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 44, height: 44)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(parc.name)
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)

                                                    if let pinLoc = searchedLocation {
                                                        Text("\(formatDistance(from: pinLoc, to: parc.coordinate)) · \(parc.commune)")
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
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.5))

                                    Text("Aucun parc à proximité")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }

                        // Mode recherche sans pin : afficher les suggestions
                        } else if !searchText.isEmpty {
                            if !addressSuggestions.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(addressSuggestions) { suggestion in
                                        Button(action: {
                                            handleSuggestionTap(suggestion)
                                        }) {
                                            HStack(spacing: 14) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.red.opacity(0.8))

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(suggestion.title)
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)

                                                    Text(suggestion.subtitle)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }

                                                Spacer()

                                                Image(systemName: "arrow.turn.up.right")
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 14)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                // État chargement ou pas de résultats
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.2)

                                    Text("Recherche en cours...")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        } else {
                            // Mode normal : À proximité + Explorer aussi
                            // Titre section
                            HStack {
                                Text("À proximité")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                            // Liste des 3 parcs les plus proches
                            if !topThreeParcs.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(topThreeParcs.prefix(3).enumerated()), id: \.element.id) { index, parc in
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            openDirections(to: parc)
                                        }) {
                                            HStack(spacing: 14) {
                                                // Icône parc
                                                Image("PetJ")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 44, height: 44)

                                                // Infos parc
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(parc.name)
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)

                                                    if let userLoc = currentFocusLocation {
                                                        Text("\(formatDistance(from: userLoc, to: parc.coordinate)) · \(parc.commune)")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                }

                                                Spacer()

                                                // Icône itinéraire
                                                Image(systemName: "arrow.turn.up.right")
                                                    .font(.system(size: 20, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 14)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                // État vide
                                VStack(spacing: 12) {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.5))

                                    Text("Aucun parc à proximité")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }

                            // Section raccourcis autres maps
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Explorer aussi")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 12)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        MapShortcutButton(imageName: "Fontaine", label: "Fontaines") {
                                            navigationManager.navigate(to: .fontaines)
                                        }
                                        MapShortcutButton(imageName: "Wc", label: "Toilettes") {
                                            navigationManager.navigate(to: .toilets)
                                        }
                                        MapShortcutButton(imageName: "Banc", label: "Bancs") {
                                            navigationManager.navigate(to: .bancs)
                                        }
                                        MapShortcutButton(imageName: "Poubelle", label: "Poubelles") {
                                            navigationManager.navigate(to: .poubelle)
                                        }
                                        MapShortcutButton(imageName: "Silos", label: "Silos") {
                                            navigationManager.navigate(to: .silos)
                                        }
                                        MapShortcutButton(imageName: "Borne", label: "Bornes") {
                                            navigationManager.navigate(to: .bornes)
                                        }
                                        MapShortcutButton(imageName: "Compost", label: "Compost") {
                                            navigationManager.navigate(to: .compost)
                                        }
                                        MapShortcutButton(imageName: "Rando", label: "Randos") {
                                            navigationManager.navigate(to: .randos)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 40)
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

    // MARK: - Ouvrir itinéraire vers parc

    private func openDirections(to parc: ParcLocation) {
        let placemark = MKPlacemark(coordinate: parc.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = parc.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    // MARK: - Helper pour formater la distance

    private func formatDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let meters = fromLoc.distance(from: toLoc)

        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    // MARK: - Carte 3D Moderne

    @ViewBuilder
    private var modernMap: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
            // Position utilisateur
            UserAnnotation()

            // Marqueurs parcs
            ForEach(nearbyParcs) { parc in
                Annotation("", coordinate: parc.coordinate) {
                    ModernParcMarker(parc: parc, themeColor: themeColor) {
                        // Fermer l'îlot puis ouvrir la modale d'info
                        withAnimation(IslandState.animation) {
                            isSheetExpanded = false
                            isSearchFocused = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            selectedParc = parc
                        }
                    }
                }
            }

            // Pin de recherche (natif Apple)
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

    // MARK: - Sheet Height Calculator

    private func sheetHeight(for parc: ParcLocation) -> CGFloat {
        // Base: drag indicator (30) + top padding (32) + icon (80) + spacing (20) + name section (~80)
        var height: CGFloat = 242

        // Surface section (HStack + paddings)
        if parc.surface != nil {
            height += 90
        }

        // Secondary info (divider + padding + info cells)
        let hasSecondaryInfo = !parc.gestionnaire.isEmpty || !parc.horaires.isEmpty || !parc.type.isEmpty
        if hasSecondaryInfo {
            height += 100
        }

        // Water/toilets line
        if parc.hasWater || parc.hasToilets {
            height += 45
        }

        // Button (50) + padding bottom (20) + safe area buffer (30)
        height += 100

        return height
    }

    // MARK: - Actions

    private func setupInitialLocation() {
        if let userLocation = locationService.userLocation {
            Task {
                await parcsService.loadParcs()
                hasLoadedOnce = true
            }
        } else {
            locationService.refreshLocation()
        }
    }

    /// Remet la carte orientée vers le Nord
    private func resetMapToNorth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        guard let userLocation = locationService.userLocation else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: userLocation,
                    distance: 1500,
                    heading: 0,
                    pitch: 45
                )
            )
        }
    }

    /// Recentre toujours sur la position de l'utilisateur et nettoie la recherche
    private func recenterOnUser() {
        guard let userLocation = locationService.userLocation else { return }

        // Si un pin est présent, nettoyer la recherche
        if searchedLocation != nil {
            handleClearSearch()
        }

        isAnimatingToUser = true
        animateToLocation(userLocation)

        withAnimation(.easeInOut(duration: 0.2)) {
            isMapCenteredOnUser = true
        }

        // Reset le flag après l'animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isAnimatingToUser = false
        }
    }

    private func animateToLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: coordinate,
                distance: 1600,
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
            animateToLocation(userLocation)
        }
    }
}

// MARK: - Marqueur Parc Moderne

struct ModernParcMarker: View {
    let parc: ParcLocation
    let themeColor: Color
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        }) {
            Image("PetJ")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .isometric3D(angle: 20, intensity: 0.4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
    }
}

// MARK: - Detail Sheet Parc

struct ParcDetailSheet: View {
    let parc: ParcLocation
    let userLocation: CLLocationCoordinate2D?
    @Environment(\.colorScheme) var colorScheme

    private var distanceText: String {
        guard let userLoc = userLocation else { return "" }
        let from = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let to = CLLocation(latitude: parc.coordinate.latitude, longitude: parc.coordinate.longitude)
        let meters = from.distance(from: to)

        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    private var surfaceValue: String {
        guard let s = parc.surface else { return "" }
        if s >= 10000 {
            return String(format: "%.1f", s / 10000)
        } else {
            return String(format: "%.0f", s)
        }
    }

    private var surfaceUnit: String {
        guard let s = parc.surface else { return "" }
        return s >= 10000 ? "ha" : "m²"
    }

    // Compte les infos secondaires disponibles
    private var hasSecondaryInfo: Bool {
        !parc.gestionnaire.isEmpty || !parc.horaires.isEmpty || !parc.type.isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header avec icône
            Image("PetJ")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .padding(.top, 32)

            // Nom et adresse
            VStack(spacing: 6) {
                Text(parc.name)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(parc.commune)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if !distanceText.isEmpty {
                    Text(distanceText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // Infos principales : Surface et Clos
            if parc.surface != nil {
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(surfaceValue)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(surfaceUnit)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    if parc.clos {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 1, height: 44)

                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                            Text("Clos")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            // Divider seulement si on a des infos secondaires
            if hasSecondaryInfo {
                Divider()
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)

                // Infos secondaires : Gestionnaire, Horaires, Type
                HStack(alignment: .center, spacing: 0) {
                    if !parc.gestionnaire.isEmpty {
                        ParcInfoCell(value: parc.gestionnaire, label: "Gestionnaire")
                    }

                    if !parc.gestionnaire.isEmpty && !parc.horaires.isEmpty {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 1, height: 44)
                    }

                    if !parc.horaires.isEmpty {
                        ParcInfoCell(value: parc.horaires, label: "Horaires")
                    }

                    if (!parc.gestionnaire.isEmpty || !parc.horaires.isEmpty) && !parc.type.isEmpty {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 1, height: 44)
                    }

                    if !parc.type.isEmpty {
                        ParcInfoCell(value: parc.type, label: "Équipements")
                    }
                }
                .padding(.horizontal, 24)
            }

            // Accessibilité PMR style (comme BorneDetailSheet)
            if parc.hasWater || parc.hasToilets {
                HStack(spacing: 6) {
                    if parc.hasWater {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Point d'eau")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    if parc.hasWater && parc.hasToilets {
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    if parc.hasToilets {
                        Image(systemName: "toilet.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Toilettes")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 12)
            }

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
        let placemark = MKPlacemark(coordinate: parc.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = parc.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Parc Info Cell Component

struct ParcInfoCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Parc Location Model

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
    let horaires: String
    let clos: Bool
    let hasWater: Bool
    let hasToilets: Bool
    let dogAllowed: Bool
}

// MARK: - Parcs API Service

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

            var request = URLRequest(url: url)
            request.timeoutInterval = 15.0

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw ParcsAPIError.invalidResponse
            }

            let geoJsonResponse = try JSONDecoder().decode(ParcsGeoJSONResponse.self, from: data)

            let parcLocations = geoJsonResponse.features.compactMap { feature -> ParcLocation? in
                guard let centerCoordinate = extractCenterFromGeometry(feature.geometry) else { return nil }
                let props = feature.properties

                // Parser les horaires correctement
                var horairesValue = ""
                if let h = props.horaires, !h.isEmpty {
                    horairesValue = h
                } else if let oh = props.openinghours, oh != "[]", !oh.isEmpty {
                    horairesValue = oh
                }

                // Parser chien correctement - seulement si explicitement autorisé
                let chienLower = props.chien?.lowercased() ?? ""
                let dogIsAllowed = chienLower.contains("laisse") || chienLower.contains("libres") || chienLower.contains("libre")

                return ParcLocation(
                    coordinate: centerCoordinate,
                    name: props.nom ?? "Parc",
                    address: formatAddress(props),
                    commune: props.commune ?? "",
                    surface: props.surf_tot_m2,
                    hasPlayground: hasPlaygroundEquipment(props),
                    hasSportsArea: hasSportsEquipment(props),
                    type: props.type_equip ?? "",
                    gestionnaire: props.gestion ?? "",
                    horaires: horairesValue,
                    clos: props.clos?.lowercased() == "oui",
                    hasWater: props.eau?.lowercased() == "oui",
                    hasToilets: props.toilettes?.lowercased() == "oui",
                    dogAllowed: dogIsAllowed
                )
            }

            parcs = parcLocations
            isLoading = false

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func extractCenterFromGeometry(_ geometry: ParcsGeometry) -> CLLocationCoordinate2D? {
        guard geometry.type == "MultiPolygon",
              let firstPolygon = geometry.coordinates.first,
              let outerRing = firstPolygon.first else { return nil }
        return calculatePolygonCenter(outerRing)
    }

    private func calculatePolygonCenter(_ coordinates: [[Double]]) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }

        var totalLat = 0.0
        var totalLon = 0.0
        var validCount = 0

        for coord in coordinates {
            guard coord.count >= 2 else { continue }
            let longitude = coord[0]
            let latitude = coord[1]

            if latitude >= 45.0 && latitude <= 46.0 && longitude >= 4.0 && longitude <= 5.0 {
                totalLon += longitude
                totalLat += latitude
                validCount += 1
            }
        }

        guard validCount > 0 else { return nil }
        return CLLocationCoordinate2D(latitude: totalLat / Double(validCount), longitude: totalLon / Double(validCount))
    }

    private func formatAddress(_ props: ParcsProperties) -> String {
        var parts: [String] = []
        if let voie = props.voie, !voie.isEmpty {
            if let numvoie = props.numvoie, !numvoie.isEmpty {
                parts.append("\(numvoie) \(voie)")
            } else {
                parts.append(voie)
            }
        }
        if let codepost = props.codepost, let commune = props.commune {
            parts.append("\(codepost) \(commune)")
        } else if let commune = props.commune {
            parts.append(commune)
        }
        return parts.isEmpty ? "Adresse non disponible" : parts.joined(separator: ", ")
    }

    private func hasPlaygroundEquipment(_ props: ParcsProperties) -> Bool {
        let name = props.nom?.lowercased() ?? ""
        let type = props.type_equip?.lowercased() ?? ""
        return name.contains("jeux") || name.contains("enfant") || name.contains("aire") || type.contains("jeux") || type.contains("aire")
    }

    private func hasSportsEquipment(_ props: ParcsProperties) -> Bool {
        let name = props.nom?.lowercased() ?? ""
        let type = props.type_equip?.lowercased() ?? ""
        return name.contains("sport") || name.contains("terrain") || name.contains("stade") || type.contains("sport") || type.contains("terrain")
    }
}

// MARK: - GeoJSON Models

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

struct ParcsGeometry: Codable {
    let type: String
    let coordinates: [[[[Double]]]]
}

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
        case .invalidURL: return "URL invalide"
        case .invalidResponse: return "Réponse serveur invalide"
        case .httpError(let code): return "Erreur HTTP \(code)"
        }
    }
}

#Preview {
    ParcsMapView()
}
