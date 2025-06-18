import SwiftUI

struct ContentView: View {
    @StateObject private var navigationManager = NavigationManager.shared
    @State private var showToiletsMap = false
    @State private var showBancsMap = false
    @State private var currentAQI = 3 // AQI de votre composant air quality
 
    
    var body: some View {
        ZStack {
            // Contenu principal
            ScrollView {
                VStack(spacing: 0) {
                    // Composant qualité de l'air intégré directement
                    AirQualityMapView()
                        .padding(.horizontal, 20)
                        .padding(.top, 0)
                        .padding(.bottom, 30)
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AQIUpdated"))) { notification in
                            if let aqi = notification.object as? Int {
                                currentAQI = aqi
                            }
                        }
                    
                    // Composant Recommandations
                    AirQualityRecommendationsView(fallbackAQI: currentAQI)
                        .padding(.bottom, 30)
                    
                    // NOUVEAU : Composant Services Environnementaux
                    EnvironmentCardView()
                        .padding(.bottom, 30)
                    
                    // Espacement en bas pour le menu
                    Spacer(minLength: 120)
                }
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            .fullScreenCover(isPresented: $showToiletsMap) {
                ToiletsMapView()
            }
            .fullScreenCover(isPresented: $showBancsMap) { // ✅ AJOUTÉ : fullScreenCover pour les bancs
                BancsMapView()
            }
            
            // Menu Bottom fixe
            FixedBottomMenuView(
                isMenuExpanded: $navigationManager.isMenuExpanded,
                showToiletsMap: .constant(false),
                showBancsMap: .constant(false),
                onHomeSelected: {
                    print("Déjà sur l'accueil")
                }
            )
        }
        // ✅ AJOUTÉ : Debug pour voir les changements d'état
        .onChange(of: showBancsMap) { newValue in
            print("🪑 ContentView - showBancsMap changed to: \(newValue)")
        }
        .onChange(of: showToiletsMap) { newValue in
            print("🚽 ContentView - showToiletsMap changed to: \(newValue)")
        }
        .onAppear {
            navigationManager.currentDestination = "home"
        }
        // ✅ CRUCIAL : Écoute des notifications de nav
       
    }
}

// MARK: - Composant exemple pour d'autres services
struct ExampleServiceButton: View {
    var body: some View {
        Button(action: {
            // Action pour un autre service
        }) {
            HStack(spacing: 15) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transports")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Horaires et itinéraires TCL")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.green, .green.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ContentView()
}
