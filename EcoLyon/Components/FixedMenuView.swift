import SwiftUI

// MARK: - Système de design basé sur la maquette
struct MenuDesignSystem {
    // Espacements
    static let cardSpacing: CGFloat = 8
    static let containerPadding: CGFloat = 16
    
    // Typographie
    static let fontLarge: CGFloat = 18
    static let fontMedium: CGFloat = 16
    static let fontSmall: CGFloat = 14
    
    // Rayons de coins
    static let cornerRadius: CGFloat = 16
    
    // Couleurs inspirées de la maquette
    static let fontaineColor = Color(red: 0xA5/255.0, green: 0xB2/255.0, blue: 0xA2/255.0).opacity(0.6)
    static let randoColor = Color(red: 0xD4/255.0, green: 0xBE/255.0, blue: 0xA0/255.0)
    static let poubelleColor = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let parcColor = Color(red: 0xAF/255.0, green: 0xD0/255.0, blue: 0xA3/255.0)
    static let compostColor = Color(red: 0.5, green: 0.35, blue: 0.25)
    static let silosColor = Color(red: 0.5, green: 0.7, blue: 0.7)
    static let bancsColor = Color(red: 0.7, green: 0.5, blue: 0.4)
    static let toilettesColor = Color(red: 0.7, green: 0.7, blue: 0.7)
    static let bornesColor = Color(red: 0.5, green: 0.6, blue: 0.7)
    static let accueilColor = Color(red: 0.5, green: 0.5, blue: 0.5)
    
    // Couleurs de thème
    static let defaultBackgroundColor = Color(red: 248/255, green: 247/255, blue: 244/255)
    static let toiletThemeColor = Color(red: 0.7, green: 0.7, blue: 0.7)
}


// ✅ MODIFICATION CRITIQUE : Éviter la fermeture automatique du menu lors du tap sur l'overlay
struct FixedBottomMenuView: View {
    @Binding var isMenuExpanded: Bool
    @Binding var showToiletsMap: Bool
    @Binding var showBancsMap: Bool
    let onHomeSelected: () -> Void
    
    // Paramètre pour le thème
    let themeColor: Color?
    
    // ✅ AJOUT : Référence au NavigationManager pour vérifier les transitions
    @StateObject private var navigationManager = NavigationManager.shared
    
    // Hauteur du bouton menu + padding pour le background
    private let menuButtonHeight: CGFloat = 56
    private let backgroundExtraHeight: CGFloat = 56
    
    // Computed properties pour les couleurs selon le thème
    private var backgroundColorClosed: Color {
        MenuDesignSystem.defaultBackgroundColor
    }
    
    private var backgroundColorOpen: Color {
        themeColor ?? MenuDesignSystem.defaultBackgroundColor
    }
    
    private var menuButtonColor: Color {
        themeColor ?? .black.opacity(0.7)
    }
    
    private var overlayColor: Color {
        if let themeColor = themeColor {
            return themeColor.opacity(0.9)
        } else {
            return .black.opacity(0.8)
        }
    }
    
    // Initializer
    init(
        isMenuExpanded: Binding<Bool>,
        showToiletsMap: Binding<Bool>,
        showBancsMap: Binding<Bool>,
        onHomeSelected: @escaping () -> Void,
        themeColor: Color? = nil
    ) {
        self._isMenuExpanded = isMenuExpanded
        self._showToiletsMap = showToiletsMap
        self._showBancsMap = showBancsMap
        self.onHomeSelected = onHomeSelected
        self.themeColor = themeColor
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Arrière-plan complet - adapté au thème
                if isMenuExpanded {
                    ZStack {
                        // Base avec couleur du thème pour le menu ouvert
                        backgroundColorOpen
                            .ignoresSafeArea(.all)
                        
                        // Overlay avec couleur du thème
                        overlayColor
                            .ignoresSafeArea(.all)
                    }
                    // ✅ MODIFICATION CRITIQUE : Ne fermer le menu que si on n'est pas en train de naviguer
                    .onTapGesture {
                        if !navigationManager.isTransitioning {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isMenuExpanded = false
                            }
                        }
                    }
                    .transition(.opacity)
                }
                
