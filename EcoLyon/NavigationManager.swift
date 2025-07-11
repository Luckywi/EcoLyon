//
//  NavigationManager.swift
//  EcoLyon
//
//  Gestion centralisée de la navigation, enrichie pour la nouvelle page "Fontaines"
//

import SwiftUI

// MARK: - NavigationManager CORRIGÉ
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var currentDestination: String = "home"
    @Published var isMenuExpanded = false
    
    // ✅ ÉTATS CENTRALISÉS - AJOUT DES FONTAINES
    @Published var showToiletsMap = false
    @Published var showBancsMap = false
    @Published var showFontainesMap = false
    @Published var showRandosMap = false
    @Published var showSilosMap = false
    @Published var showBornesMap = false
    @Published var showCompostMap = false
    @Published var showParcsMap = false
    @Published var showPoubelleMap = false
    @Published var showComposteurGratuitView = false
    @Published var showCompostGuideView = false
    @Published var showLyonFactsView = false
    
    // ✅ État pour gérer les transitions
    @Published var isTransitioning = false
    
    private init() {}
    
    // ✅ MÉTHODE GÉNÉRIQUE POUR FERMER TOUTES LES VUES
    private func closeAllMaps() {
        showToiletsMap = false
        showBancsMap = false
        showFontainesMap = false
        showRandosMap = false
        showSilosMap = false
        showBornesMap = false
        showCompostMap = false
        showParcsMap = false
        showPoubelleMap = false
    }
    
    // MARK: - NAVIGATION VERS LES DIFFÉRENTES VUES
    
    func navigateToLyonFacts() {
        showLyonFactsView = true
    }

    func closeLyonFacts() {
        showLyonFactsView = false
    }
    
    
    func navigateToCompostGuide() {
        showCompostGuideView = true
    }

    func closeCompostGuide() {
        showCompostGuideView = false
    }
    
    

    // ✅ CORRECTION : composteurGratuit se comporte maintenant comme compostGuide
    func navigateToComposteurGratuit() {
        showComposteurGratuitView = true
    }

    func closeComposteurGratuit() {
        showComposteurGratuitView = false
    }
    
    func navigateToToilets() {
        print("🚽 Navigation vers toilettes")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showToiletsMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showBancsMap || showFontainesMap || showRandosMap || showSilosMap || showBornesMap || showCompostMap || showParcsMap || showPoubelleMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openToiletsAfterDelay()
            }
        } else {
            openToiletsAfterDelay()
        }
    }
    private func openToiletsAfterDelay() {
        showToiletsMap = true
        currentDestination = "toilets"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToBancs() {
        print("🪑 Navigation vers bancs")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showBancsMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showToiletsMap || showFontainesMap || showRandosMap || showSilosMap || showBornesMap || showCompostMap || showParcsMap || showPoubelleMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openBancsAfterDelay()
            }
        } else {
            openBancsAfterDelay()
        }
    }
    private func openBancsAfterDelay() {
        showBancsMap = true
        currentDestination = "bancs"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    // ✅ NAVIGATION VERS FONTAINES - INTÉGRÉE
    func navigateToFontaines() {
        print("⛲ Navigation vers fontaines")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showFontainesMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showToiletsMap || showBancsMap || showRandosMap || showSilosMap || showBornesMap || showCompostMap || showParcsMap || showPoubelleMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openFontainesAfterDelay()
            }
        } else {
            openFontainesAfterDelay()
        }
    }
    private func openFontainesAfterDelay() {
        showFontainesMap = true
        currentDestination = "fontaines"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToRandos() {
        print("🥾 Navigation vers randos")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showRandosMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showToiletsMap || showBancsMap || showFontainesMap || showSilosMap || showBornesMap || showCompostMap || showParcsMap || showPoubelleMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openRandosAfterDelay()
            }
        } else {
            openRandosAfterDelay()
        }
    }
    private func openRandosAfterDelay() {
        showRandosMap = true
        currentDestination = "randos"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToSilos() {
        print("🗂️ Navigation vers silos")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showSilosMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showToiletsMap || showBancsMap || showFontainesMap || showRandosMap || showBornesMap || showCompostMap || showParcsMap || showPoubelleMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openSilosAfterDelay()
            }
        } else {
            openSilosAfterDelay()
        }
    }
    private func openSilosAfterDelay() {
        showSilosMap = true
        currentDestination = "silos"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToBornes() {
        print("🔌 Navigation vers bornes électriques")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showBornesMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showToiletsMap || showBancsMap || showFontainesMap || showRandosMap || showSilosMap || showCompostMap || showParcsMap || showPoubelleMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openBornesAfterDelay()
            }
        } else {
            openBornesAfterDelay()
        }
    }
    private func openBornesAfterDelay() {
        showBornesMap = true
        currentDestination = "bornes"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToCompost() {
        print("🗑️ Navigation vers compost")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showCompostMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showToiletsMap || showBancsMap || showFontainesMap || showRandosMap || showSilosMap || showBornesMap || showParcsMap || showPoubelleMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openCompostAfterDelay()
            }
        } else {
            openCompostAfterDelay()
        }
    }
    private func openCompostAfterDelay() {
        showCompostMap = true
        currentDestination = "compost"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToParcs() {
        print("🌳 Navigation vers parcs")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showParcsMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showToiletsMap || showBancsMap || showFontainesMap || showRandosMap || showSilosMap || showBornesMap || showCompostMap || showPoubelleMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openParcsAfterDelay()
            }
        } else {
            openParcsAfterDelay()
        }
    }
    private func openParcsAfterDelay() {
        showParcsMap = true
        currentDestination = "parcs"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToPoubelle() {
        print("🗑️ Navigation vers poubelles")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        if showPoubelleMap {
            isTransitioning = false
            return
        }
        let hasOtherViewOpen = showToiletsMap || showBancsMap || showFontainesMap || showRandosMap || showSilosMap || showBornesMap || showCompostMap || showParcsMap
        if hasOtherViewOpen {
            closeAllMaps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openPoubelleAfterDelay()
            }
        } else {
            openPoubelleAfterDelay()
        }
    }
    private func openPoubelleAfterDelay() {
        showPoubelleMap = true
        currentDestination = "poubelle"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    // ✅ NAVIGATION VERS L'ACCUEIL
    func navigateToHome() {
        print("🏠 Navigation vers accueil")
        guard !isTransitioning else { return }
        isTransitioning = true
        closeMenu()
        closeAllMaps()
        currentDestination = "home"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
        }
    }
    
    // MARK: - FERMETURE DES VUES SPÉCIFIQUES
    func closeToilets() {
        guard !isTransitioning else { return }
        showToiletsMap = false
        currentDestination = "home"
    }
    func closeBancs() {
        guard !isTransitioning else { return }
        showBancsMap = false
        currentDestination = "home"
    }
    // ✅ FERMETURE DES FONTAINES - INTÉGRÉE
    func closeFontaines() {
        guard !isTransitioning else { return }
        showFontainesMap = false
        currentDestination = "home"
    }
    func closeRandos() {
        guard !isTransitioning else { return }
        showRandosMap = false
        currentDestination = "home"
    }
    func closeSilos() {
        guard !isTransitioning else { return }
        showSilosMap = false
        currentDestination = "home"
    }
    func closeBornes() {
        guard !isTransitioning else { return }
        showBornesMap = false
        currentDestination = "home"
    }
    func closeCompost() {
        guard !isTransitioning else { return }
        showCompostMap = false
        currentDestination = "home"
    }
    func closeParcs() {
        guard !isTransitioning else { return }
        showParcsMap = false
        currentDestination = "home"
    }
    func closePoubelle() {
        guard !isTransitioning else { return }
        showPoubelleMap = false
        currentDestination = "home"
    }
    
    // MARK: - GESTION DU MENU
    func toggleMenu() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isMenuExpanded.toggle()
        }
    }
    func closeMenu() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isMenuExpanded = false
        }
    }
    
    // MARK: - COULEURS THÉMATIQUES - AVEC FONTAINES
    var currentThemeColor: Color? {
        switch currentDestination {
        case "toilets":
            return Color(red: 0.7, green: 0.7, blue: 0.7)
        case "bancs":
            return Color(red: 0.7, green: 0.5, blue: 0.4)
        case "fontaines":
            return Color(red: 0xA5/255.0, green: 0xB2/255.0, blue: 0xA2/255.0).opacity(0.6)
        case "randos":
            return Color(red: 0.2, green: 0.6, blue: 0.2)
        case "silos":
            return Color(red: 0.5, green: 0.7, blue: 0.7)
        case "bornes":
            return Color(red: 0.5, green: 0.6, blue: 0.7)
        case "compost":
            return Color(red: 0.5, green: 0.35, blue: 0.25)
        case "parcs":
            return Color(red: 0.3, green: 0.7, blue: 0.3)
        case "poubelle":
            return Color(red: 0.6, green: 0.6, blue: 0.6)
        default:
            return nil
        }
    }
    
    // ✅ MÉTHODE UTILITAIRE POUR DEBUGGING
    func getCurrentState() -> String {
        return """
        Current State:
        - Destination: \(currentDestination)
        - Toilets: \(showToiletsMap)
        - Bancs: \(showBancsMap)
        - Fontaines: \(showFontainesMap)
        - Randos: \(showRandosMap)
        - Silos: \(showSilosMap)
        - Bornes: \(showBornesMap)
        - Compost: \(showCompostMap)
        - Parcs: \(showParcsMap)
        - Poubelle: \(showPoubelleMap)
        - Transitioning: \(isTransitioning)
        - Menu Expanded: \(isMenuExpanded)
        """
    }
}
