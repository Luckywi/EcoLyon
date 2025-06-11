import SwiftUI
import Foundation

// MARK: - Modèles pour les recommandations
struct RecommendationResponse: Codable {
    let licence: String
    let data: [Recommendation]
}

struct Recommendation: Codable, Identifiable {
    let id = UUID()
    let message_court: String
    let message_long: String
    let type: String // "sanitaire" ou "comportemental"
    let visuel: String?
    let saison: String?
    let contextes: [RecommendationContext]
    
    enum CodingKeys: String, CodingKey {
        case message_court, message_long, type, visuel, saison, contextes
    }
}

struct RecommendationContext: Codable {
    let niveau: String // "vert", "jaune", "orange", "rouge"
    let population: [String]
}

// MARK: - Modèles pour l'API Vigilance
struct VigilanceResponse: Codable {
    let data: VigilanceData
    let success: Bool
    let message: APIMessage
    let meta: VigilanceMeta
}

struct VigilanceData: Codable {
    let code_insee: String
    let commune: String
    let vigilances: [Vigilance]
}

struct Vigilance: Codable {
    let date_debut: String
    let date_fin: String
    let nom_procedure: String
    let zone: String
    let polluant: String
    let niveau: String // "Vert", "Jaune", "Orange", "Rouge"
    let seuil: String
    let commentaire: String
    let date_modification: String
}

struct APIMessage: Codable {
    let code: Int
    let text: String
}

struct VigilanceMeta: Codable {
    let licence: String
}

// MARK: - Service Vigilance Atmo
class VigilanceService: ObservableObject {
    private let apiToken = "0c7d0bee25f494150fa591275260e81f"
    private let baseURL = "https://api.atmo-aura.fr/api/v1/communes"
    
    // Code INSEE de Lyon
    private let lyonInseeCode = "69123"
    
    @Published var currentAlertLevel: String = "vert"
    @Published var activeVigilances: [Vigilance] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// Récupère le niveau d'alerte officiel actuel pour Lyon
    func fetchCurrentAlertLevel() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let vigilances = try await fetchVigilances(for: lyonInseeCode, date: "now")
            
