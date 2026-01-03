
//
//  Persistence.swift
//  EcoLyon
//
//  Created by Lucky Lebeurre on 09/06/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Gestion d'erreur propre pour les previews
            let nsError = error as NSError
            print("❌ Erreur de sauvegarde dans preview: \(nsError.localizedDescription)")
            // En cas d'erreur dans preview, on continue sans sauvegarder
            viewContext.rollback()
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "EcoLyon")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Gestion d'erreur robuste au lieu de fatalError()
                print("❌ Erreur Core Data: \(error.localizedDescription)")
                print("📋 Détails: \(error.userInfo)")
                print("⚠️ L'app continuera de fonctionner avec un stockage limité")
                
                // Log des erreurs courantes pour le débogage
                switch error.code {
                case NSPersistentStoreIncompatibleVersionHashError:
                    print("💡 Suggestion: Mise à jour du modèle de données requise")
                case NSMigrationMissingSourceModelError:
                    print("💡 Suggestion: Migration de données requise")
                default:
                    print("💡 Erreur générale de stockage")
                }
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
