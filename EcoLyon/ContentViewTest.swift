import SwiftUI
import MapKit
import WeatherKit
import CoreLocation

struct ContentViewTest: View {
    @ObservedObject private var navigationManager = NavigationManager.shared
    @State private var currentAQI = 3

    // État partagé de la caméra map
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.764043, longitude: 4.835659),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    ))

    init() {
        // Désactiver le bounce du scroll
        UIScrollView.appearance().bounces = false
    }

    // Constantes de layout
    private let horizontalPadding: CGFloat = 16
    private let cardsHeight: CGFloat = 310 // Hauteur des cards AirQuality
    private let blurTransitionHeight: CGFloat = 80 // Zone de transition blur

    // Map couvre cards + une partie de la zone Explorer (pour le legal Apple Maps)
    private var mapTotalHeight: CGFloat {
        cardsHeight + 200 // Map s'étend 200px sous les cards
    }

    var body: some View {
        ZStack(alignment: .top) {
            // LAYER 1: Background color (toujours visible)
            AirQualityDesignSystem.backgroundColor
                .ignoresSafeArea()

            // LAYER 2: Map background (fixe, couvre toute la zone jusqu'au blur)
            VStack(spacing: 0) {
                MapBackgroundView(
                    cameraPosition: $cameraPosition,
                    showFade: false,
                    legalBottomPadding: 80
                )
                .frame(height: mapTotalHeight)

                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // LAYER 3: Contenu scrollable
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Zone Air Quality (hauteur naturelle des cards)
                    AirQualityCardsOverlay(cameraPosition: $cameraPosition)
                        .frame(height: cardsHeight)
                        .padding(.horizontal, horizontalPadding)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AQIUpdated"))) { notification in
                            if let aqi = notification.object as? Int {
                                currentAQI = aqi
                            }
                        }

                    // Espace transparent pour voir la map + legal
                    Color.clear
                        .frame(height: 30)

                    // Section Explorer avec transition douce
                    ZStack(alignment: .top) {
                        // Fond : gradient de transition
                        VStack(spacing: 0) {
                            // Zone de transition : blur + gradient de couleur
                            ZStack {
                                // Couche 1 : Blur progressif
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .mask(
                                        LinearGradient(
                                            colors: [.clear, .white, .white],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                // Couche 2 : Gradient de couleur
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        AirQualityDesignSystem.backgroundColor.opacity(0.4),
                                        AirQualityDesignSystem.backgroundColor.opacity(0.85),
                                        AirQualityDesignSystem.backgroundColor
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                            .frame(height: blurTransitionHeight)

                            // Fond opaque pour le reste
                            AirQualityDesignSystem.backgroundColor
                        }

                        // Contenu : Menu qui remonte dans le gradient
                        ModernBentoMenu()
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 40) // Titre "Explorer" dans le gradient
                            .padding(.bottom, 40)
                    }
                }
            }
            .scrollClipDisabled()
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.top, 8, for: .scrollContent)
        }
        .onAppear {
            navigationManager.currentDestination = .home
        }
        // Navigation unifiée avec un seul fullScreenCover
        .fullScreenCover(item: $navigationManager.presentedDestination) { destination in
            destinationView(for: destination)
                .onDisappear {
                    navigationManager.closeCurrentView()
                }
        }
    }

    // MARK: - Factory pour les vues de destination
    @ViewBuilder
    private func destinationView(for destination: Destination) -> some View {
        switch destination {
        case .home:
            EmptyView()
        case .toilets:
            ToiletsMapView()
        case .bancs:
            BancsMapView()
        case .fontaines:
            FontainesMapView()
        case .randos:
            RandosMapView()
        case .silos:
            SilosMapView()
        case .bornes:
            BornesMapView()
        case .compost:
            CompostMapView()
        case .parcs:
            ParcsMapView()
        case .poubelle:
            PoubelleMapView()
        case .composteurGratuit:
            ComposteurGratuitView()
        case .compostGuide:
            CompostGuideView()
        case .lyonFacts:
            LyonFactsView()
        }
    }
}

