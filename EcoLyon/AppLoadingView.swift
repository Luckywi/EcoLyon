import SwiftUI
import CoreLocation

// Service global pour gérer l'état de l'app OPTIMISÉ
@MainActor
class AppInitializationService: ObservableObject {
    @Published var isAppReady = false
    @Published var initializationProgress: Double = 0.0
    @Published var currentStatus = "Démarrage..."
    
    private let locationService = GlobalLocationService.shared
    
    func initializeApp() async {
        // Étape 1: Services de base
        await updateProgress(0.2, "Initialisation des services...")
        try? await Task.sleep(nanoseconds: 200_000_000) // Réduit de 0.3s à 0.2s
        
        // Étape 2: Permissions et localisation optimisée
        await updateProgress(0.4, "Localisation en cours...")
        
        // ✅ La localisation optimisée a déjà été démarrée dans GlobalLocationService.init()
        // Position connue probablement déjà disponible
        await waitForLocationDetection()
        
        // Étape 3: Configuration
        await updateProgress(0.7, "Configuration...")
        try? await Task.sleep(nanoseconds: 300_000_000) // Réduit de 0.4s à 0.3s
        
        // Étape 4: Finalisation
        await updateProgress(1.0, "Prêt !")
        try? await Task.sleep(nanoseconds: 200_000_000) // Réduit de 0.3s à 0.2s
        
        isAppReady = true
    }
    
    private func updateProgress(_ progress: Double, _ status: String) async {
        initializationProgress = progress
        currentStatus = status
    }
    
    // ✅ OPTIMISÉ : Attente plus courte et plus réactive
    private func waitForLocationDetection() async {
        // ✅ Attendre moins longtemps car position connue utilisée immédiatement
        let startTime = Date()
        let maxWaitTime: TimeInterval = 1.2 // Réduit de 2s à 1.2s
        
        while !locationService.isLocationReady && Date().timeIntervalSince(startTime) < maxWaitTime {
            try? await Task.sleep(nanoseconds: 50_000_000) // Check toutes les 50ms (plus réactif)
        }
        
        if locationService.isLocationReady {
            let district = locationService.detectedDistrict?.name ?? "Détecté"
            print("✅ Localisation terminée pendant le loading: \(district)")
        } else {
            print("⏰ Loading terminé, localisation continue en arrière-plan")
        }
    }
}

struct PartnerCard: View {
    let imageName: String
    let text: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Logo sans background ni container
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: logoWidth, height: logoHeight)
            
            // Texte descriptif - plus discret et uniforme
            Text(text)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 240, height: 40, alignment: .center)
        }
        .frame(height: 140)
    }
    
    // Gestion individuelle des tailles de logos
    private var logoWidth: CGFloat {
        switch imageName {
        case "Lyon2030": return 90
        case "atmo": return 130
        case "data": return 200
        default: return 90
        }
    }
    
    private var logoHeight: CGFloat {
        switch imageName {
        case "Lyon2030": return 60
        case "atmo": return 60
        case "data": return 60
        default: return 60
        }
    }
}

struct AppLoadingView: View {
    @StateObject private var initService = AppInitializationService()
    @ObservedObject private var locationService = GlobalLocationService.shared
    @State private var currentCardIndex = 0
    @State private var cardTimer: Timer? // ✅ Ajout pour gérer le timer
    let onComplete: () -> Void
    
    private let partnerCards = [
        ("data", "Données de géolocalisation\nfournies par DataGrandLyon"),
        ("Lyon2030", "Projet soutenu par la Ville de Lyon\ndans le cadre de la Bourse Jeunes Lyon 2030"),
        ("atmo", "Données sur la qualité de l’air\nfournies par Atmo Auvergne-Rhône-Alpes")
    ]
    
