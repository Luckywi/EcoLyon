import SwiftUI

struct EnvironmentCardView: View {
    @StateObject private var navigationManager = NavigationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête de la section
            HStack {
                Text("Environnement")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Carte principale avec les boutons
            VStack(spacing: 20) {
                // Section Composteurs - Navigation via NavigationManager
                EnvironmentButtonView(
                    icon: "Compost",
                    title: "Cartes des composteurs",
                    subtitle: "Trouvez le plus proche de chez vous",
                    accentColor: .green,
                    isCustomIcon: true,
                    action: {
                        navigationManager.navigateToCompost()
                    }
                )
                
                // Section Collecte - Navigation via NavigationManager
                EnvironmentButtonView(
                    icon: "Silos",
                    title: "Recyclage du verre",
                    subtitle: "2 780 silos répartis dans la métropole",
                    accentColor: .orange,
                    isCustomIcon: true,
                    action: {
                        navigationManager.navigateToSilos()
                    }
                )
                
                EnvironmentButtonView(
                    icon: "CompostGratuit",
                    title: "Composteur gratuit",
                    subtitle: "La métropole de Lyon vous offre un composteur",
                    accentColor: .orange,
                    isCustomIcon: true,
                    action: {
                        navigationManager.navigateToComposteurGratuit()
                    }
                )
                
                // NOUVEAU: Guide des bornes à compost
                EnvironmentButtonView(
                    icon: "Guide",
                    title: "Guide des bornes à compost",
                    subtitle: "Tout savoir sur le compostage collectif",
                    accentColor: Color(red: 0x8C/255.0, green: 0xC1/255.0, blue: 0xCB/255.0), // CompostColor
                    isCustomIcon: true,
                    action: {
                        navigationManager.navigateToCompostGuide()
                    }
                )
                
                // Section Statistiques
                EnvironmentButtonView(
                    icon: "Lyon",
                    title: "Lyon en transition",
                    subtitle: "Découvrez 70 faits sur la métropole",
                    accentColor: .teal,
                    isCustomIcon: true,
                    action: {
                        navigationManager.navigateToLyonFacts()
                    }
                )
                
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Composant de bouton individuel
struct EnvironmentButtonView: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let isCustomIcon: Bool // Nouveau paramètre
    let action: () -> Void
    
    @State private var isPressed = false
    
    // Initializer avec paramètre par défaut
    init(icon: String, title: String, subtitle: String, accentColor: Color, isCustomIcon: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.isCustomIcon = isCustomIcon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icône dans un cercle coloré
                ZStack {
                    // Choix entre icône SF Symbols ou icône custom
                    if isCustomIcon {
                        Image(icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 55, height: 55)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }
                
                // Contenu textuel
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        // Background similaire à votre app
        Color(red: 248/255, green: 247/255, blue: 244/255)
            .ignoresSafeArea()
        
        EnvironmentCardView()
    }
}
