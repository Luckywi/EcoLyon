//
//  ShortcutType.swift
//  EcoLyonWidget
//
//  Enum définissant les 8 types de raccourcis disponibles dans le widget.
//

import Foundation
import AppIntents
import SwiftUI

// MARK: - ShortcutType AppEnum (Required for Widget Intents)

enum ShortcutType: String, AppEnum, CaseIterable, Codable, Identifiable {
    case toilettes
    case bancs
    case fontaines
    case silos
    case compost
    case poubelles
    case parcs
    case bornes

    var id: String { rawValue }

    // Required for AppEnum
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Type de point")
    }

    static var caseDisplayRepresentations: [ShortcutType: DisplayRepresentation] {
        [
            .toilettes: DisplayRepresentation(title: "Toilettes", image: .init(systemName: "toilet.fill")),
            .bancs: DisplayRepresentation(title: "Bancs", image: .init(systemName: "chair.fill")),
            .fontaines: DisplayRepresentation(title: "Fontaines", image: .init(systemName: "drop.fill")),
            .silos: DisplayRepresentation(title: "Silos verre", image: .init(systemName: "cylinder.fill")),
            .compost: DisplayRepresentation(title: "Compost", image: .init(systemName: "leaf.fill")),
            .poubelles: DisplayRepresentation(title: "Poubelles", image: .init(systemName: "trash.fill")),
            .parcs: DisplayRepresentation(title: "Parcs", image: .init(systemName: "tree.fill")),
            .bornes: DisplayRepresentation(title: "Bornes", image: .init(systemName: "bolt.car.fill"))
        ]
    }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .toilettes: return "Toilettes"
        case .bancs: return "Bancs"
        case .fontaines: return "Fontaines"
        case .silos: return "Silos verre"
        case .compost: return "Compost"
        case .poubelles: return "Poubelles"
        case .parcs: return "Parcs"
        case .bornes: return "Bornes"
        }
    }

    /// Nom affiché dans Apple Maps (plus descriptif)
    var mapDisplayName: String {
        switch self {
        case .toilettes: return "Toilettes publiques"
        case .bancs: return "Banc public"
        case .fontaines: return "Fontaine à eau"
        case .silos: return "Silo à verre"
        case .compost: return "Borne compost"
        case .poubelles: return "Corbeille de rue"
        case .parcs: return "Parc & jardin"
        case .bornes: return "Station Vélo'v"
        }
    }

    var iconName: String {
        switch self {
        case .toilettes: return "Wc"
        case .bancs: return "Banc"
        case .fontaines: return "Fontaine"
        case .silos: return "Silos"
        case .compost: return "Compost"
        case .poubelles: return "Poubelle"
        case .parcs: return "PetJ"
        case .bornes: return "Borne"
        }
    }

    var sfSymbolFallback: String {
        switch self {
        case .toilettes: return "toilet.fill"
        case .bancs: return "chair.fill"
        case .fontaines: return "drop.fill"
        case .silos: return "cylinder.fill"
        case .compost: return "leaf.fill"
        case .poubelles: return "trash.fill"
        case .parcs: return "tree.fill"
        case .bornes: return "bolt.car.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .toilettes: return Color(red: 0.2, green: 0.6, blue: 0.8)
        case .bancs: return Color(red: 0.7, green: 0.5, blue: 0.4)
        case .fontaines: return Color(red: 0.3, green: 0.7, blue: 0.9)
        case .silos: return Color(red: 0.4, green: 0.7, blue: 0.4)
        case .compost: return Color(red: 0.5, green: 0.4, blue: 0.3)
        case .poubelles: return Color(red: 0.6, green: 0.6, blue: 0.6)
        case .parcs: return Color(red: 0.3, green: 0.6, blue: 0.3)
        case .bornes: return Color(red: 0.3, green: 0.5, blue: 0.8)
        }
    }

    // MARK: - API Configuration

    var apiURL: String {
        switch self {
        case .toilettes:
            return "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrtoilettepublique_latest&SRSNAME=EPSG:4171&outputFormat=application/json&startIndex=0&sortby=gid"
        case .bancs:
            return "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrbanc_latest&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
        case .fontaines:
            return "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrbornefontaine_latest&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
        case .silos:
            return "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gic_collecte.siloverre&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
        case .compost:
            return "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gic_collecte.bornecompost&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
        case .poubelles:
            return "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gin_nettoiement.gincorbeille&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
        case .parcs:
            return "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrparcjardin_latest&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
        case .bornes:
            return "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:pvo_patrimoine_voirie.pvostationvelov&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
        }
    }

    var searchRadius: Double {
        switch self {
        case .toilettes: return 1000
        case .bancs: return 800
        case .fontaines: return 1200
        case .silos: return 800
        case .compost: return 800
        case .poubelles: return 500
        case .parcs: return 1500
        case .bornes: return 1000
        }
    }

    /// URL de deep link pour ouvrir l'app sur la bonne page
    var deepLinkURL: URL {
        URL(string: "ecolyon://\(rawValue)")!
    }
}

