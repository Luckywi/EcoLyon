import SwiftUI

struct DistrictSelector: View {
    @State private var selectedDistrict = "Lyon 6"
    @State private var isExpanded = false
    
    // Liste des arrondissements
    private let districts = [
        "Lyon 1", "Lyon 2", "Lyon 3", "Lyon 4", "Lyon 5",
        "Lyon 6", "Lyon 7", "Lyon 8", "Lyon 9", "Villeurbanne"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Bouton principal
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(selectedDistrict)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            
            // Liste déroulante
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(districts, id: \.self) { district in
                        Button(action: {
                            selectedDistrict = district
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded = false
                            }
                            // TODO: Ici sera ajouté l'appel API
                        }) {
                            HStack {
                                Text(district)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if district == selectedDistrict {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                district == selectedDistrict
                                ? Color.blue.opacity(0.1)
                                : Color.white
                            )
                        }
                        
                        if district != districts.last {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                .offset(y: -8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .zIndex(100) // S'assure que le sélecteur s'affiche au-dessus
    }
}

#Preview {
    VStack {
        DistrictSelector()
            .padding()
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