            await MainActor.run {
                self.activeVigilances = vigilances
                self.currentAlertLevel = determineCurrentAlertLevel(from: vigilances)
                self.isLoading = false
                
                print("🚨 Niveau d'alerte officiel Lyon: \(self.currentAlertLevel)")
                print("📊 Vigilances actives: \(vigilances.count)")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Impossible de récupérer les alertes"
                self.isLoading = false
                
                print("⚠️ Erreur vigilance: \(error)")
            }
        }
    }
    
    /// Récupère les vigilances pour une commune et une date
    private func fetchVigilances(for inseeCode: String, date: String) async throws -> [Vigilance] {
        let urlString = "\(baseURL)/\(inseeCode)/vigilances?date=\(date)&api_token=\(apiToken)"
        
        guard let url = URL(string: urlString) else {
            throw VigilanceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        print("🔍 Récupération vigilances Lyon: \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VigilanceError.invalidResponse
        }
        
        print("📡 Status vigilance: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw VigilanceError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let vigilanceResponse = try decoder.decode(VigilanceResponse.self, from: data)
        
        // Filtrer les vigilances actives (aujourd'hui)
        let activeVigilances = filterActiveVigilances(vigilanceResponse.data.vigilances)
        
        return activeVigilances
    }
    
    /// Filtre les vigilances actives (en cours aujourd'hui)
    private func filterActiveVigilances(_ vigilances: [Vigilance]) -> [Vigilance] {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        
        return vigilances.filter { vigilance in
            guard let dateDebut = formatter.date(from: vigilance.date_debut),
                  let dateFin = formatter.date(from: vigilance.date_fin) else {
                return false
            }
            
            // Vérifier si la vigilance est active maintenant
            return dateDebut <= now && now <= dateFin
        }
    }
    
    /// Détermine le niveau d'alerte actuel basé sur les vigilances actives
    private func determineCurrentAlertLevel(from vigilances: [Vigilance]) -> String {
        // Si aucune vigilance active, niveau vert
        guard !vigilances.isEmpty else {
            return "vert"
        }
        
        // Prendre le niveau le plus élevé parmi les vigilances actives
        let niveaux = vigilances.map { $0.niveau.lowercased() }
        
        if niveaux.contains("rouge") {
            return "rouge"
        } else if niveaux.contains("orange") {
            return "orange"
        } else if niveaux.contains("jaune") {
            return "jaune"
        } else {
            return "vert"
        }
    }
    
    /// Récupère des infos détaillées sur les vigilances actives
    func getActiveVigilancesSummary() -> String {
        guard !activeVigilances.isEmpty else {
            return "Aucune vigilance pollution en cours"
        }
        
        let polluants = activeVigilances.map { $0.polluant }.joined(separator: ", ")
        let niveauMax = currentAlertLevel.capitalized
        
        return "Vigilance \(niveauMax) - \(polluants)"
    }
}

// MARK: - Service API pour les recommandations (avec vigilance intégrée)
class RecommendationsService: ObservableObject {
    private let apiToken = "0c7d0bee25f494150fa591275260e81f"
    private let baseURL = "https://api.atmo-aura.fr/bons_gestes"
    
    @StateObject private var vigilanceService = VigilanceService()
    
    @Published var allRecommendations: [Recommendation] = []
    @Published var currentAlertLevel: String = "vert"
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchRecommendations(fallbackAQI: Int? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 1. D'abord récupérer le niveau d'alerte officiel
        await vigilanceService.fetchCurrentAlertLevel()
        
        var alertLevel: String
        
        // 2. Utiliser le niveau officiel ou fallback
        if vigilanceService.errorMessage != nil, let aqi = fallbackAQI {
            // Fallback sur conversion AQI
            alertLevel = aqi.alertLevelFallback
            print("🔄 Utilisation fallback: AQI \(aqi) → \(alertLevel)")
        } else {
            // Utiliser le niveau officiel
            alertLevel = vigilanceService.currentAlertLevel
            print("✅ Niveau officiel Atmo: \(alertLevel)")
        }
        
        await MainActor.run {
            currentAlertLevel = alertLevel
        }
        
        // 3. Récupérer les recommandations selon le niveau
        do {
            let healthRecs: [Recommendation]
            let ecoRecs: [Recommendation]
            
            if alertLevel == "vert" {
                // Si niveau vert → seulement conseils généraux quotidiens
                healthRecs = try await fetchRecommendationsByType("sanitaire", level: "vert")
                ecoRecs = try await fetchRecommendationsByType("comportemental", level: "vert")
                print("🟢 Récupération conseils généraux (niveau vert)")
            } else {
                // Si niveau alerte → mélanger conseils généraux + conseils d'alerte
                let generalHealthRecs = try await fetchRecommendationsByType("sanitaire", level: "vert")
                let alertHealthRecs = try await fetchRecommendationsByType("sanitaire", level: alertLevel)
                
                let generalEcoRecs = try await fetchRecommendationsByType("comportemental", level: "vert")
                let alertEcoRecs = try await fetchRecommendationsByType("comportemental", level: alertLevel)
                
                // Mélanger : 2 généraux + 2 spécifiques pour chaque type
                healthRecs = Array(generalHealthRecs.shuffled().prefix(2)) +
                            Array(alertHealthRecs.shuffled().prefix(2))
                ecoRecs = Array(generalEcoRecs.shuffled().prefix(2)) +
                         Array(alertEcoRecs.shuffled().prefix(2))
                
                print("🚨 Mélange conseils généraux + spécifiques (\(alertLevel))")
            }
            
            await MainActor.run {
                // Mélanger toutes les recommandations récupérées
                var mixed: [Recommendation] = []
                mixed.append(contentsOf: healthRecs)
                mixed.append(contentsOf: ecoRecs)
                
                // Limiter à 8 conseils aléatoires maximum
                let shuffledMixed = mixed.shuffled()
                self.allRecommendations = Array(shuffledMixed.prefix(8))
                self.isLoading = false
                
                print("📱 Total recommandations affichées: \(self.allRecommendations.count)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Impossible de charger les recommandations"
                self.isLoading = false
            }
        }
    }
    
    private func fetchRecommendationsByType(_ type: String, level: String) async throws -> [Recommendation] {
        // Récupérer TOUS les conseils du type (l'API ne filtre pas par niveau correctement)
        let urlString = "\(baseURL)?type=\(type)&api_token=\(apiToken)"
        
        guard let url = URL(string: urlString) else {
            throw RecommendationError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RecommendationError.serverError
        }
        
        let recommendationResponse = try JSONDecoder().decode(RecommendationResponse.self, from: data)
        
        // ✅ FILTRER côté client par niveau
        let filteredRecommendations = recommendationResponse.data.filter { recommendation in
            recommendation.contextes.contains { contexte in
                contexte.niveau.lowercased() == level.lowercased()
            }
        }
        
        print("🔍 Type: \(type), Niveau: \(level)")
        print("📦 Total reçu de l'API: \(recommendationResponse.data.count)")
        print("✅ Après filtrage: \(filteredRecommendations.count)")
        
        return filteredRecommendations
    }
    
    /// Obtient un résumé de la situation actuelle
    func getAirQualitySummary() -> String {
        return vigilanceService.getActiveVigilancesSummary()
    }
}

enum RecommendationError: Error {
    case invalidURL
    case serverError
    case noData
}

enum VigilanceError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError
}

// MARK: - Composant principal des recommandations (avec vigilance intégrée)
struct AirQualityRecommendationsView: View {
    let fallbackAQI: Int? // AQI à utiliser si API vigilance échoue
    @StateObject private var recommendationsService = RecommendationsService()
    @State private var currentIndex = 0
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        VStack(spacing: 12) {
            // En-tête simplifié avec seulement le titre principal
            HStack {
                Text("Conseils & Gestes")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Carte swipable
            if recommendationsService.isLoading {
                LoadingRecommendationView()
            } else if let errorMessage = recommendationsService.errorMessage {
                ErrorRecommendationView(message: errorMessage) {
                    loadRecommendations()
                }
            } else if !recommendationsService.allRecommendations.isEmpty {
                SwipableRecommendationCard(
                    recommendations: recommendationsService.allRecommendations,
                    alertLevel: recommendationsService.currentAlertLevel,
                    currentIndex: $currentIndex,
                    dragOffset: $dragOffset
                )
            } else {
                EmptyRecommendationView()
            }
            
            // Indicateur de pagination en bas
            if !recommendationsService.allRecommendations.isEmpty {
                HStack(spacing: 6) {
                    ForEach(0..<recommendationsService.allRecommendations.count, id: \.self) { index in
                        Circle()
                            .fill(index == normalizedCurrentIndex ? Color.primary : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: normalizedCurrentIndex)
                    }
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            loadRecommendations()
        }
    }
    
    // Index normalisé pour gérer le bouclage correctement
    private var normalizedCurrentIndex: Int {
        guard !recommendationsService.allRecommendations.isEmpty else { return 0 }
        return currentIndex % recommendationsService.allRecommendations.count
    }
    
    private func loadRecommendations() {
        Task {
            await recommendationsService.fetchRecommendations(fallbackAQI: fallbackAQI)
        }
    }
}

// MARK: - Carte swipable (avec taille réduite et sans indicateur swipe)
struct SwipableRecommendationCard: View {
    let recommendations: [Recommendation]
    let alertLevel: String
    @Binding var currentIndex: Int
    @Binding var dragOffset: CGSize
    @State private var showFullMessage = false
    
    private var currentRecommendation: Recommendation {
        recommendations[currentIndex]
    }
    
    private var isHealthRecommendation: Bool {
        currentRecommendation.type == "sanitaire"
    }
    
    private var accentColor: Color {
        isHealthRecommendation ? .red : .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Message principal - Zone tappable pour détails
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showFullMessage.toggle()
                }
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentRecommendation.message_court)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white) // Texte blanc sur fond noir
                        .multilineTextAlignment(.leading)
                        .lineLimit(showFullMessage ? nil : 3)
                    
                    // Message détaillé (conditionnel)
                    if showFullMessage {
                        Text(currentRecommendation.message_long)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8)) // Texte blanc semi-transparent
                            .multilineTextAlignment(.leading)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Icône pour expand/collapse en bas à droite
            HStack {
                // Badge de type à gauche
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)
                    
                    Text(isHealthRecommendation ? "Santé" : "Environnement")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentColor)
                }
                
                Spacer()
                
                // Bouton expand/collapse
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showFullMessage.toggle()
                    }
                }) {
                    Image(systemName: showFullMessage ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.7)) // Icône blanche semi-transparente
                        .font(.system(size: 12, weight: .medium))
                        .padding(6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: showFullMessage ? nil : 120) // Encore plus compact
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7)) // Background noir semi-transparent comme dans ton app
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .offset(x: dragOffset.width)
        .rotationEffect(.degrees(dragOffset.width / 20))
        .scaleEffect(1 - abs(dragOffset.width) / 1000)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showFullMessage)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    
                    if value.translation.width > threshold {
                        // Swipe vers la droite - carte précédente
                        previousCard()
                    } else if value.translation.width < -threshold {
                        // Swipe vers la gauche - carte suivante
                        nextCard()
                    }
                    
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        dragOffset = .zero
                    }
                }
        )
        .padding(.horizontal, 20)
    }
    
    private func nextCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentIndex = (currentIndex + 1) % recommendations.count
            showFullMessage = false
        }
    }
    
    private func previousCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            // Correction du bouclage vers l'arrière
            if currentIndex == 0 {
                currentIndex = recommendations.count - 1
            } else {
                currentIndex = currentIndex - 1
            }
            showFullMessage = false
        }
    }
    
    private func getIconForRecommendation() -> String {
        let message = currentRecommendation.message_court.lowercased()
        
        if message.contains("sport") || message.contains("activité") || message.contains("exercice") {
            return "figure.run"
        } else if message.contains("transport") || message.contains("vélo") || message.contains("marche") {
            return "bicycle"
        } else if message.contains("fenêtre") || message.contains("aération") {
            return "wind"
        } else if message.contains("jardin") || message.contains("plante") || message.contains("arbre") {
            return "leaf"
        } else if message.contains("chauffage") || message.contains("température") {
            return "thermometer"
        } else if isHealthRecommendation {
            return "heart.fill"
        } else {
            return "leaf.arrow.circlepath"
        }
    }
}

