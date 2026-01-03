import SwiftUI
import MapKit

// MARK: - Glass Material Modifiers

struct GlassBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
            )
    }
}

struct GlassCapsuleModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
            )
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius))
    }

    func glassCapsule() -> some View {
        modifier(GlassCapsuleModifier())
    }

    func isometric3D(angle: Double = 45, intensity: Double = 0.3) -> some View {
        self
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.5
            )
            .shadow(color: .black.opacity(intensity), radius: 4, x: 2, y: 4)
    }
}

// MARK: - Island State Enum

enum IslandState {
    case collapsed
    case expanded
    case keyboard

    static let animation: Animation = .spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0)
}

// MARK: - Compass View

struct CompassView: View {
    let heading: Double
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)

            VStack(spacing: 2) {
                Capsule()
                    .fill(Color.red)
                    .frame(width: 3, height: 12)

                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3, height: 12)
            }
            .rotationEffect(.degrees(-heading))
        }
    }
}

// MARK: - Map Header Island

struct MapHeaderIsland: View {
    let title: String
    let imageName: String
    var iconSize: CGFloat = 28
    let themeColor: Color
    let description: String
    let dataSource: String
    let dataSourceURL: String
    let onBackTapped: () -> Void

    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top) {
            // Bouton retour
            Button(action: onBackTapped) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
            }

            Spacer()

            // Îlot titre + icône
            VStack(alignment: .trailing, spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 10) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)

                        // Séparateur vertical
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 1, height: 20)

                        // Icône info iOS native
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 14)
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("À propos")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 6) {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)

                                Text(dataSource)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)

                            if let url = URL(string: dataSourceURL) {
                                Link(destination: url) {
                                    HStack(spacing: 4) {
                                        Text("data.grandlyon.com")
                                            .font(.system(size: 12, weight: .medium))
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                    }
                    .frame(width: 260)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }
}

// MARK: - Map Control Buttons (Météo + Boussole + Localisation)

struct MapControlButtons: View {
    let themeColor: Color
    let mapHeading: Double
    let isMapCenteredOnUser: Bool
    let weatherData: WeatherDisplayData
    let onWeatherTapped: () -> Void
    let onCompassTapped: () -> Void
    let onLocationTapped: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            // Widget météo + qualité d'air
            Button(action: onWeatherTapped) {
                VStack(alignment: .center, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: weatherData.conditionSymbol)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .symbolRenderingMode(.multicolor)

                        Text(weatherData.formattedTemperature)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 4) {
                        Text("Air")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Circle()
                            .fill(weatherData.airQualityColor)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: 52, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
            }

            // Boussole custom
            Button(action: onCompassTapped) {
                CompassView(heading: mapHeading)
                    .frame(width: 52, height: 44)
            }
            .buttonStyle(.plain)

            // Bouton localisation
            Button(action: onLocationTapped) {
                Image(systemName: isMapCenteredOnUser ? "location.fill" : "location")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 52, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
            }
        }
        .padding(.trailing, 12)
    }
}

// MARK: - Weather Display Data Protocol

struct WeatherDisplayData {
    let conditionSymbol: String
    let formattedTemperature: String
    let airQualityColor: Color

    init(conditionSymbol: String = "cloud", formattedTemperature: String = "--°", airQualityColor: Color = .gray) {
        self.conditionSymbol = conditionSymbol
        self.formattedTemperature = formattedTemperature
        self.airQualityColor = airQualityColor
    }
}

// MARK: - Map Shortcut Button

struct MapShortcutButton: View {
    let imageName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 66, height: 66)

                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Map Shortcut Item

struct MapShortcutItem: Identifiable {
    let id = UUID()
    let imageName: String
    let label: String
    let destination: Destination
}

// MARK: - Map Shortcuts Section

struct MapShortcutsSection: View {
    let currentDestination: Destination

    private var shortcuts: [MapShortcutItem] {
        let all: [MapShortcutItem] = [
            MapShortcutItem(imageName: "Fontaine", label: "Fontaines", destination: .fontaines),
            MapShortcutItem(imageName: "Wc", label: "Toilettes", destination: .toilets),
            MapShortcutItem(imageName: "Banc", label: "Bancs", destination: .bancs),
            MapShortcutItem(imageName: "Poubelle", label: "Poubelles", destination: .poubelle),
            MapShortcutItem(imageName: "Silos", label: "Silos", destination: .silos),
            MapShortcutItem(imageName: "Borne", label: "Bornes", destination: .bornes),
            MapShortcutItem(imageName: "PetJ", label: "Parcs", destination: .parcs),
            MapShortcutItem(imageName: "Compost", label: "Compost", destination: .compost),
            MapShortcutItem(imageName: "Rando", label: "Randos", destination: .randos)
        ]
        return all.filter { $0.destination != currentDestination }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Explorer aussi")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(shortcuts) { shortcut in
                        MapShortcutButton(imageName: shortcut.imageName, label: shortcut.label) {
                            NavigationManager.shared.navigate(to: shortcut.destination)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 40)
    }
}

// MARK: - Modern Marker View

struct ModernMarkerView: View {
    let imageName: String
    var size: CGFloat = 40
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        }) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .isometric3D(angle: 20, intensity: 0.4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
    }
}

// MARK: - Generic Item Row for Search Results

struct MapItemRow<Item>: View where Item: MapDisplayable {
    let item: Item
    let referenceLocation: CLLocationCoordinate2D?
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 14) {
                Image(item.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let refLoc = referenceLocation {
                        Text("\(formatDistance(from: refLoc, to: item.coordinate)) · \(item.subtitle)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func formatDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let meters = fromLoc.distance(from: toLoc)

        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
}

// MARK: - Map Displayable Protocol

protocol MapDisplayable: Identifiable {
    var coordinate: CLLocationCoordinate2D { get }
    var displayName: String { get }
    var subtitle: String { get }
    var imageName: String { get }
}

// MARK: - Address Suggestion Row

struct AddressSuggestionRow: View {
    let suggestion: AddressSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red.opacity(0.8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(suggestion.subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State View

struct MapEmptyStateView: View {
    let imageName: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: imageName)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Loading State View

struct MapLoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Helper pour ouvrir la navigation

func openDirectionsTo(coordinate: CLLocationCoordinate2D, name: String) {
    let placemark = MKPlacemark(coordinate: coordinate)
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.name = name
    mapItem.openInMaps(launchOptions: [
        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
    ])
}

// MARK: - Helper pour formater les distances

func formatDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
    let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
    let meters = fromLoc.distance(from: toLoc)

    if meters < 1000 {
        return "\(Int(meters)) m"
    } else {
        return String(format: "%.1f km", meters / 1000)
    }
}

// MARK: - CLLocationCoordinate2D Distance Extension

extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - Map Loading Overlay

struct MapLoadingOverlay: View {
    let imageName: String
    let title: String
    let themeColor: Color
    var hasError: Bool = false

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            if hasError {
                // État erreur : Card fixe avec bordure
                VStack(spacing: 16) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                        .opacity(0.5)
                        .saturation(0.3)

                    Text("Connexion impossible")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
                )
            } else {
                // État chargement : Halo flou + animation
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 280, height: 280)
                    .blur(radius: 50)

                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 90)
                    .scaleEffect(isAnimating ? 1.08 : 0.92)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasError)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            isAnimating = true
        }
        .onChange(of: hasError) { _, error in
            if error {
                isAnimating = false
            }
        }
    }
}
