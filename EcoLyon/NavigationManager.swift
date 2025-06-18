//
//  NavigationManager.swift
//  EcoLyon
//
//  Navigation centralisée CORRIGÉE pour l'app
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
    
    private init() {}
    
    // ✅ NAVIGATION DIRECTE (plus de notifications)
    func navigateToToilets() {
        print("🚽 Navigation vers toilettes")
        closeMenu()
        
        // Fermer toutes les autres vues
        showBancsMap = false
        showFontainesMap = false
        showRandosMap = false
        
        // Ouvrir toilettes
        showToiletsMap = true
        currentDestination = "toilets"
    }
    
    func navigateToBancs() {
        print("🪑 Navigation vers bancs")
        closeMenu()
        
        // Fermer toutes les autres vues
        showToiletsMap = false
        showFontainesMap = false
        showRandosMap = false
        
        // Ouvrir bancs
        showBancsMap = true
        currentDestination = "bancs"
    }
    
    func navigateToFontaines() {
        print("⛲ Navigation vers fontaines")
        closeMenu()
        
        // Fermer toutes les autres vues
        showToiletsMap = false
        showBancsMap = false
        showRandosMap = false
        
        // Ouvrir fontaines
        showFontainesMap = true
        currentDestination = "fontaines"
    }
    
    func navigateToRandos() {
        print("🥾 Navigation vers randos")
        closeMenu()
        
        // Fermer toutes les autres vues
        showToiletsMap = false
        showBancsMap = false
        showFontainesMap = false
        
        // Ouvrir randos
        showRandosMap = true
        currentDestination = "randos"
    }
    
    func navigateToHome() {
        print("🏠 Navigation vers accueil")
        closeMenu()
        
        // Fermer toutes les vues
        showToiletsMap = false
        showBancsMap = false
        showFontainesMap = false
        showRandosMap = false
        
        currentDestination = "home"
    }
    
    // ✅ FERMETURE D'UNE VUE SPÉCIFIQUE
    func closeToilets() {
        showToiletsMap = false
        currentDestination = "home"
    }
    
    func closeBancs() {
        showBancsMap = false
        currentDestination = "home"
    }
    
    func closeFontaines() {
        showFontainesMap = false
        currentDestination = "home"
    }
    
    func closeRandos() {
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
