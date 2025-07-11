import SwiftUI

struct ContentView: View {
    @StateObject private var navigationManager = NavigationManager.shared
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
                    
                    // Composant Services Environnementaux
                    EnvironmentCardView()
                        .padding(.bottom, 30)
                    
                    // Espacement en bas pour le menu
                    Spacer(minLength: 120)
                }
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            
            // ✅ MENU CORRIGÉ - AVEC FONTAINES INTÉGRÉES
            FixedBottomMenuView(
                isMenuExpanded: $navigationManager.isMenuExpanded,
                showToiletsMap: $navigationManager.showToiletsMap,
                showBancsMap: $navigationManager.showBancsMap,
                showFontainesMap: $navigationManager.showFontainesMap,  // ✅ AJOUTÉ
                showSilosMap: $navigationManager.showSilosMap,
                showBornesMap: $navigationManager.showBornesMap,
                showCompostMap: $navigationManager.showCompostMap,
                showParcsMap: $navigationManager.showParcsMap,
                showPoubelleMap: $navigationManager.showPoubelleMap,
                showRandosMap: $navigationManager.showRandosMap,
                onHomeSelected: {
                    navigationManager.navigateToHome()
                }
            )
        }
        .onAppear {
            navigationManager.currentDestination = "home"
        }
        // ✅ NAVIGATION CORRIGÉE - UTILISE LES ÉTATS DU NAVIGATIONMANAGER
        .fullScreenCover(isPresented: $navigationManager.showToiletsMap) {
            ToiletsMapView()
                .onDisappear {
                    navigationManager.closeToilets()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showBancsMap) {
            BancsMapView()
                .onDisappear {
                    navigationManager.closeBancs()
                }
        }
        // ✅ FONTAINES INTÉGRÉES - REMPLACE LE PLACEHOLDER
        .fullScreenCover(isPresented: $navigationManager.showFontainesMap) {
            FontainesMapView()
                .onDisappear {
                    navigationManager.closeFontaines()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showRandosMap) {
            RandosMapView()
                .onDisappear {
                    navigationManager.closeRandos()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showSilosMap) {
            SilosMapView()
                .onDisappear {
                    navigationManager.closeSilos()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showBornesMap) {
            BornesMapView()
                .onDisappear {
                    navigationManager.closeBornes()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showCompostMap) {
            CompostMapView()
                .onDisappear {
                    navigationManager.closeCompost()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showParcsMap) {
            ParcsMapView()
                .onDisappear {
                    navigationManager.closeParcs()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showPoubelleMap) {
            PoubelleMapView()
                .onDisappear {
                    navigationManager.closePoubelle()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showComposteurGratuitView) {
            ComposteurGratuitView()
                .onDisappear {
                    navigationManager.closeComposteurGratuit()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showCompostGuideView) {
            CompostGuideView()
                .onDisappear {
                    navigationManager.closeCompostGuide()
                }
        }
        .fullScreenCover(isPresented: $navigationManager.showLyonFactsView) {
            LyonFactsView()
                .onDisappear {
                    navigationManager.closeLyonFacts()
                }
        }


    }
}

#Preview {
    ContentView()
}
