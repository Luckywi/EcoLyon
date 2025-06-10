import SwiftUI

struct ContentView: View {
    @State private var showToiletsMap = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Composant qualité de l'air intégré directement
                AirQualityMapView()
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
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
                    
                    // Espacement en bas
                    Spacer(minLength: 60)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showToiletsMap) {
            ToiletsMapView()
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
