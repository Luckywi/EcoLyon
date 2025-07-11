import SwiftUI
import MapKit
import Foundation

// MARK: - BornesMapView
struct BornesMapView: View {
    @StateObject private var chargingStationService = ChargingStationAPIService()
    @StateObject private var locationService = GlobalLocationService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    
    // Region et états
    @State private var region: MKCoordinateRegion
    @State private var searchText = ""
    @State private var addressSuggestions: [AddressSuggestion] = []
    @State private var showSuggestions = false
    @State private var searchedLocation: CLLocationCoordinate2D?
    
    // ✅ NOUVEAU - État pour la modale
    @State private var selectedStation: ChargingStationLocation?
    @State private var showStationDetail = false
    
    // ✅ COULEUR UNIFIÉE pour les bornes électriques
    private let bornesThemeColor = Color(red: 0.5, green: 0.6, blue: 0.7)
    
    // ✅ Computed property pour les 3 bornes les plus proches
    private var nearestStations: [ChargingStationLocation] {
        guard let userLocation = locationService.userLocation else { return [] }

// MARK: - ✅ MODALE DÉTAIL DE LA STATION
struct StationDetailView: View {
    let station: ChargingStationLocation
    let userLocation: CLLocationCoordinate2D?
    let themeColor: Color
    @Environment(\.dismiss) private var dismiss
    
    private var distance: String? {
        guard let userLocation = userLocation else { return nil }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let stationLocation = CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: stationLocation)
        
        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters))m"
        } else {
            return String(format: "%.1fkm", distanceInMeters / 1000)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ✅ EN-TÊTE AVEC ICÔNE ET NOM
                    HStack(spacing: 16) {
                        Image("Borne")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(themeColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.stationName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let distance = distance {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(themeColor)
                                        .font(.caption)
                                    Text("À \(distance)")
                                        .font(.subheadline)
                                        .foregroundColor(themeColor)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top)
                    
                    // ✅ INFORMATIONS PRINCIPALES
                    VStack(spacing: 16) {
                        // Adresse
                        InfoRowView(
                            icon: "location.circle.fill",
                            title: "Adresse",
                            value: station.address,
                            color: themeColor
                        )
                        
                        // Opérateur
                        InfoRowView(
                            icon: "building.2.fill",
                            title: "Opérateur",
                            value: station.operatorName,
                            color: themeColor
                        )
                        
                        // Nombre de points de charge
                        InfoRowView(
                            icon: "bolt.circle.fill",
                            title: "Points de charge",
                            value: "\(station.pointCount) borne\(station.pointCount > 1 ? "s" : "")",
                            color: themeColor
                        )
                        
                        // Puissance maximale
                        InfoRowView(
                            icon: "gauge.high",
                            title: "Puissance max",
                            value: "\(Int(station.power)) kW",
                            color: themeColor
                        )
                    }
                    
                    // ✅ TYPES DE CONNECTEURS
                    if !station.connectorTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Types de connecteurs")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(station.connectorTypes, id: \.self) { connector in
                                    HStack(spacing: 8) {
                                        Text(connector.symbol)
                                            .font(.title2)
                                        Text(connector.rawValue)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(themeColor.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeColor.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    
                    // ✅ BADGES STATUTS
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statut")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            // Badge Accessibilité avec 3 états
                            StatusBadgeView(
                                text: {
                                    let status = station.accessibilityStatus.lowercased()
                                    if status.contains("oui") {
                                        return "♿ Accessible PMR"
                                    } else if status.contains("non") {
                                        return "♿ Non accessible PMR"
                                    } else {
                                        return "♿ Accessibilité inconnue"
                                    }
                                }(),
                                color: {
                                    let status = station.accessibilityStatus.lowercased()
                                    if status.contains("oui") {
                                        return .green
                                    } else if status.contains("non") {
                                        return .red
                                    } else {
                                        return .orange
                                    }
                                }()
                            )
                            
                            // Badge Gratuit
                            if station.isFree {
                                StatusBadgeView(
                                    text: "🆓 Gratuit",
                                    color: .blue
                                )
                            }
                        }
                        
                        // Badge Horaires
                        StatusBadgeView(
                            text: "🕒 \(station.schedule)",
                            color: themeColor
                        )
                    }
                    
                    // ✅ INFORMATIONS COMPLÉMENTAIRES
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conditions d'accès")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(station.accessCondition)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Détails de la station")
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
        .overlay(alignment: .bottom) {
            // ✅ BOUTON Y ALLER EN BAS
            Button(action: {
                openNavigationToStation()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Y aller")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(themeColor)
                .cornerRadius(12)
                .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    private func openNavigationToStation() {
        let coordinate = station.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = station.stationName
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            MKLaunchOptionsShowsTrafficKey: true
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation en voiture lancée vers: \(station.stationName) (\(coordinate.latitude), \(coordinate.longitude))")
        
        dismiss()
    }
}

// MARK: - Composants UI pour la modale

struct InfoRowView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

struct StatusBadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

// MARK: - Service API et modèles
        
        return chargingStationService.stations
            .map { station in
                let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    .distance(from: CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude))
                return (station: station, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(3)
            .map { $0.station }
    }
    
    // ✅ Initializer personnalisé
    init() {
        let initialCenter: CLLocationCoordinate2D
        if let userLocation = GlobalLocationService.shared.userLocation {
            initialCenter = userLocation
            print("🎯 Bornes: Initialisation avec position utilisateur")
        } else {
            initialCenter = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
            print("🏛️ Bornes: Initialisation avec Bellecour (fallback)")
        }
        
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
        ))
    }
    
    var body: some View {
        // ✅ STRUCTURE IDENTIQUE À TOILETTESMAPVIEW
        ZStack {
            // ✅ Contenu principal dans ScrollView
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ✅ TITRE FIXE EN HAUT
                    HStack(spacing: 12) {
                        Image("Borne")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(bornesThemeColor)
                        
                        Text("Stations de Recharge")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // ✅ Barre de recherche
                    VStack(spacing: 0) {
                        SmartSearchBarView(
                            searchText: $searchText,
                            suggestions: addressSuggestions,
                            showSuggestions: $showSuggestions,
                            onSearchTextChanged: handleSearchTextChange,
                            onSuggestionTapped: handleSuggestionTap,
                            onSearchSubmitted: handleSearchSubmitted,
                            themeColor: bornesThemeColor
                        )
                        
                        if showSuggestions && !addressSuggestions.isEmpty {
                            SuggestionsListView(
                                suggestions: addressSuggestions,
                                onSuggestionTapped: handleSuggestionTap
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Carte
                    BornesMapBoxView(
                        region: $region,
                        stations: chargingStationService.stations,
                        userLocation: locationService.userLocation,
                        searchedLocation: searchedLocation,
                        isLoading: chargingStationService.isLoading,
                        themeColor: bornesThemeColor,
                        onStationTapped: { station in
                            print("🎯 Station sélectionnée: \(station.stationName)")
                            selectedStation = station
                            // Petit délai pour s'assurer que la station est bien assignée
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showStationDetail = true
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // ✅ Section des 3 bornes les plus proches
                    if !nearestStations.isEmpty && locationService.userLocation != nil {
                        NearestBornesView(
                            stations: nearestStations,
                            userLocation: locationService.userLocation!,
                            themeColor: bornesThemeColor,
                            onStationTapped: { station in
                                print("🎯 Station proche sélectionnée: \(station.stationName)")
                                selectedStation = station
                                // Petit délai pour s'assurer que la station est bien assignée
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showStationDetail = true
                                }
                            }
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    
                    // ✅ ESPACE POUR LE MENU EN BAS
                    Spacer(minLength: 120)
                }
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            .refreshable {
                await chargingStationService.loadAllChargingStations()
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
                themeColor: bornesThemeColor
            )
        }
        .onAppear {
            navigationManager.currentDestination = "bornes"
            setupInitialLocation()
            loadChargingStations()
        }
        .onDisappear {
            locationService.stopLocationUpdates()
        }
        .onChange(of: locationService.isLocationReady) { isReady in
            if isReady, let location = locationService.userLocation {
                centerMapOnLocation(location)
                print("📍 Bornes: Position mise à jour automatiquement")
            }
        }
        .overlay {
            if chargingStationService.isLoading && chargingStationService.stations.isEmpty {
                LoadingOverlayView(themeColor: bornesThemeColor)
            }
        }
        .overlay {
            if let errorMessage = chargingStationService.errorMessage {
                ErrorOverlayView(message: errorMessage, themeColor: bornesThemeColor) {
                    loadChargingStations()
                }
            }
        }
        .sheet(isPresented: $showStationDetail) {
            if let station = selectedStation {
                StationDetailView(
                    station: station,
                    userLocation: locationService.userLocation,
                    themeColor: bornesThemeColor
                )
                .onAppear {
                    print("🔍 Modale ouverte pour: \(station.stationName)")
                }
            }
        }
        .onChange(of: showStationDetail) { isShowing in
            print("📱 État modale: \(isShowing ? "Ouverte" : "Fermée")")
            if !isShowing {
                // Reset de la station sélectionnée après fermeture
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedStation = nil
                }
            }
        }
    }
    
    // MARK: - Fonctions
    
    private func setupInitialLocation() {
        print("🗺️ Setup initial - bornes")
        
        if locationService.userLocation == nil {
            print("🔄 Position pas encore disponible, refresh en cours...")
            locationService.refreshLocation()
        } else {
            print("✅ Position déjà disponible depuis l'init")
        }
    }
    
    private func loadChargingStations() {
        Task {
            await chargingStationService.loadAllChargingStations()
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
    
    private func centerMapOnLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region.center = coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009)
        }
    }
    
    // Fonctions de géocodage (identiques à ToiletsMapView)
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

// MARK: - ✅ Section des bornes les plus proches
struct NearestBornesView: View {
    let stations: [ChargingStationLocation]
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    let onStationTapped: (ChargingStationLocation) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête
            HStack {
                Text("Stations les plus proches")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Liste des 3 bornes
            VStack(spacing: 8) {
                ForEach(stations) { station in
                    NearestBorneRowView(
                        station: station,
                        userLocation: userLocation,
                        themeColor: themeColor,
                        onStationTapped: onStationTapped
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

struct NearestBorneRowView: View {
    let station: ChargingStationLocation
    let userLocation: CLLocationCoordinate2D
    let themeColor: Color
    let onStationTapped: (ChargingStationLocation) -> Void
    
    private var distance: String {
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let stationLocation = CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: stationLocation)
        
        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters))m"
        } else {
            return String(format: "%.1fkm", distanceInMeters / 1000)
        }
    }
    
    var body: some View {
        Button(action: {
            onStationTapped(station)
        }) {
            HStack(spacing: 12) {
                // Icône Borne AGRANDIE x2 (48px au lieu de 24px)
                Image("Borne")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(station.isOpen ? themeColor : themeColor.opacity(0.5))
                
                // Informations borne
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.stationName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text(station.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Badges statut
                    HStack(spacing: 8) {
                        Text("⚡ \(Int(station.power))kW")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeColor.opacity(0.2))
                            .foregroundColor(themeColor)
                            .cornerRadius(4)
                        
                        if station.isAccessible {
                            Text("♿ Accessible")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        if station.isFree {
                            Text("🆓 Gratuit")
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
                    
                    Image(systemName: "car.fill")
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

// MARK: - Composants UI pour la carte

struct BornesMapBoxView: View {
    @Binding var region: MKCoordinateRegion
    let stations: [ChargingStationLocation]
    let userLocation: CLLocationCoordinate2D?
    let searchedLocation: CLLocationCoordinate2D?
    let isLoading: Bool
    let themeColor: Color
    let onStationTapped: (ChargingStationLocation) -> Void
    
    private var stableAnnotations: [BorneMapAnnotationItem] {
        var annotations = stations.map { station in
            BorneMapAnnotationItem(station: station, coordinate: station.coordinate, isSearchResult: false)
        }
        
        if let searchedLocation = searchedLocation {
            annotations.append(BorneMapAnnotationItem(station: nil, coordinate: searchedLocation, isSearchResult: true))
        }
        
        return annotations
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ✅ En-tête avec nombre de bornes et bouton "Ma position"
            HStack {
                Text("Carte des stations (\(stations.count))")
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
            
            // ✅ Map avec icônes Borne personnalisées
            Map(coordinateRegion: $region,
                interactionModes: [.pan, .zoom],
                showsUserLocation: true,
                annotationItems: stableAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if let station = annotation.station {
                        BorneMarkerView(
                            station: station,
                            themeColor: themeColor,
                            onStationTapped: onStationTapped
                        )
                            .id("borne-\(station.id)")
                    } else if annotation.isSearchResult {
                        SearchPinMarker()
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

struct BorneMapAnnotationItem: Identifiable {
    let id = UUID()
    let station: ChargingStationLocation?
    let coordinate: CLLocationCoordinate2D
    let isSearchResult: Bool
}

// MARK: - ✅ MODALE DÉTAIL DE LA STATION
struct StationDetailView: View {
    let station: ChargingStationLocation
    let userLocation: CLLocationCoordinate2D?
    let themeColor: Color
    @Environment(\.dismiss) private var dismiss
    
    private var distance: String? {
        guard let userLocation = userLocation else { return nil }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let stationLocation = CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
        let distanceInMeters = userCLLocation.distance(from: stationLocation)
        
        if distanceInMeters < 1000 {
            return "\(Int(distanceInMeters))m"
        } else {
            return String(format: "%.1fkm", distanceInMeters / 1000)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ✅ EN-TÊTE AVEC ICÔNE ET NOM
                    HStack(spacing: 16) {
                        Image("Borne")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(themeColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.stationName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let distance = distance {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("À \(distance)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top)
                    
                    // ✅ INFORMATIONS PRINCIPALES
                    VStack(spacing: 16) {
                        // Adresse
                        InfoRowView(
                            icon: "location.circle.fill",
                            title: "Adresse",
                            value: station.address,
                            color: themeColor
                        )
                        
                        // Opérateur
                        InfoRowView(
                            icon: "building.2.fill",
                            title: "Opérateur",
                            value: station.operatorName,
                            color: themeColor
                        )
                        
                        // Nombre de points de charge
                        InfoRowView(
                            icon: "bolt.circle.fill",
                            title: "Points de charge",
                            value: "\(station.pointCount) borne\(station.pointCount > 1 ? "s" : "")",
                            color: themeColor
                        )
                        
                        // Puissance maximale
                        InfoRowView(
                            icon: "gauge.high",
                            title: "Puissance max",
                            value: "\(Int(station.power)) kW",
                            color: themeColor
                        )
                    }
                    
                    // ✅ TYPES DE CONNECTEURS
                    if !station.connectorTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Types de connecteurs")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(station.connectorTypes, id: \.self) { connector in
                                    HStack(spacing: 8) {
                                        Text(connector.symbol)
                                            .font(.title2)
                                        Text(connector.rawValue)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(themeColor.opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeColor.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    
                    // ✅ BADGES STATUTS
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statut")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            // Badge Accessibilité
                            StatusBadgeView(
                                text: station.isAccessible ? "♿ Accessible PMR" : "♿ Non accessible PMR",
                                color: station.isAccessible ? .green : .red
                            )
                            
                            // Badge Gratuit
                            if station.isFree {
                                StatusBadgeView(
                                    text: "🆓 Gratuit",
                                    color: .blue
                                )
                            }
                        }
                        
                        // Badge Horaires
                        StatusBadgeView(
                            text: "🕒 \(station.schedule)",
                            color: themeColor
                        )
                    }
                    
                    // ✅ INFORMATIONS COMPLÉMENTAIRES
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conditions d'accès")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(station.accessCondition)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Détails de la station")
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
        .overlay(alignment: .bottom) {
            // ✅ BOUTON Y ALLER EN BAS
            Button(action: {
                openNavigationToStation()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Y aller")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(themeColor)
                .cornerRadius(12)
                .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    private func openNavigationToStation() {
        let coordinate = station.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = station.stationName
        
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            MKLaunchOptionsShowsTrafficKey: true
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
        
        print("🧭 Navigation en voiture lancée vers: \(station.stationName) (\(coordinate.latitude), \(coordinate.longitude))")
        
        dismiss()
    }
}

// MARK: - Composants UI pour la modale

struct InfoRowView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

struct StatusBadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

// ✅ MARQUEUR BORNE avec icône
struct BorneMarkerView: View {
    let station: ChargingStationLocation
    let themeColor: Color
    let onStationTapped: (ChargingStationLocation) -> Void
    
    var body: some View {
        Button(action: {
            onStationTapped(station)
        }) {
            ZStack {
                // ✅ Icône Borne
                Image("Borne")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundColor(station.isOpen ? themeColor : themeColor.opacity(0.5))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                
                // Bordure verte si accessible
                if station.isAccessible {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                // Bordure bleue si gratuit
                if station.isFree {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
            }
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
            // ✅ CHARGEMENT PARALLÈLE des 9 arrondissements
            let allStations = try await withThrowingTaskGroup(of: [ChargingStationLocation].self) { group in
                
                // Lancer les 9 requêtes en parallèle
                for district in lyonDistricts {
                    group.addTask {
                        await self.loadDistrictStations(district: district)
                    }
                }
                
                // Collecter tous les résultats
                var combinedStations: [ChargingStationLocation] = []
                for try await districtStations in group {
                    combinedStations.append(contentsOf: districtStations)
                }
                
                return combinedStations
            }
            
            // ✅ GROUPEMENT automatique par coordonnées
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
                print("⚠️ Status \(httpResponse.statusCode) pour district \(district)")
                return []
            }
            
            let geoJsonResponse = try JSONDecoder().decode(IRVEGeoJSONResponse.self, from: data)
            return parseStationsFromFeatures(geoJsonResponse.features)
            
        } catch {
            print("❌ Erreur district \(district): \(error)")
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
        
        if props.prise_type_2 == true {
            connectors.append(.type2)
        }
        if props.prise_type_combo_ccs == true {
            connectors.append(.comboCCS)
        }
        if props.prise_type_chademo == true {
            connectors.append(.chademo)
        }
        if props.prise_type_ef == true {
            connectors.append(.ef)
        }
        
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
            
            if stationsGroup.count == 1 {
                return firstStation
            }
            
            // ✅ FUSION des stations au même emplacement
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
    let accessibilityStatus: String  // ✅ NOUVEAU: statut brut d'accessibilité
    let isFree: Bool
    let isOpen: Bool
    let schedule: String
    let accessCondition: String
    
    // ✅ Computed property pour savoir si accessible
    var isAccessible: Bool {
        return accessibilityStatus.lowercased().contains("oui")
    }
}

enum ConnectorType: String, CaseIterable {
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