// MARK: - Modern Bento Menu

struct ModernBentoMenu: View {
    @ObservedObject private var navigationManager = NavigationManager.shared

    private let spacing: CGFloat = 12

    var body: some View {
        VStack(spacing: spacing) {
            // Section titre
            HStack {
                Text("Localiser")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.bottom, 4)

            // LIGNE 1: Fontaines + Parcs + Randos
            HStack(spacing: spacing) {
                ModernBentoCard(
                    title: "Fontaines",
                    icon: "Fontaine",
                    color: Color(red: 0.4, green: 0.7, blue: 0.65)
                ) {
                    navigationManager.navigate(to: .fontaines)
                }

                ModernBentoCard(
                    title: "Parcs",
                    icon: "PetJ",
                    color: Color(red: 0.5, green: 0.75, blue: 0.45)
                ) {
                    navigationManager.navigate(to: .parcs)
                }

                ModernBentoCard(
                    title: "Randos",
                    icon: "Rando",
                    color: Color(red: 0.85, green: 0.7, blue: 0.5)
                ) {
                    navigationManager.navigate(to: .randos)
                }
            }
            .frame(height: 100)

            // LIGNE 2: Poubelles + Compost + Silos
            HStack(spacing: spacing) {
                ModernBentoCard(
                    title: "Poubelles",
                    icon: "Poubelle",
                    color: Color(red: 0.55, green: 0.55, blue: 0.55)
                ) {
                    navigationManager.navigate(to: .poubelle)
                }

                ModernBentoCard(
                    title: "Compost",
                    icon: "Compost",
                    color: Color(red: 0.55, green: 0.4, blue: 0.3)
                ) {
                    navigationManager.navigate(to: .compost)
                }

                ModernBentoCard(
                    title: "Silos",
                    icon: "Silos",
                    color: Color(red: 0.45, green: 0.65, blue: 0.7)
                ) {
                    navigationManager.navigate(to: .silos)
                }
            }
            .frame(height: 100)

            // LIGNE 4: Toilettes + Bancs + Bornes
            HStack(spacing: spacing) {
                ModernBentoCard(
                    title: "Toilettes",
                    icon: "Wc",
                    color: Color(red: 0.6, green: 0.6, blue: 0.65)
                ) {
                    navigationManager.navigate(to: .toilets)
                }

                ModernBentoCard(
                    title: "Bancs",
                    icon: "Banc",
                    color: Color(red: 0.7, green: 0.55, blue: 0.45)
                ) {
                    navigationManager.navigate(to: .bancs)
                }

                ModernBentoCard(
                    title: "Recharge",
                    icon: "Borne",
                    color: Color(red: 0.45, green: 0.55, blue: 0.7)
                ) {
                    navigationManager.navigate(to: .bornes)
                }
            }
            .frame(height: 100)

            // Section Widgets
            HStack {
                Text("Widgets")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Widget Preview Principal
            WidgetPreviewCardSimple()

            // Widget Incity + Texte explicatif
            HStack(alignment: .top, spacing: 12) {
                // Texte à gauche
                Text("Maintenez l'écran d'accueil et appuyez sur + pour ajouter un widget. Météo, qualité de l'air et raccourcis vers vos services préférés, le tout avec un fond dynamique qui évolue au fil du temps et cache quelques surprises !")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                // Widget Incity à droite
                IncityWidgetPreviewCard()
            }

            // Section Ressources
            HStack {
                Text("Ressources")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Colonne Infos: 3 cards empilées
            VStack(spacing: spacing) {
                ModernBentoCardInfo(
                    title: "Lyon en Chiffres",
                    subtitle: "Faits et initiatives de la Métropole de Lyon",
                    icon: "Lyon",
                    systemIcon: "leaf.fill"
                ) {
                    navigationManager.navigate(to: .lyonFacts)
                }
                .frame(height: 80)

                ModernBentoCardInfo(
                    title: "Guide Compost",
                    subtitle: "Apprenez à composter vos déchets organiques",
                    icon: "Guide",
                    systemIcon: "book.fill"
                ) {
                    navigationManager.navigate(to: .compostGuide)
                }
                .frame(height: 80)

                ModernBentoCardPromo(
                    title: "Composteur Gratuit",
                    subtitle: "Obtenez votre composteur offert par la Métropole",
                    icon: "CompostGratuit"
                ) {
                    navigationManager.navigate(to: .composteurGratuit)
                }
                .frame(height: 80)
            }
        }
    }
}

// MARK: - Widget Preview Card Simple (sans texte)

struct WidgetPreviewCardSimple: View {
    @StateObject private var viewModel = WidgetPreviewViewModel()

    var body: some View {
        ZStack {
            // Background dynamique
            Image(viewModel.backgroundImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipped()

            // Contenu du widget - exactement comme MediumWidgetView
            VStack {
                // Météo en haut à droite
                HStack {
                    Spacer()
                    WidgetWeatherDisplayView(
                        temperature: viewModel.temperature,
                        conditionSymbol: viewModel.conditionSymbol,
                        airQualityIndex: viewModel.airQualityIndex,
                        airQualityColor: viewModel.airQualityColor
                    )
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Spacer()

                // Boutons en bas à gauche (2 max pour Medium)
                HStack {
                    HStack(spacing: 8) {
                        WidgetShortcutButton(iconName: "Wc")
                        WidgetShortcutButton(iconName: "Fontaine")
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - Widget Weather Display View (Exact copy from widget)

struct WidgetWeatherDisplayView: View {
    let temperature: String
    let conditionSymbol: String
    let airQualityIndex: Int?
    let airQualityColor: String

    var body: some View {
        HStack(spacing: 8) {
            // Météo: Icône + Température
            HStack(spacing: 4) {
                Image(systemName: conditionSymbol.hasSuffix(".fill") ? conditionSymbol : conditionSymbol + ".fill")
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.multicolor)

                Text(temperature)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Séparateur si on a l'AQI
            if airQualityIndex != nil {
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 1, height: 14)
            }

            // Qualité de l'air
            if let aqi = airQualityIndex {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: airQualityColor))
                        .frame(width: 10, height: 10)

                    Text("AQI \(aqi)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Widget Shortcut Button

struct WidgetShortcutButton: View {
    let iconName: String

    var body: some View {
        Image(iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 36, height: 36)
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Widget Preview ViewModel

@MainActor
class WidgetPreviewViewModel: ObservableObject {
    @Published var backgroundImageName: String = "A_winter_day"
    @Published var temperature: String = "--°"
    @Published var conditionSymbol: String = "cloud.sun"
    @Published var airQualityIndex: Int? = nil
    @Published var airQualityColor: String = "#808080"

    private var backgroundTimer: Timer?
    private var currentBackgroundIndex = 0

    // Liste des backgrounds à afficher en démo
    private let demoBackgrounds: [String] = [
        "A_spring_day", "A_summer_golden", "A_autumn_day", "A_winter_night",
        "F_fete_lumieres_night", "A_summer_day", "F_noel_day", "A_spring_golden",
        "A_winter_day", "F_halloween_night", "A_autumn_golden", "A_summer_night"
    ]

    func loadData() {
        // Démarrer l'animation des backgrounds
        startBackgroundAnimation()

        // Fetch real weather & air quality data
        Task {
            await fetchWeatherData()
            await fetchAirQualityData()
        }
    }

    private func startBackgroundAnimation() {
        // Choisir un background initial aléatoire
        currentBackgroundIndex = Int.random(in: 0..<demoBackgrounds.count)
        backgroundImageName = demoBackgrounds[currentBackgroundIndex]

        // Timer synchronisé toutes les 1.75 secondes
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nextBackground()
            }
        }
    }

    private func nextBackground() {
        currentBackgroundIndex = (currentBackgroundIndex + 1) % demoBackgrounds.count
        withAnimation(.easeInOut(duration: 0.8)) {
            backgroundImageName = demoBackgrounds[currentBackgroundIndex]
        }
    }

    deinit {
        backgroundTimer?.invalidate()
    }

    private func fetchWeatherData() async {
        // Use WeatherKit if available
        do {
            let weatherService = WeatherKit.WeatherService.shared
            let lyon = CLLocation(latitude: 45.757814, longitude: 4.832011)
            let weather = try await weatherService.weather(for: lyon)
            let current = weather.currentWeather

            await MainActor.run {
                let tempCelsius = current.temperature.converted(to: .celsius).value
                self.temperature = "\(Int(round(tempCelsius)))°"
                self.conditionSymbol = current.symbolName
            }
        } catch {
            print("❌ WeatherKit error: \(error)")
            // Keep placeholder values
        }
    }

    private func fetchAirQualityData() async {
        // Use the same ATMO API as the widget
        guard let token = Bundle.main.object(forInfoDictionaryKey: "ATMO_API_TOKEN") as? String,
              !token.isEmpty else {
            return
        }

        let urlString = "https://api.atmo-aura.fr/api/v1/communes/69381/indices/atmo?api_token=\(token)&date_echeance=now"
        guard let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10.0

            let (data, _) = try await URLSession.shared.data(for: request)

            struct ATMOResponse: Codable {
                let data: [ATMOData]
                struct ATMOData: Codable {
                    let indice: Int
                }
            }

            let response = try JSONDecoder().decode(ATMOResponse.self, from: data)
            if let firstData = response.data.first {
                await MainActor.run {
                    self.airQualityIndex = firstData.indice
                    self.airQualityColor = self.colorForAQI(firstData.indice)
                }
            }
        } catch {
            print("❌ ATMO error: \(error)")
        }
    }

    private func colorForAQI(_ index: Int) -> String {
        switch index {
        case 1: return "#50F0E6"
        case 2: return "#50CCAA"
        case 3: return "#F0E641"
        case 4: return "#FF5050"
        case 5: return "#960032"
        case 6: return "#872181"
        default: return "#808080"
        }
    }
}

// MARK: - Incity Widget Preview Card

struct IncityWidgetPreviewCard: View {
    @StateObject private var viewModel = IncityWidgetPreviewViewModel()

    // Taille Small widget = 160x160
    private let widgetSize: CGFloat = 160

    var body: some View {
        ZStack {
            // Background dynamique Incity
            Image(viewModel.backgroundImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: widgetSize, height: widgetSize)
                .clipped()

            // Contenu du widget Incity - composants proportionnellement plus petits
            VStack {
                // Météo + AQI en haut à droite
                HStack {
                    Spacer()
                    IncityWeatherDisplayView(
                        temperature: viewModel.temperature,
                        conditionSymbol: viewModel.conditionSymbol,
                        airQualityIndex: viewModel.airQualityIndex,
                        airQualityColor: viewModel.airQualityColor
                    )
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)

                Spacer()

                // Un seul bouton raccourci en bas à gauche
                HStack {
                    IncityShortcutButton(iconName: "PetJ")
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(width: widgetSize, height: widgetSize)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - Incity Weather Display View (Plus petit, proportionnel au widget Small)

struct IncityWeatherDisplayView: View {
    let temperature: String
    let conditionSymbol: String
    let airQualityIndex: Int?
    let airQualityColor: String

    var body: some View {
        HStack(spacing: 6) {
            // Météo: Icône + Température
            HStack(spacing: 4) {
                Image(systemName: conditionSymbol.hasSuffix(".fill") ? conditionSymbol : conditionSymbol + ".fill")
                    .font(.system(size: 12, weight: .medium))
                    .symbolRenderingMode(.multicolor)

                Text(temperature)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Séparateur + AQI
            if let aqi = airQualityIndex {
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 1, height: 12)

                Circle()
                    .fill(Color(hex: airQualityColor))
                    .frame(width: 8, height: 8)

                Text("\(aqi)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Incity Shortcut Button (Plus petit, proportionnel au widget Small)

struct IncityShortcutButton: View {
    let iconName: String

    var body: some View {
        Image(iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 28, height: 28)
            .padding(6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Incity Widget Preview ViewModel

@MainActor
class IncityWidgetPreviewViewModel: ObservableObject {
    @Published var backgroundImageName: String = "incity_cloudy_day"
    @Published var temperature: String = "--°"
    @Published var conditionSymbol: String = "cloud.sun"
    @Published var airQualityIndex: Int? = nil
    @Published var airQualityColor: String = "#808080"

    private var backgroundTimer: Timer?
    private var currentBackgroundIndex = 0

    // Liste des backgrounds Incity à afficher en démo
    private let demoBackgrounds: [String] = [
        "incity_clear_day", "incity_night_cyan", "incity_clear_golden", "incity_night_green",
        "incity_fete_lumieres_night", "incity_cloudy_day", "incity_fullmoon_red", "incity_rain_day",
        "incity_night_purple", "incity_noel_night", "incity_storm_day", "incity_night_yellow"
    ]

    func loadData() {
        // Démarrer l'animation des backgrounds
        startBackgroundAnimation()

        // Récupérer les vraies données
        Task {
            await fetchWeatherData()
            await fetchAirQualityData()
        }
    }

    private func startBackgroundAnimation() {
        // Choisir un background initial aléatoire
        currentBackgroundIndex = Int.random(in: 0..<demoBackgrounds.count)
        backgroundImageName = demoBackgrounds[currentBackgroundIndex]

        // Timer synchronisé toutes les 1.75 secondes (même timing que le widget principal)
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nextBackground()
            }
        }
    }

    private func nextBackground() {
        currentBackgroundIndex = (currentBackgroundIndex + 1) % demoBackgrounds.count
        withAnimation(.easeInOut(duration: 0.8)) {
            backgroundImageName = demoBackgrounds[currentBackgroundIndex]
        }
    }

    deinit {
        backgroundTimer?.invalidate()
    }

    private func fetchWeatherData() async {
        do {
            let weatherService = WeatherKit.WeatherService.shared
            let lyon = CLLocation(latitude: 45.757814, longitude: 4.832011)
            let weather = try await weatherService.weather(for: lyon)
            let current = weather.currentWeather

            await MainActor.run {
                let tempCelsius = current.temperature.converted(to: .celsius).value
                self.temperature = "\(Int(round(tempCelsius)))°"
                self.conditionSymbol = current.symbolName
            }
        } catch {
            print("❌ Incity WeatherKit error: \(error)")
        }
    }

    private func fetchAirQualityData() async {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "ATMO_API_TOKEN") as? String,
              !token.isEmpty else {
            return
        }

        let urlString = "https://api.atmo-aura.fr/api/v1/communes/69381/indices/atmo?api_token=\(token)&date_echeance=now"
        guard let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10.0

            let (data, _) = try await URLSession.shared.data(for: request)

            struct ATMOResponse: Codable {
                let data: [ATMOData]
                struct ATMOData: Codable {
                    let indice: Int
                }
            }

            let response = try JSONDecoder().decode(ATMOResponse.self, from: data)
            if let firstData = response.data.first {
                await MainActor.run {
                    self.airQualityIndex = firstData.indice
                    self.airQualityColor = self.colorForAQI(firstData.indice)
                }
            }
        } catch {
            print("❌ Incity ATMO error: \(error)")
        }
    }

    private func colorForAQI(_ index: Int) -> String {
        switch index {
        case 1: return "#50F0E6"
        case 2: return "#50CCAA"
        case 3: return "#F0E641"
        case 4: return "#FF5050"
        case 5: return "#960032"
        case 6: return "#872181"
        default: return "#808080"
        }
    }
}

// MARK: - App Incity Background Service

struct AppIncityBackgroundService {

    static func currentBackgroundName() -> String {
        let date = Date()

        // 1. Vérifier les Easter Eggs
        if let eventImage = checkSpecialEvent(for: date) {
            return eventImage
        }

        // 2. Jour ou Nuit?
        let hour = Calendar.current.component(.hour, from: date)
        let isDay = hour >= 7 && hour < 19

        if isDay {
            // JOUR - Basé sur heure
            if hour >= 6 && hour < 8 || hour >= 17 && hour < 19 {
                return "incity_clear_golden"
            }
            return "incity_clear_day"
        } else {
            // NUIT - LED qualité de l'air (cyan par défaut)
            return "incity_night_cyan"
        }
    }

    private static func checkSpecialEvent(for date: Date) -> String? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let isDay = hour >= 7 && hour < 19
        let suffix = isDay ? "day" : "night"

        // Fête des Lumières: 8-10 décembre
        if month == 12 && (day >= 8 && day <= 10) {
            return "incity_fete_lumieres_\(suffix)"
        }
        // Noël: 24-25 décembre
        if month == 12 && (day == 24 || day == 25) {
            return "incity_noel_\(suffix)"
        }
        // Nouvel An: 31 déc - 1 jan
        if (month == 12 && day == 31) || (month == 1 && day == 1) {
            return "incity_nouvel_an_\(suffix)"
        }
        // 14 Juillet
        if month == 7 && day == 14 {
            return "incity_14_juillet_\(suffix)"
        }
        // Halloween: 31 octobre
        if month == 10 && day == 31 {
            return "incity_halloween_\(suffix)"
        }
        // Saint-Valentin: 14 février
        if month == 2 && day == 14 {
            return "incity_saint_valentin_\(suffix)"
        }

        return nil
    }
}

// MARK: - App Background Service (Simplified)

struct AppBackgroundService {

    enum Season: String {
        case spring, summer, autumn, winter

        static func current() -> Season {
            let month = Calendar.current.component(.month, from: Date())
            let day = Calendar.current.component(.day, from: Date())

            switch month {
            case 1, 2: return .winter
            case 3: return day < 20 ? .winter : .spring
            case 4, 5: return .spring
            case 6: return day < 21 ? .spring : .summer
            case 7, 8: return .summer
            case 9: return day < 22 ? .summer : .autumn
            case 10, 11: return .autumn
            case 12: return day < 21 ? .autumn : .winter
            default: return .autumn
            }
        }
    }

    enum TimeSlot: String {
        case golden, day, night

        static func current() -> TimeSlot {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 6..<8: return .golden
            case 8..<17: return .day
            case 17..<19: return .golden
            default: return .night
            }
        }
    }

    static func currentBackgroundName() -> String {
        let season = Season.current()
        let timeSlot = TimeSlot.current()

        // Check for special events
        if let eventImage = checkSpecialEvent() {
            return eventImage
        }

        // Format: A_{season}_{time}
        return "A_\(season.rawValue)_\(timeSlot.rawValue)"
    }

    private static func checkSpecialEvent() -> String? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let day = calendar.component(.day, from: Date())
        let hour = calendar.component(.hour, from: Date())
        let isDay = hour >= 7 && hour < 19
        let suffix = isDay ? "day" : "night"

        // Fête des Lumières: 8-10 décembre
        if month == 12 && (day >= 8 && day <= 10) {
            return "F_fete_lumieres_\(suffix)"
        }
        // Noël: 24-25 décembre
        if month == 12 && (day == 24 || day == 25) {
            return "F_noel_\(suffix)"
        }
        // Nouvel An: 31 déc - 1 jan
        if (month == 12 && day == 31) || (month == 1 && day == 1) {
            return "F_nouvel_an_\(suffix)"
        }
        // 14 Juillet
        if month == 7 && day == 14 {
            return "F_14_juillet_\(suffix)"
        }
        // Halloween: 31 octobre
        if month == 10 && day == 31 {
            return "F_halloween_\(suffix)"
        }
        // Saint-Valentin: 14 février
        if month == 2 && day == 14 {
            return "F_saint_valentin_\(suffix)"
        }

        return nil
    }
}

// MARK: - Carte Bento Standard (Glass Style)

struct ModernBentoCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Carte Bento Large (Glass Style)

struct ModernBentoCardWide: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Carte Bento Info (Glass Style)

struct ModernBentoCardInfo: View {
    let title: String
    let subtitle: String
    let icon: String
    let systemIcon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Carte Bento Promo (Glass Style)

struct ModernBentoCardPromo: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#Preview {
    ContentViewTest()
}
