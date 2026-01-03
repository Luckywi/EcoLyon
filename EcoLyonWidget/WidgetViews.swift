//
//  WidgetViews.swift
//  EcoLyonWidget
//
//  Vues pour les widgets Medium et Large.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Glass Material Modifier (Style verre avec Material SwiftUI)

struct GlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    let isDark: Bool

    init(cornerRadius: CGFloat = 12, isDark: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isDark = isDark
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isDark ? .ultraThinMaterial : .regularMaterial)
            )
    }
}

struct GlassCapsule: ViewModifier {
    let isDark: Bool

    init(isDark: Bool = false) {
        self.isDark = isDark
    }

    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(isDark ? .ultraThinMaterial : .regularMaterial)
            )
    }
}

extension View {
    func adaptiveGlassBackground(cornerRadius: CGFloat = 12, isDark: Bool = false) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, isDark: isDark))
    }

    func adaptiveGlassCapsule(isDark: Bool = false) -> some View {
        modifier(GlassCapsule(isDark: isDark))
    }
}

// MARK: - Widget Entry

struct EcoLyonWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: EcoLyonWidgetConfigurationIntent
    let weatherData: WidgetWeatherData?
    let backgroundImageName: String

    init(
        date: Date,
        configuration: EcoLyonWidgetConfigurationIntent,
        weatherData: WidgetWeatherData? = nil,
        backgroundImageName: String = "A_autumn_day"
    ) {
        self.date = date
        self.configuration = configuration
        self.weatherData = weatherData
        self.backgroundImageName = backgroundImageName
    }
}

// MARK: - Weather Symbol Helper

/// Convertit un symbole météo en version .fill pour supporter le multicolor
private func weatherSymbolWithFill(_ symbol: String) -> String {
    // Si le symbole a déjà .fill, le retourner tel quel
    if symbol.hasSuffix(".fill") {
        return symbol
    }
    // Ajouter .fill pour les symboles météo (supportent le multicolor)
    return symbol + ".fill"
}

// MARK: - Weather Display View (Style Apple Maps)

struct WeatherDisplayView: View {
    let weatherData: WidgetWeatherData?

    var body: some View {
        HStack(spacing: 8) {
            // Météo: Icône + Température
            HStack(spacing: 4) {
                Image(systemName: weatherSymbolWithFill(weatherData?.conditionSymbol ?? "cloud.sun.fill"))
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.multicolor)

                Text(weatherData?.formattedTemperature ?? "--°")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Séparateur si on a l'AQI
            if weatherData?.airQualityIndex != nil {
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 1, height: 14)
            }

            // Qualité de l'air (si disponible)
            if let aqi = weatherData?.airQualityIndex {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: weatherData?.airQualityColor ?? "#808080"))
                        .frame(width: 10, height: 10)

                    Text("AQI \(aqi)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .adaptiveGlassCapsule()
    }
}

// Extension Color pour hex (nécessaire pour le widget)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Medium Widget View (2 boutons)

struct MediumWidgetView: View {
    let entry: EcoLyonWidgetEntry

    private var shortcuts: [ShortcutType] {
        entry.configuration.mediumShortcuts
    }

    var body: some View {
        VStack {
            // Météo en haut à droite
            HStack {
                Spacer()
                WeatherDisplayView(weatherData: entry.weatherData)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()

            HStack {
                // Boutons en bas à gauche
                HStack(spacing: 8) {
                    ForEach(shortcuts, id: \.self) { shortcut in
                        ShortcutButtonView(
                            shortcut: shortcut,
                            size: .medium
                        )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Shortcut Button View

struct ShortcutButtonView: View {
    let shortcut: ShortcutType
    let size: WidgetButtonSize

    enum WidgetButtonSize {
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .medium: return 36
            case .large: return 32
            }
        }
    }

    var body: some View {
        Link(destination: shortcut.deepLinkURL) {
            Image(shortcut.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.iconSize, height: size.iconSize)
                .padding(8)
                .adaptiveGlassBackground(cornerRadius: 12)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MediumWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        MediumWidgetView(
            entry: EcoLyonWidgetEntry(
                date: Date(),
                configuration: EcoLyonWidgetConfigurationIntent(
                    first: .toilettes,
                    second: .bancs
                ),
                weatherData: .placeholder,
                backgroundImageName: "A_autumn_golden"
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

#endif
