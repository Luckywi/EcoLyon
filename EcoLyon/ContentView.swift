import SwiftUI

struct ContentView: View {
    @State private var showToiletsMap = false
    @State private var isMenuExpanded = false
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
                    
                    // NOUVEAU : Composant Recommandations
                    AirQualityRecommendationsView(fallbackAQI: currentAQI)
                        .padding(.bottom, 30)
                    
                    // Section autres fonctionnalités
                    VStack(spacing: 20) {
                        // Divider avec texte
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("Autres services")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 10)
                        
                        // Bouton toilettes stylisé
                        Button(action: {
                            showToiletsMap = true
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "toilet.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Toilettes Publiques")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    Text("Trouvez les toilettes les plus proches")
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
                                    gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 20)
                        
                        // Autres boutons peuvent être ajoutés ici
                        // ExampleServiceButton()
                        
                        // Espacement en bas pour le menu
                        Spacer(minLength: 120) // Plus d'espace pour le menu bottom
                    }
                }
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            .fullScreenCover(isPresented: $showToiletsMap) {
                ToiletsMapView()
            }
            
            // NOUVEAU : Menu Bottom fixe
            FixedBottomMenuView(
                isMenuExpanded: $isMenuExpanded,
                showToiletsMap: $showToiletsMap,
                onHomeSelected: {
                    // Action pour retourner en haut ou rafraîchir
                    print("Retour à l'accueil")
                }
            )
        }
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
