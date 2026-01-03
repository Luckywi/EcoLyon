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
    static let fontaineColor = Color(red: 0xA5/255.0, green: 0xB2/255.0, blue: 0xA2/255.0)
    static let randoColor = Color(red: 0xD4/255.0, green: 0xBE/255.0, blue: 0xA0/255.0)
    static let poubelleColor = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let parcColor = Color(red: 0xAF/255.0, green: 0xD0/255.0, blue: 0xA3/255.0)
    static let compostColor = Color(red: 0.5, green: 0.35, blue: 0.25)
    static let silosColor = Color(red: 0.5, green: 0.7, blue: 0.7)
    static let bancsColor = Color(red: 0.7, green: 0.5, blue: 0.4)
    static let toilettesColor = Color(red: 0.7, green: 0.7, blue: 0.7)
    static let bornesColor = Color(red: 0.5, green: 0.6, blue: 0.7)
    static let accueilColor = Color(red: 0.2, green: 0.2, blue: 0.2)

    // Couleurs de thème
    static let defaultBackgroundColor = Color(red: 248/255, green: 247/255, blue: 244/255)
    static let toiletThemeColor = Color(red: 0.7, green: 0.7, blue: 0.7)
}

// MARK: - Menu simplifié avec NavigationManager
struct FixedBottomMenuView: View {
    @Binding var isMenuExpanded: Bool
    let onHomeSelected: () -> Void

    // État pour détecter le clavier
    @State private var keyboardHeight: CGFloat = 0

    // Référence au NavigationManager
    @ObservedObject private var navigationManager = NavigationManager.shared

    // Hauteur du bouton menu + padding pour le background
    private let menuButtonHeight: CGFloat = 56
    private let backgroundExtraHeight: CGFloat = 56

    // MARK: - Computed Properties

    private var isOnHomePage: Bool {
        navigationManager.isOnHomePage
    }

    private var themeColor: Color? {
        navigationManager.currentThemeColor
    }

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

    // MARK: - Init simplifié
    init(
        isMenuExpanded: Binding<Bool>,
        onHomeSelected: @escaping () -> Void
    ) {
        self._isMenuExpanded = isMenuExpanded
        self.onHomeSelected = onHomeSelected
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Arrière-plan complet - adapté au thème
                if isMenuExpanded {
                    ZStack {
                        backgroundColorOpen
                            .ignoresSafeArea(.all)

                        overlayColor
                            .ignoresSafeArea(.all)
                    }
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

                            // Layout du menu
                            MenuLayoutRedesigned(
                                onHomeSelected: onHomeSelected,
                                showHomeButton: !isOnHomePage
                            )
                            .padding(.horizontal, MenuDesignSystem.containerPadding)
                            .padding(.bottom, 20)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Onglet du menu avec couleur adaptée au thème
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()

                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                      to: nil, from: nil, for: nil)

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
                    .disabled(navigationManager.isTransitioning)
                }
                .padding(.horizontal, 20)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuExpanded)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .padding(.bottom, 0)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            handleKeyboardShow(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            handleKeyboardHide()
        }
    }

    // MARK: - Gestion du clavier
    private func handleKeyboardShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        keyboardHeight = keyboardFrame.height

        if isMenuExpanded {
            withAnimation(.easeOut(duration: 0.3)) {
                isMenuExpanded = false
            }
        }
    }

    private func handleKeyboardHide() {
        keyboardHeight = 0
    }
}

// MARK: - Layout redesigné - Simplifié
struct MenuLayoutRedesigned: View {
    let onHomeSelected: () -> Void
    let showHomeButton: Bool

    @ObservedObject private var navigationManager = NavigationManager.shared

    var body: some View {
        VStack(spacing: MenuDesignSystem.cardSpacing) {
            // LIGNE 1: Fontaines + Randos
            HStack(spacing: MenuDesignSystem.cardSpacing) {
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
                        navigationManager.navigate(to: .fontaines)
                    }
                )
                .frame(width: 100, height: 170)

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
                        navigationManager.navigate(to: .randos)
                    }
                )
                .frame(height: 170)
            }

            // LIGNE 2: Poubelles + Parcs et Jardins
            HStack(spacing: MenuDesignSystem.cardSpacing) {
                MenuCardRedesigned(
                    title: "Poubelles",
                    icon: "Poubelle",
                    iconSize: 80,
                    iconPosition: .top,
                    fontSize: 15,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.poubelleColor,
                    action: {
                        navigationManager.navigate(to: .poubelle)
                    }
                )
                .frame(width: 120, height: 140)

                MenuCardRedesigned(
                    title: "Parcs et Jardins",
                    icon: "PetJ",
                    iconSize: 80,
                    iconPosition: .top,
                    fontSize: 16,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.parcColor,
                    action: {
                        navigationManager.navigate(to: .parcs)
                    }
                )
                .frame(height: 140)
            }

            // LIGNE 3: Bornes à Compost + Silos à Verre
            HStack(spacing: MenuDesignSystem.cardSpacing) {
                MenuCardRedesigned(
                    title: "Bornes à Compost",
                    icon: "Compost",
                    iconSize: 80,
                    iconPosition: .left,
                    fontSize: 14,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.compostColor,
                    action: {
                        navigationManager.navigate(to: .compost)
                    }
                )
                .frame(height: 115)

                MenuCardRedesigned(
                    title: "Silos à Verre",
                    icon: "Silos",
                    iconSize: 60,
                    iconPosition: .top,
                    fontSize: 11,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.silosColor,
                    action: {
                        navigationManager.navigate(to: .silos)
                    }
                )
                .frame(width: 100, height: 115)
            }

            // LIGNE 4: Bancs + Toilettes + Bornes Électriques
            HStack(spacing: MenuDesignSystem.cardSpacing) {
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
                        navigationManager.navigate(to: .bancs)
                    }
                )
                .frame(height: 155)

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
                        navigationManager.navigate(to: .toilets)
                    }
                )
                .frame(height: 155)

                MenuCardRedesigned(
                    title: "Stations\nde Recharge",
                    icon: "Borne",
                    iconSize: 80,
                    iconPosition: .top,
                    fontSize: 12,
                    textPadding: 0,
                    cardPadding: 0,
                    backgroundColor: MenuDesignSystem.bornesColor,
                    action: {
                        navigationManager.navigate(to: .bornes)
                    }
                )
                .frame(height: 155)
            }

            // BOUTON ACCUEIL CONDITIONNEL
            if showHomeButton {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onHomeSelected()
                }) {
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
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

// MARK: - Position de l'icône
enum IconPosition {
    case top
    case left
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
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Group {
                if let icon = icon {
                    switch iconPosition {
                    case .top:
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

// Extension pour fermer le clavier
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var isMenuExpanded = false

        var body: some View {
            ZStack {
                Color(red: 248/255, green: 247/255, blue: 244/255)
                    .ignoresSafeArea()

                FixedBottomMenuView(
                    isMenuExpanded: $isMenuExpanded,
                    onHomeSelected: {
                        print("Accueil sélectionné")
                    }
                )
            }
        }
    }

    return PreviewWrapper()
}
