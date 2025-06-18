//
//  NavigationManager.swift
//  EcoLyon
//
//  Navigation centralisée CORRIGÉE pour éviter les conflits de navigation
//

import SwiftUI

// MARK: - NavigationManager CORRIGÉ
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var currentDestination: String = "home"
    @Published var isMenuExpanded = false
    
    // ✅ NOUVEAUX ÉTATS CENTRALISÉS
    @Published var showToiletsMap = false
    @Published var showBancsMap = false
    @Published var showFontainesMap = false
    @Published var showRandosMap = false
    
    // ✅ NOUVEAU : État pour gérer les transitions
    @Published var isTransitioning = false
    
    private init() {}
    
    // ✅ NAVIGATION DIRECTE AMÉLIORÉE avec gestion des transitions
    func navigateToToilets() {
        print("🚽 Navigation vers toilettes")
        
        // Éviter les doubles navigations
        guard !isTransitioning else { return }
        isTransitioning = true
        
        closeMenu()
        
        // ✅ FERMETURE SÉQUENTIELLE au lieu de simultanée
        if showBancsMap {
            showBancsMap = false
            // Attendre un peu avant d'ouvrir la nouvelle vue
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openToiletsAfterDelay()
            }
        } else {
            openToiletsAfterDelay()
        }
    }
    
    private func openToiletsAfterDelay() {
        // Fermer toutes les autres vues
        showFontainesMap = false
        showRandosMap = false
        
        // Ouvrir toilettes
        showToiletsMap = true
        currentDestination = "toilets"
        
        // Réinitialiser l'état de transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToBancs() {
        print("🪑 Navigation vers bancs")
        
        // Éviter les doubles navigations
        guard !isTransitioning else { return }
        isTransitioning = true
        
        closeMenu()
        
        // ✅ FERMETURE SÉQUENTIELLE au lieu de simultanée
        if showToiletsMap {
            showToiletsMap = false
            // Attendre un peu avant d'ouvrir la nouvelle vue
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openBancsAfterDelay()
            }
        } else {
            openBancsAfterDelay()
        }
    }
    
    private func openBancsAfterDelay() {
        // Fermer toutes les autres vues
        showFontainesMap = false
        showRandosMap = false
        
        // Ouvrir bancs
        showBancsMap = true
        currentDestination = "bancs"
        
        // Réinitialiser l'état de transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToFontaines() {
        print("⛲ Navigation vers fontaines")
        
        guard !isTransitioning else { return }
        isTransitioning = true
        
        closeMenu()
        
        // Fermer toutes les autres vues avec délai si nécessaire
        if showToiletsMap || showBancsMap {
            showToiletsMap = false
            showBancsMap = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openFontainesAfterDelay()
            }
        } else {
            openFontainesAfterDelay()
        }
    }
    
    private func openFontainesAfterDelay() {
        showRandosMap = false
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
        
        // Fermer toutes les autres vues avec délai si nécessaire
        if showToiletsMap || showBancsMap {
            showToiletsMap = false
            showBancsMap = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openRandosAfterDelay()
            }
        } else {
            openRandosAfterDelay()
        }
    }
    
    private func openRandosAfterDelay() {
        showFontainesMap = false
        showRandosMap = true
        currentDestination = "randos"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }
    
    func navigateToHome() {
        print("🏠 Navigation vers accueil")
        
        guard !isTransitioning else { return }
        isTransitioning = true
        
        closeMenu()
        
        // Fermer toutes les vues
        showToiletsMap = false
        showBancsMap = false
        showFontainesMap = false
        showRandosMap = false
        
        currentDestination = "home"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
        }
    }
    
    // ✅ FERMETURE D'UNE VUE SPÉCIFIQUE (inchangées mais avec protection)
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
    
    // Gestion du menu (inchangée)
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
    
    // Couleur du thème selon la page actuelle (inchangée)
    var currentThemeColor: Color? {
        switch currentDestination {
        case "toilets":
            return Color(red: 0.7, green: 0.7, blue: 0.7)
        case "bancs":
            return Color(red: 0.7, green: 0.5, blue: 0.4)
        case "fontaines":
            return Color(red: 0xA5/255.0, green: 0xB2/255.0, blue: 0xA2/255.0)
        default:
            return nil
        }
    }
}
