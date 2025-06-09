//
//  EcoLyonApp.swift
//  EcoLyon
//
//  Created by Lucky Lebeurre on 09/06/2025.
//

import SwiftUI

@main
struct EcoLyonApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