// MARK: - États de chargement avec taille réduite
struct LoadingRecommendationView: View {
    var body: some View {
        VStack(spacing: 12) { // Réduit de 16 à 12
            ProgressView()
                .scaleEffect(1.1) // Réduit de 1.2 à 1.1
                .tint(.blue)
            
            Text("Chargement des conseils...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white) // Texte blanc
        }
        .frame(height: 140) // Réduit de 180 à 140
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7)) // Background noir semi-transparent
        )
        .padding(.horizontal, 20)
    }
}

struct ErrorRecommendationView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) { // Réduit de 16 à 12
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28)) // Réduit de 32 à 28
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white) // Texte blanc
                .multilineTextAlignment(.center)
            
            Button("Réessayer") {
                onRetry()
            }
            .padding(.horizontal, 16) // Réduit de 20 à 16
            .padding(.vertical, 6) // Réduit de 8 à 6
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10) // Réduit de 12 à 10
        }
        .frame(height: 140) // Réduit de 180 à 140
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7)) // Background noir semi-transparent
        )
        .padding(.horizontal, 20)
    }
}

struct EmptyRecommendationView: View {
    var body: some View {
        VStack(spacing: 10) { // Réduit de 12 à 10
            Image(systemName: "info.circle")
                .font(.system(size: 28)) // Réduit de 32 à 28
                .foregroundColor(.gray)
            
            Text("Aucun conseil disponible")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white) // Texte blanc
        }
        .frame(height: 140) // Réduit de 180 à 140
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7)) // Background noir semi-transparent
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Extension fallback AQI
extension Int {
    /// Fallback : Conversion AQI vers niveau d'alerte (si API vigilance échoue)
    var alertLevelFallback: String {
        switch self {
        case 0...25:
            return "vert"      // Bon
        case 26...50:
            return "vert"      // Moyen mais pas d'alerte
        case 51...75:
            return "jaune"     // Dégradé - information
        case 76...100:
            return "orange"    // Mauvais - alerte niveau 1
        default:
            return "rouge"     // Très mauvais - alerte niveau 2+
        }
    }
}

// MARK: - Exemple d'utilisation dans ContentView
struct ContentViewExample: View {
    @State private var currentAQI = 75 // Votre AQI existant
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Votre composant AirQuality existant
                // AirQualityMapView()
                //     .padding(.horizontal, 20)
                
                // Nouveau composant recommandations avec vigilance intégrée
                AirQualityRecommendationsView(fallbackAQI: currentAQI)
                
                // Autres composants...
            }
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    AirQualityRecommendationsView(fallbackAQI: 75)
}
