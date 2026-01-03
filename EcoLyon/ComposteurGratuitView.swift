import SwiftUI

struct ComposteurGratuitView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Couleur principale unifiée
    private let primaryGreen = Color(red: 0x7B/255.0, green: 0xAC/255.0, blue: 0x5D/255.0)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header avec illustration
                    headerSection
                    
                    // Section principale d'information
                    mainInfoSection
                    
                    // Avantages du compostage
                    avantagesSection
                    
                    // Formation
                    formationSection
                    
                    // Conditions d'éligibilité
                    eligibilitySection
                    
                    // Bouton d'action principal
                    actionButton
                    
                    // Informations complémentaires
                    complementaryInfo
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color(red: 248/255, green: 247/255, blue: 244/255))
            .navigationTitle("Composteur gratuit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(primaryGreen)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Titre principal centré
            Text("La Métropole de Lyon vous offre un composteur !")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            // Badge #objectifZéroDéchet centré avec styles différents
            HStack(spacing: 0) {
                Text("#objectif")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Zéro")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white)
                
                Text("Déchet")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(primaryGreen)
            )
            
            // Logo Métropole et composteur côte à côte
            HStack(spacing: 30) {
                // Logo Métropole de Lyon
                Image("LogoMetropole")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                
                // Illustration du composteur
                Image("CompostGratuit")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Main Info Section
    private var mainInfoSection: some View {
        VStack(spacing: 20) {
            // Titre avec icône
            HStack {
                Text("Pourquoi ?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Contenu principal avec mise en valeur des chiffres
            VStack(alignment: .leading, spacing: 16) {
                // Première partie - objectif 50%
                HStack(alignment: .top, spacing: 12) {
                    VStack {
                        Text("50%")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(primaryGreen)
                    }
                    .frame(width: 60)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("La Métropole de Lyon à pour objectif de réduire de")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        + Text(" 50% les déchets incinérés ")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(primaryGreen)
                        + Text("d'ici 2026.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                
                // Séparateur visuel
                Divider()
                    .background(primaryGreen.opacity(0.3))
                
                // Deuxième partie - impact personnel 30%
                HStack(alignment: .top, spacing: 12) {
                    VStack {
                        Text("30%")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(primaryGreen)
                    }
                    .frame(width: 60)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("En compostant, vous pouvez déjà réduire de")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        + Text(" 30% le contenu ")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(primaryGreen)
                        + Text("de votre bac gris.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(primaryGreen.opacity(0.1), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Avantages Section
    private var avantagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Avantages du compostage")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                AvantageRow(
                    emoji: "🌱",
                    title: "Engrais naturel",
                    subtitle: "Transformez vos déchets en fertilisant gratuit et sans produits chimiques"
                )
                
                AvantageRow(
                    emoji: "🗑",
                    title: "Moins de déchets",
                    subtitle: "Réduisez jusqu'à 1/3 le volume de votre poubelle"
                )
                
                AvantageRow(
                    emoji: "🌍",
                    title: "Sols et planète préservés",
                    subtitle: "Améliore la qualité des sols et réduit l'impact environnemental"
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
    
    // MARK: - Eligibility Section
    private var eligibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Qui peut en bénéficier ?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                EligibilityCard(
                    icon: "house.fill",
                    title: "Particuliers",
                    conditions: [
                        "Maison individuelle",
                        "Appartement avec rez-de-jardin",
                        "Accès à un jardin ou à la terre"
                    ]
                )
                
                EligibilityCard(
                    icon: "building.2.fill",
                    title: "Établissements",
                    conditions: [
                        "Structures publiques ou privées",
                        "Projet pédagogique en place",
                        "Pas encore bénéficiaire du dispositif"
                    ]
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
    
    // MARK: - Formation Section
    private var formationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Débutant ? On vous forme !")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("🎓")
                    .font(.system(size: 32))
            }
            
            Text("Ateliers de sensibilisation au compostage et au jardinage avec vos résidus végétaux.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(nil)
            
            Button(action: {
                if let url = URL(string: "https://www.grandlyon.com/mes-services-au-quotidien/gerer-ses-dechets/sinscrire-a-un-atelier-ou-une-formation-sur-le-compostage") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Text("En savoir plus sur les formations")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(primaryGreen)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: {
            // Action pour rediriger vers le site de demande
            if let url = URL(string: "https://demarches.toodego.com/gestion-des-dechets/demander-la-distribution-d-un-composteur-individuel/") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Faire ma demande en ligne")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [primaryGreen, primaryGreen.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Complementary Info
    private var complementaryInfo: some View {
        VStack(spacing: 16) {
            Text("En attendant votre composteur ⏳️")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Préparez-vous grâce à toutes les informations disponibles sur [grandlyon.com/compostage](https://grandlyon.com/compostage)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                if let url = URL(string: "https://grandlyon.com/compostage") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Consulter le guide complet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryGreen)
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Supporting Views

struct AvantageRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct EligibilityCard: View {
    let icon: String
    let title: String
    let conditions: [String]
    
    // Couleur principale unifiée
    private let primaryGreen = Color(red: 0x7B/255.0, green: 0xAC/255.0, blue: 0x5D/255.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(primaryGreen)
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(conditions, id: \.self) { condition in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(primaryGreen)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        
                        Text(condition)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(primaryGreen.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(primaryGreen.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    ComposteurGratuitView()
}
