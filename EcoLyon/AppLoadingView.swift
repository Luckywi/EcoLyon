import SwiftUI
import CoreLocation

// Service global pour gérer l'état de l'app
@MainActor
class AppInitializationService: ObservableObject {
    @Published var isAppReady = false
    @Published var initializationProgress: Double = 0.0
    @Published var currentStatus = "Démarrage..."
    
    private let locationManager = CLLocationManager()
    
    func initializeApp() async {
        // Étape 1: Services de base
        await updateProgress(0.2, "Initialisation des services...")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Étape 2: Permissions
        await updateProgress(0.4, "Vérification des permissions...")
        await checkLocationPermissions()
        
        // Étape 3: Configuration
        await updateProgress(0.6, "Configuration...")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Étape 4: Données initiales
        await updateProgress(0.8, "Chargement des données...")
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
        
        // Étape 5: Finalisation
        await updateProgress(1.0, "Prêt !")
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        
        isAppReady = true
    }
    
    private func updateProgress(_ progress: Double, _ status: String) async {
        initializationProgress = progress
        currentStatus = status
    }
    
    private func checkLocationPermissions() async {
        return await withCheckedContinuation { continuation in
            switch locationManager.authorizationStatus {
            case .notDetermined:
                // Permission sera demandée plus tard par LocationManager
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    continuation.resume()
                }
            default:
                continuation.resume()
            }
        }
    }
}

struct AppLoadingView: View {
    @StateObject private var initService = AppInitializationService()
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
                
                // Section de chargement
                VStack(spacing: 24) {
                    // Barre de progression
                    VStack(spacing: 12) {
                        Text(initService.currentStatus)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
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
