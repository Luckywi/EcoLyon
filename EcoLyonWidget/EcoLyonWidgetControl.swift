//
//  EcoLyonWidgetControl.swift
//  EcoLyonWidget
//
//  Control Widget pour iOS 18+ (Control Center)
//  Note: Ce fichier ne sera actif que sur iOS 18 ou plus récent.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Control Widget (iOS 18+)

@available(iOS 18.0, *)
struct EcoLyonWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.EcoLyon.app.EcoLyon.EcoLyonControl",
            provider: ControlProvider()
        ) { value in
            ControlWidgetToggle(
                "EcoLyon",
                isOn: value,
                action: OpenEcoLyonIntent()
            ) { isOn in
                Label(isOn ? "Actif" : "Inactif", systemImage: "leaf.fill")
            }
        }
        .displayName("EcoLyon")
        .description("Accès rapide à EcoLyon")
    }
}

@available(iOS 18.0, *)
extension EcoLyonWidgetControl {
    struct ControlProvider: ControlValueProvider {
        var previewValue: Bool {
            false
        }

        func currentValue() async throws -> Bool {
            return false
        }
    }
}

@available(iOS 18.0, *)
struct OpenEcoLyonIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Ouvrir EcoLyon"

    @Parameter(title: "Actif")
    var value: Bool

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
