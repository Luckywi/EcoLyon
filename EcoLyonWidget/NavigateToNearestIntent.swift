//
//  NavigateToNearestIntent.swift
//  EcoLyonWidget
//
//  App Intent pour ouvrir l'app sur la page correspondante.
//  Déclenché quand l'utilisateur tape sur un bouton du widget.
//

import AppIntents
import WidgetKit

// MARK: - Navigate To Nearest Intent

struct NavigateToNearestIntent: AppIntent {
    static var title: LocalizedStringResource = "Ouvrir dans EcoLyon"
    static var description: IntentDescription = IntentDescription("Ouvre l'app EcoLyon sur la page correspondante.")

    // Ouvrir l'app quand l'intent est exécuté
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Type de point")
    var shortcutType: ShortcutType

    init() {
        self.shortcutType = .toilettes
    }

    init(shortcutType: ShortcutType) {
        self.shortcutType = shortcutType
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let type = shortcutType
        print("🚀 Widget intent: Ouverture de \(type.displayName)")

        // Stocker le type dans UserDefaults partagé pour que l'app principale puisse le lire
        if let defaults = UserDefaults(suiteName: "group.com.ecolyon.shared") {
            defaults.set(type.rawValue, forKey: "pendingNavigation")
            defaults.set(Date().timeIntervalSince1970, forKey: "pendingNavigationTimestamp")
            print("📝 Navigation pending stockée: \(type.rawValue)")
        }

        return .result()
    }
}
