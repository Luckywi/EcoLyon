import SwiftUI

struct CompostGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Couleur principale unifiée pour le compost
    private let compostColor = Color(red: 0x8C/255.0, green: 0xC1/255.0, blue: 0xCB/255.0)
    private let darkBackground = Color.black.opacity(0.7)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header avec illustration
                    headerSection
                    
                    // Section compacte Avant/Aujourd'hui
                    compactBeforeAfterSection
                    
                    // Que mettre dans les bornes
                    whatToCompostBornesSection
                    
                    // Section fusionnée : Comment utiliser + Cycle
                    howToUseBornesAndCycleSection
                    
                    // Card de remerciement
                    thankYouSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            .navigationTitle("Guide des Bornes à Compost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(compostColor)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Titre principal centré
            Text("Triez tous vos déchets alimentaires")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Badge avec nombre de bornes avec styles différents
            HStack(spacing: 0) {
                Text("+ 2 700")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text(" bornes à compost à ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Lyon")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(compostColor)
            )
            
            // Logo Métropole et compost côte à côte
            HStack(spacing: 30) {
                // Logo Métropole de Lyon
                Image("LogoMetropole")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                
                // Illustration du composteur
                Image("Compost")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Compact Before/After Section - Style moderne
    private var compactBeforeAfterSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Titre de section
            Text("Une révolution pour vos déchets")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Card "Aujourd'hui" - mise en valeur
                BeforeAfterCard(
                    icon: "leaf.fill",
                    title: "Aujourd'hui",
                    subtitle: "Valorisation et compost",
                    description: "Moins d'odeurs, moins de nuisibles, moins de poubelles à sortir... Trier ses déchets alimentaires, c'est plus propre et plus simple au quotidien.",
                    isHighlighted: true
                )
                
                // Card "Avant"
                BeforeAfterCard(
                    icon: "trash.fill",
                    title: "Avant",
                    subtitle: "Gaspillage et incinération",
                    description: "24% des poubelles grises sont des déchets alimentaires qui finissent incinérés, polluant l'environnement inutilement.",
                    isHighlighted: false
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - What to Compost Bornes Section - Modern Design
    private var whatToCompostBornesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Titre de section
            Text("Tous les déchets alimentaires sont acceptés !")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // Scroll horizontal des catégories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(foodWasteCategories, id: \.id) { category in
                        ModernFoodWasteCard(category: category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .padding(.horizontal, -20) // Compensate container padding
            
            // Note importante redesignée
            ModernImportantNote()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - How to Use Bornes & Cycle Section (fusionnée)
    private var howToUseBornesAndCycleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Du dépôt à la valorisation")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                AccordionStepCard(
                    step: "1",
                    title: "Préparez votre geste éco-citoyen",
                    description: "À la maison, jetez tous vos déchets alimentaires dans un contenant dédié (bio-seau ou récipient réutilisé). Épluchures, restes de repas, produits périmés non emballés… tout peut y aller. Un petit geste simple, mais essentiel pour démarrer la boucle du compostage !",
                    color: compostColor
                )
                
                AccordionStepCard(
                    step: "2",
                    title: "Déposez-les près de chez vous",
                    description: "Rendez-vous à la borne à compost la plus proche de chez vous. Déposez vos déchets alimentaires en vrac ou dans un sac en papier. Attention : pas de plastique, même biodégradable ! Ces bornes sont accessibles 24h/24, pour un tri facile au quotidien.",
                    color: compostColor
                )
                
                AccordionStepCard(
                    step: "3",
                    title: "Collecte et transformation",
                    description: "Les déchets sont collectés régulièrement et transportés vers des plateformes de compostage locales comme Les Alchimistes à Vénissieux, OuiCompost à Lyon ou Racine à Ternay. Là, ils sont soigneusement mélangés à des déchets verts, puis compostés pendant plusieurs semaines dans des conditions contrôlées.",
                    color: compostColor
                )
                
                AccordionStepCard(
                    step: "4",
                    title: "Retour à la terre",
                    description: "Après maturation, un compost 100 % naturel est obtenu. Il est utilisé par des agriculteurs locaux et des jardiniers pour nourrir les sols et faire pousser de nouvelles cultures. Grâce à votre tri, les déchets redeviennent une ressource précieuse pour la planète.",
                    color: compostColor
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: compostColor.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Thank You Section
    private var thankYouSection: some View {
        VStack(spacing: 16) {
            Text("Merci ! 🎉")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // Texte uniforme sans couleurs spéciales
            Text("En 2024, grâce à votre mobilisation, la Métropole de Lyon a récupéré 12 500 tonnes de déchets alimentaires et les a transformées en 9 000 tonnes de compost naturel.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 29) 
            
            
            Button(action: {
                if let url = URL(string: "https://www.grandlyon.com/mes-services-au-quotidien/gerer-ses-dechets/utiliser-une-borne-a-compost/vos-questions-sur-les-bornes-a-compost/") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Plus d'informations sur les bornes à compost")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(compostColor)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
    }
    
    // Extension pour les données
    private var foodWasteCategories: [FoodWasteCategoryModel] {
        [
            FoodWasteCategoryModel(
                title: "Préparations de repas",
                emoji: "🧑‍🍳",
                description: "Épluchures, coquilles d'œufs, trognons de fruits…",
                color: compostColor
            ),
            FoodWasteCategoryModel(
                title: "Restes de repas",
                emoji: "🍖",
                description: "Restes cuits, arêtes, os, épluchures…",
                color: compostColor
            ),
            FoodWasteCategoryModel(
                title: "Produits alimentaires périmés",
                emoji: "🧀",
                description: "Aliments moisis ou expirés sans emballage",
                color: compostColor
            ),
            FoodWasteCategoryModel(
                title: "Thé & café",
                emoji: "☕️",
                description: "Marc de café, filtres, sachets de thé…",
                color: compostColor
            )
        ]
    }
}

// MARK: - Data Model pour les catégories
struct FoodWasteCategoryModel: Identifiable {
    let id = UUID()
    let title: String
    let emoji: String
    let description: String
    let color: Color
}

// MARK: - Supporting Views

// MARK: - Supporting View pour Before/After
struct BeforeAfterCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let isHighlighted: Bool
    
    // Couleur principale unifiée pour le compost
    private let compostColor = Color(red: 0x8C/255.0, green: 0xC1/255.0, blue: 0xCB/255.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header avec icône et titre
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isHighlighted ? compostColor : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isHighlighted ? compostColor : .secondary)
                }
            }
            
            // Description
            Text(description)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? compostColor.opacity(0.05) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighlighted ? compostColor.opacity(0.2) : .clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Modern Food Waste Card
struct ModernFoodWasteCard: View {
    let category: FoodWasteCategoryModel
    
    // Couleur principale unifiée pour le compost
    private let compostColor = Color(red: 0x8C/255.0, green: 0xC1/255.0, blue: 0xCB/255.0)
    
    var body: some View {
        VStack(spacing: 16) {
            // Gros emoji simple
            Text(category.emoji)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
            
            // Contenu textuel
            VStack(spacing: 8) {
                Text(category.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(category.description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 160, height: 180)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(compostColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(compostColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Modern Important Note
struct ModernImportantNote: View {
    var body: some View {
        VStack(spacing: 8) {
            ImportantRule(
                icon: "xmark.circle.fill",
                text: "Pas de sac plastique (même compostable)"
            )
            
            ImportantRule(
                icon: "xmark.circle.fill",
                text: "Pas d'emballage"
            )
            
            ImportantRule(
                icon: "checkmark.circle.fill",
                text: "Uniquement les déchets alimentaires en vrac",
                isPositive: true
            )
        }
    }
}

// MARK: - Accordion Step Card
struct AccordionStepCard: View {
    let step: String
    let title: String
    let description: String
    let color: Color
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header cliquable
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Numéro dans un cercle
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                        
                        Text(step)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Titre
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Icône de flèche
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(color)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Contenu déroulant
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Important Rule Component
struct ImportantRule: View {
    let icon: String
    let text: String
    let isPositive: Bool
    private let compostColor = Color(red: 0x8C/255.0, green: 0xC1/255.0, blue: 0xCB/255.0)
    
    init(icon: String, text: String, isPositive: Bool = false) {
        self.icon = icon
        self.text = text
        self.isPositive = isPositive
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isPositive ? compostColor : .red)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isPositive ? compostColor : .red)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    CompostGuideView()
}