                // Background anti-superposition (toujours visible quand menu fermé)
                if !isMenuExpanded {
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(backgroundColorClosed)
                            .frame(height: menuButtonHeight + backgroundExtraHeight)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
                
                VStack(spacing: 0) {
                    // Contenu du menu quand il est ouvert
                    if isMenuExpanded {
                        VStack(spacing: 0) {
                            // Poignée de glissement
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(.systemGray3))
                                .frame(width: 36, height: 5)
                                .padding(.top, 12)
                                .padding(.bottom, 20)
                            
                            // ✅ Layout du menu SIMPLIFIÉ
                            MenuLayoutRedesigned(
                                onHomeSelected: onHomeSelected
                            )
                            .padding(.horizontal, MenuDesignSystem.containerPadding)
                            .padding(.bottom, 20)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Onglet du menu avec couleur adaptée au thème
                    Button(action: {
                        // ✅ Ne permettre l'ouverture/fermeture du menu que si on n'est pas en transition
                        if !navigationManager.isTransitioning {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isMenuExpanded.toggle()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Menu")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: isMenuExpanded ? "chevron.down" : "chevron.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMenuExpanded)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(isMenuExpanded ? Color.clear : menuButtonColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(.white.opacity(isMenuExpanded ? 0.0 : 0.2), lineWidth: 1)
                                )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    // ✅ Désactiver le bouton pendant les transitions
                    .disabled(navigationManager.isTransitioning)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 0)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuExpanded)
        }
    }
}
// MARK: - Layout redesigné selon la maquette - CORRIGÉ
struct MenuLayoutRedesigned: View {
    let onHomeSelected: () -> Void
    
    @StateObject private var navigationManager = NavigationManager.shared
    
