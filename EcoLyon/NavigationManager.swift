//
//  NavigationManager.swift
//  EcoLyon
//
//  Gestion centralisée de la navigation avec enum
//

import SwiftUI

// MARK: - Destination Enum
enum Destination: String, CaseIterable, Identifiable {
    case home
    case toilets
    case bancs
    case fontaines
    case randos
    case silos
    case bornes
    case compost
    case parcs
    case poubelle
    case composteurGratuit
    case compostGuide
    case lyonFacts

    var id: String { rawValue }

    // MARK: - Couleur thématique pour chaque destination
    var themeColor: Color {
        switch self {
        case .home:
            return Color.clear
        case .toilets:
            return Color(red: 0.7, green: 0.7, blue: 0.7)
        case .bancs:
            return Color(red: 0.7, green: 0.5, blue: 0.4)
        case .fontaines:
            return Color(red: 0xA5/255.0, green: 0xB2/255.0, blue: 0xA2/255.0).opacity(0.6)
        case .randos:
            return Color(red: 0.2, green: 0.6, blue: 0.2)
        case .silos:
            return Color(red: 0.5, green: 0.7, blue: 0.7)
        case .bornes:
            return Color(red: 0.5, green: 0.6, blue: 0.7)
        case .compost:
            return Color(red: 0.5, green: 0.35, blue: 0.25)
        case .parcs:
            return Color(red: 0xAF/255.0, green: 0xD0/255.0, blue: 0xA3/255.0)
        case .poubelle:
            return Color(red: 0.6, green: 0.6, blue: 0.6)
        case .composteurGratuit:
            return Color(red: 0.5, green: 0.35, blue: 0.25)
        case .compostGuide:
            return Color(red: 0.5, green: 0.35, blue: 0.25)
        case .lyonFacts:
            return Color.blue.opacity(0.3)
        }
    }

    // MARK: - Emoji pour debug
    var emoji: String {
        switch self {
        case .home: return "🏠"
        case .toilets: return "🚽"
        case .bancs: return "🪑"
        case .fontaines: return "⛲"
        case .randos: return "🥾"
        case .silos: return "🗂️"
        case .bornes: return "🔌"
        case .compost: return "🗑️"
        case .parcs: return "🌳"
        case .poubelle: return "🗑️"
        case .composteurGratuit: return "♻️"
        case .compostGuide: return "📖"
        case .lyonFacts: return "📍"
        }
    }

    // MARK: - Est-ce une MapView (fullscreen cover)
    var isMapView: Bool {
        switch self {
        case .home:
            return false
        case .toilets, .bancs, .fontaines, .randos, .silos, .bornes, .compost, .parcs, .poubelle:
            return true
        case .composteurGratuit, .compostGuide, .lyonFacts:
            return true // Ce sont aussi des fullscreen covers
        }
    }
}

