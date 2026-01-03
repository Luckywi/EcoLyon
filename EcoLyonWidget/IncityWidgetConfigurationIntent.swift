//
//  IncityWidgetConfigurationIntent.swift
//  EcoLyonWidget
//
//  Intent de configuration pour le widget Incity (small uniquement).
//  Permet de choisir UN seul raccourci.
//

import AppIntents
import WidgetKit

// MARK: - Incity Widget Configuration Intent

struct IncityWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Incity"
    static var description = IntentDescription("Personnalisez votre raccourci.")

    // Un seul raccourci pour le widget small
    @Parameter(title: "Raccourci", default: .toilettes)
    var shortcut: ShortcutType

    init() {
        self.shortcut = .toilettes
    }

    init(shortcut: ShortcutType) {
        self.shortcut = shortcut
    }
}
