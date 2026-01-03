import SwiftUI
import MapKit
import CoreLocation

// MARK: - Design System

struct AirQualityDesignSystem {
    static let horizontalPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let backgroundColor = Color(red: 248/255, green: 247/255, blue: 244/255)

    // Glass card style
    static let glassBackground = Color.black.opacity(0.7)
    static let glassBorder = Color.white.opacity(0.3)
    static let glassBorderWidth: CGFloat = 1
}

// MARK: - Glass Card Modifier

fileprivate struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AirQualityDesignSystem.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AirQualityDesignSystem.glassBorder, lineWidth: AirQualityDesignSystem.glassBorderWidth)
                    )
            )
    }
}

extension View {
    fileprivate func glassCard(cornerRadius: CGFloat = AirQualityDesignSystem.cardCornerRadius) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Map Background Component

struct MapBackgroundView: View {
    @Binding var cameraPosition: MapCameraPosition
    let showFade: Bool
    let fadeHeight: CGFloat
    let legalBottomPadding: CGFloat

    init(
        cameraPosition: Binding<MapCameraPosition>,
        showFade: Bool = false,
        fadeHeight: CGFloat = 120,
        legalBottomPadding: CGFloat = 0
    ) {
        self._cameraPosition = cameraPosition
        self.showFade = showFade
        self.fadeHeight = fadeHeight
        self.legalBottomPadding = legalBottomPadding
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapScaleView()
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: legalBottomPadding)
                    .allowsHitTesting(false)
            }

            if showFade {
                LinearGradient(
                    colors: [
                        .clear,
                        AirQualityDesignSystem.backgroundColor.opacity(0.5),
                        AirQualityDesignSystem.backgroundColor.opacity(0.85),
                        AirQualityDesignSystem.backgroundColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)
            }
        }
    }
}

// MARK: - Fade Overlay

struct MapFadeOverlay: View {
    let height: CGFloat

    var body: some View {
        LinearGradient(
            colors: [
                .clear,
                AirQualityDesignSystem.backgroundColor.opacity(0.4),
                AirQualityDesignSystem.backgroundColor.opacity(0.75),
                AirQualityDesignSystem.backgroundColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
    }
}

// MARK: - Air Quality Cards Overlay

struct AirQualityCardsOverlay: View {
    @ObservedObject private var locationService = GlobalLocationService.shared
    @Binding var cameraPosition: MapCameraPosition

    @State private var airData: AirQualityData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAtmoReport = false

    // District par défaut : Lyon 2
    private var currentDistrict: District {
        locationService.detectedDistrict ?? Lyon.districts.first { $0.name.contains("2") } ?? Lyon.districts[1]
    }

    var body: some View {
        VStack(spacing: AirQualityDesignSystem.cardSpacing) {
            // Row 1: Bouton rapport (gauche) + Arrondissement (droite)
            topBar

            // Spacer flexible
            Spacer()

            // Row 2: Données qualité d'air
            airQualityDataCard
        }
        .onAppear {
            setupLocation()
        }
        .onDisappear {
            locationService.stopLocationUpdates()
        }
        .onChange(of: locationService.detectedDistrict) { _, _ in
            loadAirQualityData()
            updateMapRegion()
        }
        .sheet(isPresented: $showAtmoReport) {
            AtmoMapView()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AirQualityDesignSystem.cardSpacing) {
            // Gauche: Bouton rapport détaillé
            atmoReportButton

            Spacer()

            // Droite: Affichage arrondissement
            districtDisplayCard
        }
    }

    // MARK: - Atmo Report Button

    private var atmoReportButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAtmoReport = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text("Rapport détaillé")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - District Display Card

    private var districtDisplayCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)

            Text(currentDistrict.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 12)
    }

    // MARK: - Air Quality Data Card

    @ViewBuilder
    private var airQualityDataCard: some View {
        if isLoading {
            loadingState
        } else if let error = errorMessage {
            errorState(message: error)
        } else if let data = airData {
            dataContent(data: data)
        } else {
            errorState(message: "Aucune donnée")
        }
    }

    private var loadingState: some View {
        AirQualitySkeletonView()
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Button("Réessayer") {
                loadAirQualityData()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
    }

    private func dataContent(data: AirQualityData) -> some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.qualificatif)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("Qualité de l'air")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Text("\(data.indice)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Progress bar
            progressBar(indice: data.indice, color: data.couleur_html)

            // Date
            HStack {
                Spacer()
                Text(formatDate(data.date_echeance))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Pollutants
            pollutantsGrid(pollutants: data.sous_indices)
        }
        .padding(16)
        .glassCard()
    }