// MARK: - NavigationManager Refactorisé
@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()

    // MARK: - État principal
    @Published var currentDestination: Destination = .home
    @Published var presentedDestination: Destination? = nil
    @Published var isMenuExpanded = false
    @Published private(set) var isTransitioning = false

    private init() {}

    // MARK: - Computed Properties

    /// Couleur du thème actuel
    var currentThemeColor: Color? {
        guard currentDestination != .home else { return nil }
        return currentDestination.themeColor
    }

    /// Est-on sur la page d'accueil ?
    var isOnHomePage: Bool {
        currentDestination == .home && presentedDestination == nil
    }

    // MARK: - Navigation principale

    /// Naviguer vers une destination
    func navigate(to destination: Destination) {
        guard !isTransitioning else {
            print("⚠️ Navigation bloquée - transition en cours")
            return
        }

        print("\(destination.emoji) Navigation vers \(destination.rawValue)")

        // Si on navigue vers home
        if destination == .home {
            navigateToHome()
            return
        }

        // Si on est déjà sur cette destination
        if presentedDestination == destination {
            print("ℹ️ Déjà sur \(destination.rawValue)")
            return
        }

        isTransitioning = true
        closeMenu()

        // Si une autre vue est ouverte, la fermer d'abord
        if presentedDestination != nil {
            presentedDestination = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openDestination(destination)
            }
        } else {
            openDestination(destination)
        }
    }

    private func openDestination(_ destination: Destination) {
        presentedDestination = destination
        currentDestination = destination
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isTransitioning = false
        }
    }

    /// Retourner à l'accueil
    func navigateToHome() {
        guard !isTransitioning else { return }

        print("🏠 Navigation vers accueil")
        isTransitioning = true
        closeMenu()
        presentedDestination = nil
        currentDestination = .home

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
        }
    }

    /// Fermer la vue actuelle
    func closeCurrentView() {
        guard !isTransitioning else { return }
        presentedDestination = nil
        currentDestination = .home
    }

    // MARK: - Gestion du menu

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

    // MARK: - Méthodes de compatibilité (pour transition progressive)
    // Ces méthodes appellent simplement navigate(to:) pour garder la compatibilité

    func navigateToToilets() { navigate(to: .toilets) }
    func navigateToBancs() { navigate(to: .bancs) }
    func navigateToFontaines() { navigate(to: .fontaines) }
    func navigateToRandos() { navigate(to: .randos) }
    func navigateToSilos() { navigate(to: .silos) }
    func navigateToBornes() { navigate(to: .bornes) }
    func navigateToCompost() { navigate(to: .compost) }
    func navigateToParcs() { navigate(to: .parcs) }
    func navigateToPoubelle() { navigate(to: .poubelle) }
    func navigateToComposteurGratuit() { navigate(to: .composteurGratuit) }
    func navigateToCompostGuide() { navigate(to: .compostGuide) }
    func navigateToLyonFacts() { navigate(to: .lyonFacts) }

    func closeToilets() { closeCurrentView() }
    func closeBancs() { closeCurrentView() }
    func closeFontaines() { closeCurrentView() }
    func closeRandos() { closeCurrentView() }
    func closeSilos() { closeCurrentView() }
    func closeBornes() { closeCurrentView() }
    func closeCompost() { closeCurrentView() }
    func closeParcs() { closeCurrentView() }
    func closePoubelle() { closeCurrentView() }
    func closeComposteurGratuit() { closeCurrentView() }
    func closeCompostGuide() { closeCurrentView() }
    func closeLyonFacts() { closeCurrentView() }

    // MARK: - Computed properties de compatibilité (bindings)
    // Ces propriétés permettent de garder la compatibilité avec le code existant

    var showToiletsMap: Bool {
        get { presentedDestination == .toilets }
        set { if !newValue { closeCurrentView() } }
    }

    var showBancsMap: Bool {
        get { presentedDestination == .bancs }
        set { if !newValue { closeCurrentView() } }
    }

    var showFontainesMap: Bool {
        get { presentedDestination == .fontaines }
        set { if !newValue { closeCurrentView() } }
    }

    var showRandosMap: Bool {
        get { presentedDestination == .randos }
        set { if !newValue { closeCurrentView() } }
    }

    var showSilosMap: Bool {
        get { presentedDestination == .silos }
        set { if !newValue { closeCurrentView() } }
    }

    var showBornesMap: Bool {
        get { presentedDestination == .bornes }
        set { if !newValue { closeCurrentView() } }
    }

    var showCompostMap: Bool {
        get { presentedDestination == .compost }
        set { if !newValue { closeCurrentView() } }
    }

    var showParcsMap: Bool {
        get { presentedDestination == .parcs }
        set { if !newValue { closeCurrentView() } }
    }

    var showPoubelleMap: Bool {
        get { presentedDestination == .poubelle }
        set { if !newValue { closeCurrentView() } }
    }

    var showComposteurGratuitView: Bool {
        get { presentedDestination == .composteurGratuit }
        set { if !newValue { closeCurrentView() } }
    }

    var showCompostGuideView: Bool {
        get { presentedDestination == .compostGuide }
        set { if !newValue { closeCurrentView() } }
    }

    var showLyonFactsView: Bool {
        get { presentedDestination == .lyonFacts }
        set { if !newValue { closeCurrentView() } }
    }

    // MARK: - Debug
    func getCurrentState() -> String {
        return """
        Current State:
        - Destination: \(currentDestination.rawValue)
        - Presented: \(presentedDestination?.rawValue ?? "nil")
        - Transitioning: \(isTransitioning)
        - Menu Expanded: \(isMenuExpanded)
        """
    }
}
