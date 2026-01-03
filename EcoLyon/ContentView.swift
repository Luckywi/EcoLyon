import SwiftUI

struct ContentView: View {
    @ObservedObject private var navigationManager = NavigationManager.shared
    @State private var currentAQI = 3

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

                    // Composant Services Environnementaux
                    EnvironmentCardView()
                        .padding(.bottom, 30)

                    // Espacement en bas pour le menu
                    Spacer(minLength: 120)
                }
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))

            // Menu avec bindings simplifiés
            FixedBottomMenuView(
                isMenuExpanded: $navigationManager.isMenuExpanded,
                onHomeSelected: {
                    navigationManager.navigateToHome()
                }
            )
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

#Preview {
    ContentView()
}
