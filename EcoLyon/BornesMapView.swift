import SwiftUI
import MapKit
import Foundation

// MARK: - BornesMapView Style Apple Maps iOS 26

struct BornesMapView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var chargingStationService = ChargingStationAPIService()
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
    @State private var selectedStation: ChargingStationLocation?

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

    // Couleur thème bornes
    private let themeColor = Color(red: 0.5, green: 0.6, blue: 0.7)

    // État de chargement initial
    @State private var hasLoadedOnce = false

    // Computed properties pour l'overlay de chargement
    private var showLoadingOverlay: Bool {
        (!hasLoadedOnce && chargingStationService.stations.isEmpty) || hasLoadingError
    }

    private var hasLoadingError: Bool {
        chargingStationService.errorMessage != nil && chargingStationService.stations.isEmpty
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

    private var nearbyStations: [ChargingStationLocation] {
        guard let refLoc = currentFocusLocation else { return chargingStationService.stations }

        return chargingStationService.stations
            .map { station in
                let distance = CLLocation(latitude: refLoc.latitude, longitude: refLoc.longitude)
                    .distance(from: CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude))
                return (station: station, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .map { $0.station }
    }

    private var topThreeStations: [ChargingStationLocation] {
        return Array(nearbyStations.prefix(5))
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
                // Header island
                MapHeaderIsland(
                    title: "Bornes",
                    imageName: "Borne",
                    iconSize: 22,
                    themeColor: themeColor,
                    description: "Cette carte répertorie toutes les stations de recharge pour véhicules électriques situées dans les 9 arrondissements de Lyon.",
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
                    imageName: "Borne",
                    title: "Bornes",
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
            navigationManager.currentDestination = .bornes
            setupInitialLocation()
            loadChargingStations()
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
                    await weatherService.fetchWeather(for: location)
                }
            }
        }
        .onChange(of: chargingStationService.stations.count) { _, newCount in
            if newCount > 0 {
                hasLoadedOnce = true
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            if focused {
                isSheetExpanded = true
            }
        }
        .sheet(item: $selectedStation) { station in
            BorneDetailSheet(station: station, userLocation: currentFocusLocation)
                .presentationDetents([.height(520)])
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

                    TextField("Stations de recharge", text: $searchText)
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

                // Logo ou bouton fermer
                Button(action: {
                    if isSearchFocused {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isSearchFocused = false
                    }
                }) {
                    ZStack {
                        Image("Borne")
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
                            // Mode recherche avec pin placé
                            HStack {
                                Text("Stations proches")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                            if !topThreeStations.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(topThreeStations.prefix(3).enumerated()), id: \.element.id) { _, station in
                                        Button(action: {
                                            selectStation(station)
                                        }) {
                                            stationRowContent(station: station)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                MapEmptyStateView(imageName: "bolt.car", message: "Aucune station à proximité")
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

                            if !topThreeStations.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(topThreeStations.prefix(3).enumerated()), id: \.element.id) { _, station in
                                        Button(action: {
                                            selectStation(station)
                                        }) {
                                            stationRowContent(station: station)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else if chargingStationService.isLoading {
                                MapLoadingStateView(message: "Chargement des stations...")
                            } else {
                                MapEmptyStateView(imageName: "bolt.car", message: "Aucune station à proximité")
                            }

                            // Section raccourcis
                            MapShortcutsSection(currentDestination: .bornes)
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
        .animation(IslandState.animation, value: islandState)
    }

    // MARK: - Station Row Content

    @ViewBuilder
    private func stationRowContent(station: ChargingStationLocation) -> some View {
        HStack(spacing: 14) {
            Image("Borne")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 35, height: 35)

            VStack(alignment: .leading, spacing: 4) {
                Text(station.stationName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let refLoc = currentFocusLocation {
                    Text("\(formatDistance(from: refLoc, to: station.coordinate)) · \(station.address)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
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

            ForEach(chargingStationService.stations) { station in
                Annotation("", coordinate: station.coordinate) {
                    ModernMarkerView(imageName: "Borne", size: 32) {
                        selectStation(station)
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

    private func selectStation(_ station: ChargingStationLocation) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Fermer l'îlot avant d'ouvrir la sheet
        withAnimation(IslandState.animation) {
            isSheetExpanded = false
            isSearchFocused = false
        }
        // Petit délai pour laisser l'animation se terminer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            selectedStation = station
        }
    }

    private func setupInitialLocation() {
        if locationService.userLocation == nil {
            locationService.refreshLocation()
        }
    }

    private func loadChargingStations() {
        Task {
            await chargingStationService.loadAllChargingStations()
            hasLoadedOnce = true
        }
    }

    private func resetMapToNorth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let userLocation = locationService.userLocation else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: userLocation,
                    distance: 1600,
                    heading: 0,
                    pitch: 45
                )
            )
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

// MARK: - Borne Detail Sheet

struct BorneDetailSheet: View {
    let station: ChargingStationLocation
    let userLocation: CLLocationCoordinate2D?
    @Environment(\.colorScheme) var colorScheme

    private var distanceText: String {
        guard let userLoc = userLocation else { return "" }
        return formatDistance(from: userLoc, to: station.coordinate)
    }

    private var connectorsText: String {
        station.connectorTypes.map { $0.rawValue }.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header avec icône
            Image("Borne")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .padding(.top, 32)

            // Nom et adresse
            VStack(spacing: 6) {
                Text(station.stationName)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(station.address)
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

            // Infos principales : kW et Bornes
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(Int(station.power))")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("kW")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1, height: 44)

                VStack(spacing: 4) {
                    Text("\(station.pointCount)")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(station.pointCount > 1 ? "bornes" : "borne")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Divider()
                .padding(.horizontal, 40)
                .padding(.vertical, 12)

            // Infos secondaires : Entreprise, Horaires, Type
            HStack(alignment: .center, spacing: 0) {
                InfoCell(value: station.operatorName, label: "Entreprise")

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1, height: 44)

                InfoCell(value: station.schedule, label: "Horaires")

                if !station.connectorTypes.isEmpty {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1, height: 44)

                    InfoCell(value: connectorsText, label: "Type")
                }
            }
            .padding(.horizontal, 24)

            // Accessibilité PMR
            if station.isAccessible {
                HStack(spacing: 6) {
                    Image(systemName: "figure.roll")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("Accessible PMR")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
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
        openDirectionsTo(coordinate: station.coordinate, name: station.stationName)
    }
}

// MARK: - Info Cell Component

struct InfoCell: View {
    var value: String? = nil
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            if let val = value {
                Text(val)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .frame(height: 34, alignment: .center)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

// MARK: - Service API et modèles

@MainActor
class ChargingStationAPIService: ObservableObject {
    @Published var stations: [ChargingStationLocation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let lyonDistricts = [
        "69381", "69382", "69383", "69384", "69385",
        "69386", "69387", "69388", "69389"
    ]

    func loadAllChargingStations() async {
        isLoading = true
        errorMessage = nil

        do {
            let allStations = try await withThrowingTaskGroup(of: [ChargingStationLocation].self) { group in
                for district in lyonDistricts {
                    group.addTask {
                        await self.loadDistrictStations(district: district)
                    }
                }

                var combinedStations: [ChargingStationLocation] = []
                for try await districtStations in group {
                    combinedStations.append(contentsOf: districtStations)
                }

                return combinedStations
            }

            stations = groupStationsByLocation(allStations)
            isLoading = false

        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func loadDistrictStations(district: String) async -> [ChargingStationLocation] {
        let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:nrj_energie.irve&SRSNAME=EPSG:4171&outputFormat=application/json&CQL_FILTER=code_insee_commune=\(district)&startIndex=0&sortby=gid"

        do {
            guard let url = URL(string: apiURL) else { return [] }

            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                return []
            }

            let geoJsonResponse = try JSONDecoder().decode(IRVEGeoJSONResponse.self, from: data)
            return parseStationsFromFeatures(geoJsonResponse.features)

        } catch {
            return []
        }
    }

    private func parseStationsFromFeatures(_ features: [IRVEFeature]) -> [ChargingStationLocation] {
        return features.compactMap { feature -> ChargingStationLocation? in
            guard feature.geometry.coordinates.count >= 2 else { return nil }

            let longitude = feature.geometry.coordinates[0]
            let latitude = feature.geometry.coordinates[1]
            let props = feature.properties

            let connectors = determineConnectorTypes(props)

            return ChargingStationLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                stationName: props.nom_station ?? "Borne de recharge",
                address: props.adresse_station ?? "Adresse non disponible",
                operatorName: props.nom_operateur ?? "Opérateur non spécifié",
                power: props.puissance_nominale ?? 0,
                connectorTypes: connectors,
                pointCount: 1,
                accessibilityStatus: props.accessibilite_pmr ?? "Accessibilité inconnue",
                isFree: props.gratuit == true,
                isOpen: true,
                schedule: props.horaires ?? "Non spécifié",
                accessCondition: props.condition_acces ?? "Non spécifié"
            )
        }
    }

    private func determineConnectorTypes(_ props: IRVEProperties) -> [ConnectorType] {
        var connectors: [ConnectorType] = []

        if props.prise_type_2 == true { connectors.append(.type2) }
        if props.prise_type_combo_ccs == true { connectors.append(.comboCCS) }
        if props.prise_type_chademo == true { connectors.append(.chademo) }
        if props.prise_type_ef == true { connectors.append(.ef) }

        return connectors.isEmpty ? [.type2] : connectors
    }

    private func groupStationsByLocation(_ stations: [ChargingStationLocation]) -> [ChargingStationLocation] {
        let grouped = Dictionary(grouping: stations) { station in
            let lat = round(station.coordinate.latitude * 1000000) / 1000000
            let lon = round(station.coordinate.longitude * 1000000) / 1000000
            return "\(lat)_\(lon)"
        }

        return grouped.compactMap { (_, stationsGroup) -> ChargingStationLocation? in
            guard let firstStation = stationsGroup.first else { return nil }

            if stationsGroup.count == 1 { return firstStation }

            let combinedConnectors = stationsGroup.flatMap { $0.connectorTypes }
            let maxPower = stationsGroup.map { $0.power }.max() ?? 0
            let combinedPointCount = stationsGroup.count

            return ChargingStationLocation(
                coordinate: firstStation.coordinate,
                stationName: firstStation.stationName,
                address: firstStation.address,
                operatorName: firstStation.operatorName,
                power: maxPower,
                connectorTypes: Array(Set(combinedConnectors)),
                pointCount: combinedPointCount,
                accessibilityStatus: firstStation.accessibilityStatus,
                isFree: stationsGroup.contains { $0.isFree },
                isOpen: stationsGroup.allSatisfy { $0.isOpen },
                schedule: firstStation.schedule,
                accessCondition: firstStation.accessCondition
            )
        }
    }
}

// MARK: - Modèles de données

struct ChargingStationLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let stationName: String
    let address: String
    let operatorName: String
    let power: Double
    let connectorTypes: [ConnectorType]
    let pointCount: Int
    let accessibilityStatus: String
    let isFree: Bool
    let isOpen: Bool
    let schedule: String
    let accessCondition: String

    var isAccessible: Bool {
        return accessibilityStatus.lowercased().contains("oui")
    }
}

enum ConnectorType: String, CaseIterable, Hashable {
    case type2 = "Type 2"
    case comboCCS = "Combo CCS"
    case chademo = "CHAdeMO"
    case ef = "EF"

    var symbol: String {
        switch self {
        case .type2: return "🔌"
        case .comboCCS: return "⚡"
        case .chademo: return "🔋"
        case .ef: return "🏠"
        }
    }
}

struct IRVEGeoJSONResponse: Codable {
    let type: String
    let features: [IRVEFeature]
    let totalFeatures: Int?
}

struct IRVEFeature: Codable {
    let type: String
    let geometry: IRVEGeometry
    let properties: IRVEProperties
}

struct IRVEGeometry: Codable {
    let type: String
    let coordinates: [Double]
}

struct IRVEProperties: Codable {
    let nom_station: String?
    let adresse_station: String?
    let nom_operateur: String?
    let nom_enseigne: String?
    let puissance_nominale: Double?
    let prise_type_2: Bool?
    let prise_type_combo_ccs: Bool?
    let prise_type_chademo: Bool?
    let prise_type_ef: Bool?
    let gratuit: Bool?
    let accessibilite_pmr: String?
    let horaires: String?
    let condition_acces: String?
    let gid: Int?
}

#Preview {
    BornesMapView()
}
