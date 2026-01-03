//
//  MapDataConfigurations.swift
//  EcoLyon
//
//  Configurations spécifiques pour chaque type de données de carte.
//

import Foundation
import CoreLocation

// MARK: - Protocol Conformances

extension BancLocation: MapLocationProtocol {}
extension FontaineLocation: MapLocationProtocol {}
extension SilosLocation: MapLocationProtocol {}
extension CompostLocation: MapLocationProtocol {}
extension PoubelleLocation: MapLocationProtocol {}
extension ToiletLocation: MapLocationProtocol {}

// MARK: - Bancs Configuration

struct BancsConfiguration: MapDataConfiguration {
    typealias LocationType = BancLocation
    typealias PropertiesType = BancProperties

    let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrbanc_latest&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
    let searchRadius: Double = 800
    let maxItemsToShow: Int = 50

    func parseLocation(coordinates: [Double], properties: BancProperties) -> BancLocation? {
        let longitude = coordinates[0]
        let latitude = coordinates[1]

        return BancLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            name: properties.nom ?? "Banc public",
            address: formatAddress(properties),
            gestionnaire: properties.gestionnaire ?? "Non spécifié",
            isAccessible: properties.acces_pmr == "Oui",
            hasShadow: properties.ombrage == "Oui",
            materiau: properties.materiau
        )
    }

    private func formatAddress(_ props: BancProperties) -> String {
        var parts: [String] = []
        if let adresse = props.adresse { parts.append(adresse) }
        if let codePostal = props.code_postal { parts.append(codePostal) }
        if let commune = props.commune { parts.append(commune) }
        return parts.isEmpty ? "Adresse non disponible" : parts.joined(separator: ", ")
    }
}

// MARK: - Fontaines Configuration

struct FontainesConfiguration: MapDataConfiguration {
    typealias LocationType = FontaineLocation
    typealias PropertiesType = FontainesProperties

    let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrbornefontaine_latest&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
    let searchRadius: Double = 1200
    let maxItemsToShow: Int = 50

    func parseLocation(coordinates: [Double], properties: FontainesProperties) -> FontaineLocation? {
        let longitude = coordinates[0]
        let latitude = coordinates[1]

        return FontaineLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            name: properties.nom ?? "Fontaine publique",
            address: formatAddress(properties),
            gestionnaire: properties.gestionnaire ?? "Non spécifié",
            isAccessible: properties.acces_pmr == "Oui" || properties.acces_pmr == "oui",
            type: properties.type_fontaine ?? "",
            commune: properties.commune ?? ""
        )
    }

    private func formatAddress(_ props: FontainesProperties) -> String {
        var parts: [String] = []
        if let adresse = props.adresse { parts.append(adresse) }
        if let codePostal = props.code_postal { parts.append(codePostal) }
        if let commune = props.commune { parts.append(commune) }
        return parts.isEmpty ? "Adresse non disponible" : parts.joined(separator: ", ")
    }
}

// MARK: - Silos Configuration

struct SilosConfiguration: MapDataConfiguration {
    typealias LocationType = SilosLocation
    typealias PropertiesType = SilosProperties

    let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gic_collecte.siloverre&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
    let searchRadius: Double = 800
    let maxItemsToShow: Int = 50

    func parseLocation(coordinates: [Double], properties: SilosProperties) -> SilosLocation? {
        let longitude = coordinates[0]
        let latitude = coordinates[1]

        return SilosLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            name: properties.nom ?? "Silo à verre",
            address: formatAddress(properties),
            gestionnaire: properties.gestionnaire ?? "Non spécifié",
            isAccessible: properties.acces_pmr == "Oui" || properties.acces_pmr == "oui",
            type: properties.type_silo ?? "",
            capacite: properties.capacite,
            commune: properties.commune ?? ""
        )
    }

    private func formatAddress(_ props: SilosProperties) -> String {
        var parts: [String] = []
        if let adresse = props.adresse { parts.append(adresse) }
        if let codePostal = props.code_postal { parts.append(codePostal) }
        if let commune = props.commune { parts.append(commune) }
        return parts.isEmpty ? "Adresse non disponible" : parts.joined(separator: ", ")
    }
}

// MARK: - Compost Configuration

struct CompostConfiguration: MapDataConfiguration {
    typealias LocationType = CompostLocation
    typealias PropertiesType = CompostProperties

    let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gic_collecte.bornecompost&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
    let searchRadius: Double = 800
    let maxItemsToShow: Int = 50

    func parseLocation(coordinates: [Double], properties: CompostProperties) -> CompostLocation? {
        let longitude = coordinates[0]
        let latitude = coordinates[1]

        return CompostLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            identifiant: properties.identifiant ?? "Non spécifié",
            address: formatAddress(properties),
            commune: properties.commune ?? "Non spécifiée",
            gestionnaire: properties.gestionnaire ?? "Non spécifié",
            collecteur: properties.collecteur ?? "Non spécifié",
            numeroCircuit: properties.numerocircuit ?? "",
            observationLocalisante: properties.observation_localisante ?? "",
            dateDebutExploitation: properties.datedebutexploitation ?? "",
            insee: properties.insee ?? ""
        )
    }

    private func formatAddress(_ props: CompostProperties) -> String {
        var parts: [String] = []
        if let adresse = props.adresse { parts.append(adresse) }
        if let commune = props.commune { parts.append(commune) }
        return parts.isEmpty ? "Adresse non disponible" : parts.joined(separator: ", ")
    }
}