    var body: some View {
        VStack(spacing: MenuDesignSystem.cardSpacing) {
            // LIGNE 1: Fontaines + Randos
            HStack(spacing: MenuDesignSystem.cardSpacing) {
                // Fontaines (grande carte verticale à gauche)
                MenuCardRedesigned(
                    title: "Fontaines\nd'Eau",
                    icon: "Fontaine",
                    iconSize: 98,
                    iconPosition: .top,
                    fontSize: 13,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.fontaineColor,
                    action: {
                        navigationManager.navigateToFontaines()
                    }
                )
                .frame(width: 100, height: 170)
                
                // Randos (carte horizontale qui prend le reste de l'espace)
                MenuCardRedesigned(
                    title: "Randos de la Métropole",
                    icon: "Rando",
                    iconSize: 100,
                    iconPosition: .top,
                    fontSize: 16,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.randoColor,
                    action: {
                        navigationManager.navigateToRandos()
                    }
                )
                .frame(height: 170)
            }
            
            // LIGNE 2: Poubelles + Parcs et Jardins
            HStack(spacing: MenuDesignSystem.cardSpacing) {
                // Poubelles (petite carte carrée)
                MenuCardRedesigned(
                    title: "Poubelles",
                    icon: "Poubelle",
                    iconSize: 80,
                    iconPosition: .top,
                    fontSize: 15,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.poubelleColor,
                    action: { print("Poubelles - À implémenter") }
                )
                .frame(width: 120, height: 140)
                
                // Parcs et Jardins (grande carte carrée avec icône)
                MenuCardRedesigned(
                    title: "Parcs et Jardins",
                    icon: "PetJ",
                    iconSize: 80,
                    iconPosition: .top,
                    fontSize: 16,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.parcColor,
                    action: { print("Parcs et Jardins - À implémenter") }
                )
                .frame(height: 140)
            }
            
            // LIGNE 3: Bornes à Compost + Silos à Verre
            HStack(spacing: MenuDesignSystem.cardSpacing) {
                // Bornes à Compost (carte large)
                MenuCardRedesigned(
                    title: "Bornes à Compost",
                    icon: "Compost",
                    iconSize: 80,
                    iconPosition: .left,
                    fontSize: 14,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.compostColor,
                    action: { print("Compost - À implémenter") }
                )
                .frame(height: 115)
                
                // Silos à Verre
                MenuCardRedesigned(
                    title: "Silos à Verre",
                    icon: "Silos",
                    iconSize: 60,
                    iconPosition: .top,
                    fontSize: 11,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.silosColor,
                    action: { print("Silos - À implémenter") }
                )
                .frame(width: 100, height: 115)
            }
            
            // LIGNE 4: Bancs + Toilettes + Bornes Électriques
            HStack(spacing: MenuDesignSystem.cardSpacing) {
                // ✅ Bancs avec navigation DIRECTE
                MenuCardRedesigned(
                    title: "Bancs",
                    icon: "Banc",
                    iconSize: 70,
                    iconPosition: .top,
                    fontSize: 12,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.bancsColor,
                    action: {
                        navigationManager.navigateToBancs()
                    }
                )
                .frame(height: 155)
                
                // ✅ Toilettes avec navigation DIRECTE
                MenuCardRedesigned(
                    title: "Toilettes\nPubliques",
                    icon: "Wc",
                    iconSize: 80,
                    iconPosition: .top,
                    fontSize: 12,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.toilettesColor,
                    action: {
                        navigationManager.navigateToToilets()
                    }
                )
                .frame(height: 155)
                
                // Bornes Électriques
                MenuCardRedesigned(
                    title: "Bornes\nÉlectriques",
                    icon: "Borne",
                    iconSize: 80,
                    iconPosition: .top,
                    fontSize: 12,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.bornesColor,
                    action: { print("Bornes Électriques - À implémenter") }
                )
                .frame(height: 155)
            }
            
            // BOUTON ACCUEIL
            Button(action: onHomeSelected) {
                Text("Accueil")
                    .font(.system(size: MenuDesignSystem.fontLarge, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: MenuDesignSystem.cornerRadius)
                            .fill(MenuDesignSystem.accueilColor)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Position de l'icône
enum IconPosition {
    case top    // Au-dessus du texte
    case left   // À gauche du texte
}

// MARK: - Carte unifiée avec icône optionnelle
struct MenuCardRedesigned: View {
    let title: String
    let icon: String?
    let iconSize: CGFloat
    let iconPosition: IconPosition
    let fontSize: CGFloat
    let textPadding: CGFloat
    let cardPadding: CGFloat
    let backgroundColor: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    switch iconPosition {
                    case .top:
                        // Icône au-dessus du texte (layout vertical)
                        VStack(spacing: 8) {
                            Spacer()
                            
                            Image(icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconSize, height: iconSize)
                                .foregroundColor(.white)
                            
                            Text(title)
                                .font(.system(size: fontSize, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, textPadding)
                            
                            Spacer()
                        }
                        
                    case .left:
                        // Icône à gauche du texte (layout horizontal)
                        HStack(spacing: 12) {
                            Image(icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconSize, height: iconSize)
                                .foregroundColor(.white)
                            
                            Text(title)
                                .font(.system(size: fontSize, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .padding(.horizontal, textPadding)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                } else {
                    // Pas d'icône, juste le texte centré
                    VStack {
                        Spacer()
                        
                        Text(title)
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, textPadding)
                        
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(cardPadding)
            .background(
                RoundedRectangle(cornerRadius: MenuDesignSystem.cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var isMenuExpanded = false
        @State private var showToiletsMap = false
        @State private var showBancsMap = false
        
        var body: some View {
            ZStack {
                Color(red: 248/255, green: 247/255, blue: 244/255)
                    .ignoresSafeArea()
                
                FixedBottomMenuView(
                    isMenuExpanded: $isMenuExpanded,
                    showToiletsMap: $showToiletsMap,
                    showBancsMap: $showBancsMap,
                    onHomeSelected: {
                        print("Accueil sélectionné")
                    }
                )
            }
        }
    }
    
    return PreviewWrapper()
}
