import SwiftUI

struct FixedBottomMenuView: View {
    @Binding var isMenuExpanded: Bool
    @Binding var showToiletsMap: Bool
    let onHomeSelected: () -> Void
    
    private let menuHeight: CGFloat = 160 // Hauteur du menu étendu
    private let tabHeight: CGFloat = 60 // Hauteur de l'onglet fermé
    private let fadeHeight: CGFloat = 15 // Zone de fade au-dessus du menu (5px + transition)
    
    var body: some View {
        ZStack {
            // ✅ NOUVEAU : Zone de masquage invisible qui cache le contenu
            VStack(spacing: 0) { // ✅ spacing: 0 pour éliminer l'espace
                Spacer()
                
                // Zone de fade dégradé
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color(red: 248/255, green: 247/255, blue: 244/255).opacity(0.3), location: 0.3),
                        .init(color: Color(red: 248/255, green: 247/255, blue: 244/255).opacity(0.7), location: 0.7),
                        .init(color: Color(red: 248/255, green: 247/255, blue: 244/255), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)
                .allowsHitTesting(false) // Ne bloque pas les interactions
                
                // ✅ Zone opaque qui masque complètement le contenu jusqu'en bas de l'écran
                Color(red: 248/255, green: 247/255, blue: 244/255)
                    .frame(height: tabHeight + (isMenuExpanded ? menuHeight - tabHeight : 0) + 50) // ✅ +50 au lieu de +34 pour être sûr de couvrir tout
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(.all, edges: .bottom) // ✅ Ignore la safe area en bas pour aller jusqu'au bord
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuExpanded)
            
            // Filtre de fond quand le menu est ouvert
            if isMenuExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isMenuExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Menu étendu (visible uniquement quand ouvert)
                    if isMenuExpanded {
                        VStack(spacing: 16) {
                            // Header avec ligne de glissement
                            VStack(spacing: 16) {
                                // Ligne de glissement
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(Color(.systemGray3))
                                    .frame(width: 36, height: 5)
                                
                                // Boutons du menu avec style iOS moderne
                                VStack(spacing: 12) {
                                    // Bouton Accueil
                                    ModernMenuButton(
                                        icon: "house.fill",
                                        title: "Accueil",
                                        subtitle: "Page principale",
                                        backgroundColor: .black.opacity(0.7),
                                        foregroundStyle: .white
                                    ) {
                                        onHomeSelected()
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            isMenuExpanded = false
                                        }
                                    }
                                    
                                    // Bouton Toilettes
                                    ModernMenuButton(
                                        icon: "toilet.fill",
                                        title: "Toilettes Publiques",
                                        subtitle: "Trouvez les toilettes les plus proches",
                                        backgroundColor: LinearGradient(
                                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        foregroundStyle: .white
                                    ) {
                                        showToiletsMap = true
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            isMenuExpanded = false
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Onglet du menu (toujours visible) avec style gris transparent
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isMenuExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Menu")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Flèche vers le haut/bas selon l'état
                            Image(systemName: isMenuExpanded ? "chevron.down" : "chevron.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMenuExpanded)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.black.opacity(0.7)) // Style gris transparent comme les autres éléments
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 0) // Espace pour l'home indicator
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuExpanded)
    }
}

// MARK: - Bouton moderne iOS natif
struct ModernMenuButton<Background: ShapeStyle, Foreground: ShapeStyle>: View {
    let icon: String
    let title: String
    let subtitle: String
    let backgroundColor: Background
    let foregroundStyle: Foreground
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icône dans un cercle
                ZStack {
                    Circle()
                        .fill(foregroundStyle.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(foregroundStyle)
                }
                
                // Texte
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(foregroundStyle)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(foregroundStyle.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(foregroundStyle.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Extensions pour supporter différents types de Background
extension ModernMenuButton where Background == Color, Foreground == Color {
    init(
        icon: String,
        title: String,
        subtitle: String,
        backgroundColor: Color,
        foregroundStyle: Color,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.backgroundColor = backgroundColor
        self.foregroundStyle = foregroundStyle
        self.action = action
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        // Background simulé
        LinearGradient(
            gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        FixedBottomMenuView(
            isMenuExpanded: .constant(true),
            showToiletsMap: .constant(false),
            onHomeSelected: {
                print("Home selected")
            }
        )
    }
}
