
import SwiftUI

// Vue racine qui gère le loading screen
struct RootView: View {
    @State private var showLoadingScreen = true
    
    var body: some View {
        ZStack {
            if showLoadingScreen {
                AppLoadingView {
                    showLoadingScreen = false
                }
                .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showLoadingScreen)
    }
}

@main
struct EcoLyonApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView() // Changé de ContentView() à RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.light)
        }
    }
}
