import SwiftUI
import CoreLocation

// Service global pour gérer l'état de l'app
@MainActor
class AppInitializationService: ObservableObject {
    @Published var isAppReady = false
    @Published var initializationProgress: Double = 0.0
    @Published var currentStatus = "Démarrage..."
    
    private let locationService = GlobalLocationService.shared
    
    func initializeApp() async {
        // Étape 1: Services de base
        await updateProgress(0.2, "Initialisation des services...")
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        
        // Étape 2: Permissions et localisation
        await updateProgress(0.4, "Localisation en cours...")
        
        // ✅ La localisation a déjà été démarrée dans GlobalLocationService.init()
        // On attend juste qu'elle se termine ou timeout
        await waitForLocationDetection()
        
        // Étape 3: Configuration
        await updateProgress(0.7, "Configuration...")
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
        
        // Étape 4: Finalisation
        await updateProgress(1.0, "Prêt !")
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        
        isAppReady = true
    }
    
    private func updateProgress(_ progress: Double, _ status: String) async {
        initializationProgress = progress
        currentStatus = status
    }
    
    private func waitForLocationDetection() async {
        // ✅ Attendre max 2 secondes que la localisation se termine
        let startTime = Date()
        let maxWaitTime: TimeInterval = 2.0
        
        while !locationService.isLocationReady && Date().timeIntervalSince(startTime) < maxWaitTime {
            try? await Task.sleep(nanoseconds: 100_000_000) // Check toutes les 100ms
        }
        
        if locationService.isLocationReady {
            let district = locationService.detectedDistrict?.name ?? "Inconnu"
            print("✅ Localisation terminée pendant le loading: \(district)")
        } else {
            print("⏰ Localisation pas terminée, continuera en arrière-plan")
        }
    }
}

struct AppLoadingView: View {
    @StateObject private var initService = AppInitializationService()
    @StateObject private var locationService = GlobalLocationService.shared
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Gradient de fond
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.green.opacity(0.6),
                    Color.blue.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo et titre
                VStack(spacing: 20) {
                    // Logo de l'app
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    
                    Text("EcoLyon")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    
                    Text("Votre assistant écologique lyonnais")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Section de chargement avec info localisation
                VStack(spacing: 24) {
                    // Barre de progression
                    VStack(spacing: 12) {
                        Text(initService.currentStatus)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // ✅ Affichage de l'arrondissement détecté
                        if let district = locationService.detectedDistrict {
                            Text("📍 \(district.name)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .transition(.opacity.combined(with: .scale))
                        }
                        
                        ZStack(alignment: .leading) {
                            // Fond de la barre
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white.opacity(0.3))
                                .frame(height: 8)
                            
                            // Progression
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white)
                                .frame(width: max(20, initService.initializationProgress * 280), height: 8)
                                .animation(.easeInOut(duration: 0.5), value: initService.initializationProgress)
                        }
                        .frame(width: 280)
                    }
                    
                    // Pourcentage
                    Text("\(Int(initService.initializationProgress * 100))%")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                    .frame(height: 60)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            Task {
                await initService.initializeApp()
            }
        }
        .onChange(of: initService.isAppReady) { isReady in
            if isReady {
                // Délai pour l'effet visuel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}
