//
//  NavigationManager.swift
//  EcoLyon
//
//  Navigation centralisée pour l'app
//

import SwiftUI

// MARK: - NavigationManager
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var currentDestination: String = "home"
    @Published var isMenuExpanded = false
    
    private init() {}
    
    // Méthodes de navigation centralisées
    func navigateToToilets() {
        print("🚽 Navigation vers toilettes")
        closeMenu()
        
        // Poster une notification que toutes vos vues peuvent écouter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToToilets"),
                object: nil
            )
        }
    }
    
    func navigateToBancs() {
        print("🪑 Navigation vers bancs")
        closeMenu()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToBancs"),
                object: nil
            )
        }
    }
    
    func navigateToHome() {
        print("🏠 Navigation vers accueil")
        closeMenu()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToHome"),
                object: nil
            )
        }
    }
    
    func navigateToFontaines() {
        print("⛲ Navigation vers fontaines - À implémenter")
        closeMenu()
    }
    
    func navigateToRandos() {
        print("🥾 Navigation vers randos - À implémenter")
        closeMenu()
    }
    
    // Ajouter d'autres destinations au fur et à mesure...
    
    // Gestion du menu
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
    
    // Couleur du thème selon la page actuelle
    var currentThemeColor: Color? {
        switch currentDestination {
        case "toilets":
            return Color(red: 0.7, green: 0.7, blue: 0.7)
        case "bancs":
            return Color(red: 0.7, green: 0.5, blue: 0.4)
        case "fontaines":
            return Color(red: 0xA5/255.0, green: 0xB2/255.0, blue: 0xA2/255.0)
        // Ajouter d'autres couleurs...
        default:
            return nil
        }
    }
}
