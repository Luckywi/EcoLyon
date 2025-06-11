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
                    // Logo de l'app avec animation subtile
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .scaleEffect(initService.initializationProgress > 0.5 ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: initService.initializationProgress)
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
                
                // Section de chargement avec info localisation optimisée
                VStack(spacing: 24) {
                    // Barre de progression
                    VStack(spacing: 12) {
                        Text(initService.currentStatus)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // ✅ Affichage de l'arrondissement détecté avec animation améliorée
                        if let district = locationService.detectedDistrict {
                            HStack(spacing: 8) {
                                // Icône de localisation animée
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12, weight: .semibold))
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 0.5).repeatCount(1, autoreverses: false), value: district.name)
                                
                                Text(district.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.15))
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        } else if locationService.locationError != nil {
                            // ✅ Affichage de l'erreur de localisation
                            HStack(spacing: 8) {
                                Image(systemName: "location.slash")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12, weight: .semibold))
                                
                                Text("Position indisponible")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.orange.opacity(0.2))
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                        
                        // Barre de progression avec animation fluide
                        ZStack(alignment: .leading) {
                            // Fond de la barre
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white.opacity(0.3))
                                .frame(height: 8)
                            
                            // Progression avec dégradé
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.white, .white.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(20, initService.initializationProgress * 280), height: 8)
                                .animation(.easeInOut(duration: 0.5), value: initService.initializationProgress)
                        }
                        .frame(width: 280)
                    }
                    
                    // Pourcentage avec animation compatible iOS 15+
                    Text("\(Int(initService.initializationProgress * 100))%")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .animation(.easeInOut(duration: 0.3), value: initService.initializationProgress)
                    
                    // ✅ Indicateur de statut de localisation discret
                    if initService.initializationProgress > 0.3 {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(locationService.isLocationReady ? .green : .orange)
                                .frame(width: 6, height: 6)
                            
                            Text(locationService.isLocationReady ? "Localisation OK" : "Recherche position...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                
                Spacer()
                    .frame(height: 60)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            // ✅ Démarrage optimisé de l'initialisation
            Task {
                await initService.initializeApp()
            }
        }
        // ✅ CORRIGÉ : onChange compatible iOS 15+
        .onChange(of: initService.isAppReady) { isReady in
            if isReady {
                // ✅ Délai réduit pour transition plus rapide
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
        // ✅ Animation lors du changement d'arrondissement pendant le loading - Compatible iOS 15+
        .onChange(of: locationService.detectedDistrict) { district in
            if let district = district {
                print("🎯 Arrondissement mis à jour pendant loading: \(district.name)")
            }
        }
        // ✅ Réaction au changement de statut de localisation - Compatible iOS 15+
        .onChange(of: locationService.isLocationReady) { isReady in
            if isReady {
                print("✅ Localisation prête pendant le loading")
            }
        }
    }
}
