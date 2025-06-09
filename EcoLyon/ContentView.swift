import SwiftUI

struct ContentView: View {
    @State private var showToiletsMap = false
    
    var body: some View {
        ZStack {
            // Fond blanc
            Color.white
                .ignoresSafeArea()
            
            // Bouton centré
            VStack {
                Spacer()
                
                Button(action: {
                    showToiletsMap = true
                }) {
                    Text("Carte des Toilettes Publiques")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                }
                
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showToiletsMap) {
            ToiletsMapView()
        }
    }
}

#Preview {
    ContentView()
}