    var body: some View {
        ZStack {
            // Nouveau background couleur crème
            Color(red: 248/255, green: 247/255, blue: 244/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Section logo principal EcoLogo
                VStack(spacing: 20) {
                    // Logo EcoLogo principal (image assets)
                    Image("EcoLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 260, height: 290)
                        .scaleEffect(initService.initializationProgress > 0.5 ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.4), value: initService.initializationProgress)
                    
                    // ✅ CORRIGÉ : Cartes partenaires affichées immédiatement
                    PartnerCard(
                        imageName: partnerCards[currentCardIndex].0,
                        text: partnerCards[currentCardIndex].1
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.1).combined(with: .opacity)
                    ))
                    .id(currentCardIndex) // Force la réanimation
                }
                
                Spacer()
                    .frame(height: 40)
                
                // Section statut et progression
                VStack(spacing: 20) {
                    // Statut actuel
                    Text(initService.currentStatus)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    // Affichage de l'arrondissement détecté
                    if let district = locationService.detectedDistrict {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .foregroundColor(Color(red: 0x46/255, green: 0x95/255, blue: 0x2C/255))
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text(district.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0x46/255, green: 0x95/255, blue: 0x2C/255).opacity(0.1))
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    } else if locationService.locationError != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .foregroundColor(.orange)
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text("Position indisponible")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.orange.opacity(0.1))
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    
                    // Barre de progression moderne
                    VStack(spacing: 12) {
                        ZStack(alignment: .leading) {
                            // Fond de la barre
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.08))
                                .frame(height: 12)
                            
                            // Progression avec dégradé vert
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0x46/255, green: 0x95/255, blue: 0x2C/255).opacity(0.8),
                                            Color(red: 0x46/255, green: 0x95/255, blue: 0x2C/255)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(24, initService.initializationProgress * 300), height: 12)
                                .animation(.easeInOut(duration: 0.5), value: initService.initializationProgress)
                        }
                        .frame(width: 300)
                        
                        // Pourcentage
                        Text("\(Int(initService.initializationProgress * 100))%")
                            .font(.system(size: 15, weight: .regular, design: .monospaced))
                            .foregroundColor(.black.opacity(0.5))
                            .animation(.easeInOut(duration: 0.3), value: initService.initializationProgress)
                    }
                    
                    // Indicateur de statut de localisation
                    if initService.initializationProgress > 0.3 {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(locationService.isLocationReady ? Color(red: 0x46/255, green: 0x95/255, blue: 0x2C/255) : .orange)
                                .frame(width: 8, height: 8)
                            
                            Text(locationService.isLocationReady ? "Localisation OK" : "Recherche position...")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.black.opacity(0.5))
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                
                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            // ✅ CORRIGÉ : Animation des cartes partenaires démarrent immédiatement
            startPartnerCardsAnimation()
            
            // ✅ Démarrage optimisé de l'initialisation
            Task {
                await initService.initializeApp()
            }
        }
        // ✅ Nettoyage du timer quand la vue disparaît
        .onDisappear {
            cardTimer?.invalidate()
            cardTimer = nil
        }
        // ✅ onChange iOS 17+
        .onChange(of: initService.isAppReady) { _, isReady in
            if isReady {
                // ✅ Arrêter l'animation des cartes
                cardTimer?.invalidate()
                cardTimer = nil

                // ✅ Délai réduit pour transition plus rapide
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
        // ✅ Animation lors du changement d'arrondissement pendant le loading
        .onChange(of: locationService.detectedDistrict) { _, district in
            if let district = district {
                print("🎯 Arrondissement mis à jour pendant loading: \(district.name)")
            }
        }
        // ✅ Réaction au changement de statut de localisation
        .onChange(of: locationService.isLocationReady) { _, isReady in
            if isReady {
                print("✅ Localisation prête pendant le loading")
            }
        }
    }
    
    // ✅ NOUVELLE FONCTION : Démarrer l'animation des cartes
    private func startPartnerCardsAnimation() {
        cardTimer = Timer.scheduledTimer(withTimeInterval: 0.33, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                currentCardIndex = (currentCardIndex + 1) % partnerCards.count
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AppLoadingView {
        print("App ready!")
    }
}
