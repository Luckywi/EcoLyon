import SwiftUI
import CoreLocation

struct NO2DetailView: View {
    let pollutant: Pollutant
    let selectedDistrict: District
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // En-tête avec localisation et statut
                    headerSection
                    
                    // Curseur d'échelle avec données API
                    qualityScaleSection
                    
                    // Concentration actuelle
                    concentrationSection
                    
                    // Informations détaillées
                    detailSections
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("Détail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Polluant NO2")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
            
            VStack(spacing: 12) {
                Text("Aujourd'hui à :")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                
                Text(selectedDistrict.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                
                // Pastille de statut
                HStack(spacing: 8) {
                    Circle()
                        .fill(getQualityColor(from: pollutant.indice))
                        .frame(width: 12, height: 12)
                    
                    Text(getQualityText(from: pollutant.indice))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }
    
    // MARK: - Quality Scale Section
    private var qualityScaleSection: some View {
        VStack(spacing: 16) {
            Text("Indice de qualité NO2")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            // Curseur horizontal identique à la vue principale
            VStack(spacing: 12) {
                HStack(spacing: 2) {
                    ForEach(1...6, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(level <= pollutant.indice ? getScaleColor(level: level) : Color.gray.opacity(0.3))
                            .frame(height: 12)
                            .animation(.easeInOut(duration: 0.3).delay(Double(level) * 0.1), value: pollutant.indice)
                    }
                }
                
                // Labels des niveaux
                HStack {
                    Text("1")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("6")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // Niveau actuel
                HStack {
                    Text("Niveau actuel: \(pollutant.indice)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text(getQualityText(from: pollutant.indice))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(getQualityColor(from: pollutant.indice))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }
    
    // MARK: - Concentration Section
    private var concentrationSection: some View {
        VStack(spacing: 12) {
            Text("Concentration actuelle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f µg/m³", pollutant.concentration))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Dioxyde d'azote NO2 mesuré")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Indicateur visuel de niveau
                Circle()
                    .fill(getQualityColor(from: pollutant.indice))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text("\(pollutant.indice)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }
    
    // MARK: - Detail Sections
    private var detailSections: some View {
        VStack(spacing: 20) {
            // Qu'est-ce que c'est ?
            detailCard(
                title: "Qu'est-ce que c'est ?",
                content: "Le dioxyde d'azote (NO2) est un gaz irritant de couleur brun-rouge émis principalement par les véhicules et les installations de combustion. Il fait partie de la famille des oxydes d'azote (NOx)."
            )
            
            // Les pics
            detailCard(
                title: "Les pics",
                content: "Les concentrations les plus élevées s'observent pendant les heures de pointe du trafic routier (7h-9h et 17h-19h), particulièrement en hiver quand les conditions de dispersion sont moins favorables."
            )
            
            // Les effets sur la santé
            detailCard(
                title: "Les effets sur la santé",
                content: "Le NO2 est un gaz irritant qui pénètre dans les voies respiratoires profondes. Il peut provoquer une hyperréactivité bronchique chez les asthmatiques, une altération de la fonction pulmonaire et un accroissement de la sensibilité aux infections respiratoires, notamment chez les enfants."
            )
            
            // Les sources
            detailCard(
                title: "Les sources principales",
                content: """
                • Transport routier (70% des émissions urbaines)
                • Véhicules diesel (émissions plus importantes)
                • Installations de combustion (chauffage, industrie)
                • Centrales thermiques
                • Navigation fluviale et maritime
                • Précurseur de l'ozone (réactions photochimiques)
                """
            )
        }
    }
    
    // MARK: - Helper Views
    private func detailCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Text(content)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black.opacity(0.8))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Helper Functions
    private func getQualityColor(from indice: Int) -> Color {
        switch indice {
        case 1: return Color(hex: "#50F0E6")
        case 2: return Color(hex: "#50CCAA")
        case 3: return Color(hex: "#F0E641")
        case 4: return Color(hex: "#FF5050")
        case 5: return Color(hex: "#960032")
        case 6: return Color(hex: "#872181")
        default: return Color.gray
        }
    }
    
    private func getScaleColor(level: Int) -> Color {
        switch level {
        case 1: return Color(hex: "#50F0E6")
        case 2: return Color(hex: "#50CCAA")
        case 3: return Color(hex: "#F0E641")
        case 4: return Color(hex: "#FF5050")
        case 5: return Color(hex: "#960032")
        case 6: return Color(hex: "#872181")
        default: return Color.gray
        }
    }
    
    private func getQualityText(from indice: Int) -> String {
        switch indice {
        case 1: return "Très bon"
        case 2: return "Bon"
        case 3: return "Moyen"
        case 4: return "Mauvais"
        case 5: return "Très mauvais"
        case 6: return "Extrêmement mauvais"
        default: return "Inconnu"
        }
    }
}

// L'extension Color(hex:) existe déjà dans votre projet principal

#Preview {
    NO2DetailView(
        pollutant: Pollutant(
            polluant_nom: "NO2",
            concentration: 42.5,
            indice: 3
        ),
        selectedDistrict: District(
            id: "69386",
            name: "Lyon 6e",
            codeInsee: "69386",
            coordinate: CLLocationCoordinate2D(latitude: 45.7692, longitude: 4.8502)
        )
    )
}