    private func progressBar(indice: Int, color: String) -> some View {
        HStack(spacing: 2) {
            ForEach(1...6, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(level <= indice ? Color(hex: color) : Color.white.opacity(0.3))
                    .frame(height: 8)
                    .animation(.easeInOut(duration: 0.3).delay(Double(level) * 0.1), value: indice)
            }
        }
    }

    private func pollutantsGrid(pollutants: [Pollutant]) -> some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: pollutants.count <= 4 ? 10 : 5),
            count: pollutants.count <= 4 ? 4 : 5
        )

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(pollutants, id: \.polluant_nom) { pollutant in
                PollutantBubbleView(pollutant: pollutant, district: currentDistrict)
            }
        }
    }

    // MARK: - Data Management

    private func setupLocation() {
        locationService.refreshLocation()
        loadAirQualityData()
        updateMapRegion()
    }

    private func loadAirQualityData() {
        let district = currentDistrict

        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            do {
                let data = try await AirQualityAPIService().fetchAirQuality(for: district.codeInsee)
                await MainActor.run {
                    self.airData = data
                    self.isLoading = false
                }

                NotificationCenter.default.post(
                    name: NSNotification.Name("AQIUpdated"),
                    object: data.indice
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = "Données indisponibles"
                    self.isLoading = false
                }
            }
        }
    }

    private func updateMapRegion() {
        let coordinate = currentDistrict.coordinate
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            ))
        }
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd/MM"
        return outputFormatter.string(from: date)
    }
}

// MARK: - Pollutant Bubble

fileprivate struct PollutantBubbleView: View {
    let pollutant: Pollutant
    let district: District

    @State private var showDetail = false

    private var bubbleColor: Color {
        switch pollutant.indice {
        case 1: return Color(hex: "#50F0E6")
        case 2: return Color(hex: "#50CCAA")
        case 3: return Color(hex: "#F0E641")
        case 4: return Color(hex: "#FF5050")
        case 5: return Color(hex: "#960032")
        case 6: return Color(hex: "#872181")
        default: return Color.gray
        }
    }

    private var shortName: String {
        switch pollutant.polluant_nom.uppercased() {
        case "NO2": return "NO2"
        case "O3": return "O3"
        case "PM10": return "PM10"
        case "PM2.5": return "PM2.5"
        case "SO2": return "SO2"
        default: return String(pollutant.polluant_nom.prefix(3))
        }
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showDetail = true
        } label: {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bubbleColor)
                .frame(width: 54, height: 54)
                .overlay(
                    Text(shortName)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            pollutantDetailView
        }
    }

    @ViewBuilder
    private var pollutantDetailView: some View {
        switch pollutant.polluant_nom.uppercased() {
        case "PM2.5":
            PM25DetailView(pollutant: pollutant, selectedDistrict: district)
        case "PM10":
            PM10DetailView(pollutant: pollutant, selectedDistrict: district)
        case "NO2":
            NO2DetailView(pollutant: pollutant, selectedDistrict: district)
        case "O3":
            O3DetailView(pollutant: pollutant, selectedDistrict: district)
        case "SO2":
            SO2DetailView(pollutant: pollutant, selectedDistrict: district)
        default:
            Text("Détails non disponibles")
                .padding()
        }
    }
}

// MARK: - Skeleton Loading View (Professional iOS Pattern)

struct AirQualitySkeletonView: View {
    @State private var isAnimating = false

    private var shimmerOpacity: Double {
        isAnimating ? 0.4 : 0.2
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header: Qualificatif + Indice
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Qualificatif placeholder (ex: "Bon", "Moyen")
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(shimmerOpacity))
                        .frame(width: 80, height: 20)

                    // "Qualité de l'air" placeholder
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(shimmerOpacity))
                        .frame(width: 100, height: 14)
                }

                Spacer()

                // Indice number placeholder (32pt)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(shimmerOpacity))
                    .frame(width: 44, height: 38)
            }

            // Progress bar (6 segments)
            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(shimmerOpacity))
                        .frame(height: 8)
                }
            }

            // Date placeholder
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(shimmerOpacity))
                    .frame(width: 45, height: 12)
            }

            // Pollutants grid (5 bubbles, 54x54)
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(shimmerOpacity))
                        .frame(width: 54, height: 54)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AirQualityDesignSystem.cardCornerRadius, style: .continuous)
                .fill(AirQualityDesignSystem.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AirQualityDesignSystem.cardCornerRadius, style: .continuous)
                        .stroke(AirQualityDesignSystem.glassBorder, lineWidth: AirQualityDesignSystem.glassBorderWidth)
                )
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentViewTest()
}
