//
//  WidgetConfigurationIntent.swift
//  EcoLyonWidget
//
//  Intent de configuration pour permettre à l'utilisateur de choisir ses raccourcis.
//  Utilise AppIntents (iOS 17+) pour une configuration native via long press.
//

import AppIntents
import WidgetKit

// MARK: - Widget Configuration Intent

struct EcoLyonWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Lyon"
    static var description = IntentDescription("Personnalisez vos deux raccourcis.")

    // MARK: - Configuration Parameters

    @Parameter(title: "Premier raccourci", default: .toilettes)
    var firstShortcut: ShortcutType

    @Parameter(title: "Deuxième raccourci", default: .fontaines)
    var secondShortcut: ShortcutType

    init() {
        self.firstShortcut = .toilettes
        self.secondShortcut = .fontaines
    }

    init(first: ShortcutType, second: ShortcutType) {
        self.firstShortcut = first
        self.secondShortcut = second
    }
}

// MARK: - Convenience Extensions

extension EcoLyonWidgetConfigurationIntent {
    /// Retourne les 2 raccourcis pour le widget Medium
    var mediumShortcuts: [ShortcutType] {
        [firstShortcut, secondShortcut]
    }
}