// MARK: - Poubelle Configuration

struct PoubelleConfiguration: MapDataConfiguration {
    typealias LocationType = PoubelleLocation
    typealias PropertiesType = PoubelleProperties

    let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:gin_nettoiement.gincorbeille&outputFormat=application/json&SRSNAME=EPSG:4171&startIndex=0&sortby=gid"
    let searchRadius: Double = 500
    let maxItemsToShow: Int = 50

    func parseLocation(coordinates: [Double], properties: PoubelleProperties) -> PoubelleLocation? {
        let longitude = coordinates[0]
        let latitude = coordinates[1]

        return PoubelleLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            name: properties.nom ?? "Corbeille",
            address: formatAddress(properties),
            gestionnaire: properties.gestionnaire ?? "Non spécifié",
            isAccessible: properties.acces_pmr == "Oui" || properties.acces_pmr == "oui",
            type: properties.support ?? properties.type_corbeille ?? "",
            capacite: properties.capacite,
            commune: properties.commune ?? ""
        )
    }

    private func formatAddress(_ props: PoubelleProperties) -> String {
        var parts: [String] = []
        // Utiliser voie + numerodansvoie de l'ancienne API, ou adresse si disponible
        if let voie = props.voie {
            if let numero = props.numerodansvoie, !numero.isEmpty {
                parts.append("\(numero) \(voie)")
            } else {
                parts.append(voie)
            }
        } else if let adresse = props.adresse {
            parts.append(adresse)
        }
        if let codePostal = props.code_postal { parts.append(codePostal) }
        if let commune = props.commune { parts.append(commune) }
        return parts.isEmpty ? "Adresse non disponible" : parts.joined(separator: ", ")
    }
}

// MARK: - Toilets Configuration

struct ToiletsConfiguration: MapDataConfiguration {
    typealias LocationType = ToiletLocation
    typealias PropertiesType = ToiletProperties

    let apiURL = "https://data.grandlyon.com/geoserver/metropole-de-lyon/ows?SERVICE=WFS&VERSION=2.0.0&request=GetFeature&typename=metropole-de-lyon:adr_voie_lieu.adrtoilettepublique_latest&SRSNAME=EPSG:4171&outputFormat=application/json&startIndex=0&sortby=gid"
    let searchRadius: Double = 1000
    let maxItemsToShow: Int = 50

    func parseLocation(coordinates: [Double], properties: ToiletProperties) -> ToiletLocation? {
        let longitude = coordinates[0]
        let latitude = coordinates[1]

        return ToiletLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            name: properties.nom ?? "Toilette publique",
            address: formatAddress(properties),
            gestionnaire: properties.gestionnaire ?? "Non spécifié",
            isAccessible: properties.acces_pmr == "Oui",
            isOpen: determineOpenStatus(properties),
            horaires: properties.horaires
        )
    }

    private func formatAddress(_ props: ToiletProperties) -> String {
        var parts: [String] = []
        if let adresse = props.adresse { parts.append(adresse) }
        if let codePostal = props.code_postal { parts.append(codePostal) }
        if let commune = props.commune { parts.append(commune) }
        return parts.isEmpty ? "Adresse non disponible" : parts.joined(separator: ", ")
    }

    private func determineOpenStatus(_ props: ToiletProperties) -> Bool {
        // Si pas d'horaires spécifiés, on considère ouvert
        guard let horaires = props.horaires?.lowercased() else { return true }

        // Fermé si explicitement fermé
        if horaires.contains("fermé") || horaires.contains("ferme") {
            return false
        }

        return true
    }
}

// MARK: - Type Aliases for Services

typealias BancsService = MapDataService<BancsConfiguration>
typealias FontainesService = MapDataService<FontainesConfiguration>
typealias SilosService = MapDataService<SilosConfiguration>
typealias CompostService = MapDataService<CompostConfiguration>
typealias PoubelleService = MapDataService<PoubelleConfiguration>
typealias ToiletsService = MapDataService<ToiletsConfiguration>

// MARK: - Convenience Factory Methods

extension MapDataService {
    static func bancs() -> BancsService {
        BancsService(configuration: BancsConfiguration())
    }

    static func fontaines() -> FontainesService {
        FontainesService(configuration: FontainesConfiguration())
    }

    static func silos() -> SilosService {
        SilosService(configuration: SilosConfiguration())
    }

    static func compost() -> CompostService {
        CompostService(configuration: CompostConfiguration())
    }

    static func poubelles() -> PoubelleService {
        PoubelleService(configuration: PoubelleConfiguration())
    }

    static func toilets() -> ToiletsService {
        ToiletsService(configuration: ToiletsConfiguration())
    }
}
