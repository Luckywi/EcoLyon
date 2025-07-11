import SwiftUI
import Combine

// MARK: - Main View Controller
struct LyonFactsView: View {
    @StateObject private var viewModel = LyonFactsViewModel()
    @StateObject private var preloader = LyonFactsPreloader.shared // ✅ AJOUT
    @State private var currentDragOffset: CGFloat = 0
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @Environment(\.dismiss) private var dismiss
    
    private let dragThreshold: CGFloat = 100
    
    var body: some View {
        // Conteneur principal avec ZStack pour superposer les couches
        ZStack {
            // Arrière-plan noir
            Color.black
                .ignoresSafeArea(.all)
            
            // Images au premier plan
            if viewModel.isLoading && viewModel.facts.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            } else if !viewModel.facts.isEmpty {
                ZStack {
                    ForEach(Array(viewModel.facts.enumerated()), id: \.element.id) { index, fact in
                        if shouldShowPhoto(at: index) {
                            CachedPhotoView(imageUrl: fact.imageUrl)
                                .offset(y: calculateOffset(for: index))
                                .opacity(calculateOpacity(for: index))
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            currentDragOffset = value.translation.height
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                if value.translation.height < -dragThreshold {
                                    viewModel.moveToNext()
                                } else if value.translation.height > dragThreshold {
                                    viewModel.moveToPrevious()
                                }
                                currentDragOffset = 0
                            }
                        }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                // Interface utilisateur FIXE - positionnée par rapport au Rectangle principal
                VStack(spacing: 0) {
                    // Zone des boutons en haut
                    HStack {
                        // Bouton retour - Style simple comme la maquette
                        Button(action: {
                            print("DISMISS PRESSED")
                            // ✅ MODIFICATION: Déclencher le refresh du preloader
                            preloader.refreshFacts()
                            viewModel.currentIndex = 0
                            currentDragOffset = 0
                            dismiss()
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .overlay(
                                            Circle()
                                                .fill(Color.black.opacity(0.3))
                                        )
                                )
                        }
                        
                        Spacer()
                        
                        // Bouton partage - Style simple comme la maquette
                        Button(action: {
                            print("SHARE PRESSED")
                            shareCurrentFact()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .overlay(
                                            Circle()
                                                .fill(Color.black.opacity(0.3))
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60) // Safe area manuelle
                    
                    Spacer()
                    
                    // Zone de contenu textuel en bas
                    if !viewModel.facts.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            // Titre principal
                            Text(viewModel.facts[viewModel.currentIndex].title)
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Description
                            Text(viewModel.facts[viewModel.currentIndex].description)
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .lineSpacing(2)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 80)
                        .padding(.all, 3)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            // ✅ NOUVEAU: Background similaire aux boutons
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.3))
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.black.opacity(0.6))
                                )
                        )
                        
                    }
                }
                .allowsHitTesting(true)
            )
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
            .onAppear {
                // ✅ AJOUT: Utiliser le preloader si disponible
                if let preloadedFacts = preloader.getPreloadedFacts() {
                    print("🚀 Utilisation des facts préchargés!")
                    viewModel.usePreloadedFacts(preloadedFacts)
                } else {
                    print("⏳ Préchargement non prêt, chargement classique...")
                    viewModel.loadFacts()
                }
            }
            .statusBarHidden(true)
    }
    
    // MARK: - Helper Methods
    private func shouldShowPhoto(at index: Int) -> Bool {
        abs(index - viewModel.currentIndex) <= 1
    }
    
    private func calculateOffset(for index: Int) -> CGFloat {
        let baseOffset = CGFloat(index - viewModel.currentIndex) * UIScreen.main.bounds.height
        return baseOffset + currentDragOffset
    }
    
    private func calculateOpacity(for index: Int) -> Double {
        index == viewModel.currentIndex ? 1.0 : 0.5
    }
    
    private func shareCurrentFact() {
        guard !viewModel.facts.isEmpty else { return }
        let currentFact = viewModel.facts[viewModel.currentIndex]
        
        // Créer le texte avec le préfixe personnalisé
        let shareText = "J'ai appris ce fait intéressant sur la ville de Lyon grâce à l'application EcoLyon :\n\n\(currentFact.title)\n\n\(currentFact.description)"
        
        // Vérifier si l'image est déjà en cache
        if let cachedImage = PhotoCache.shared.get(forKey: currentFact.imageUrl) {
            // Image disponible immédiatement
            shareItems = [shareText, cachedImage]
            showingShareSheet = true
        } else {
            // Télécharger l'image avant de partager
            downloadImageForSharing(url: currentFact.imageUrl, text: shareText)
        }
    }
    
    private func downloadImageForSharing(url: String, text: String) {
        guard let imageUrl = URL(string: url) else {
            // Si l'image n'est pas disponible, partager seulement le texte
            shareItems = [text]
            showingShareSheet = true
            return
        }
        
        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    // Sauvegarder en cache pour la prochaine fois
                    PhotoCache.shared.set(image, forKey: url)
                    
                    // Partager avec l'image
                    shareItems = [text, image]
                    showingShareSheet = true
                } else {
                    // En cas d'erreur, partager seulement le texte
                    shareItems = [text]
                    showingShareSheet = true
                }
            }
        }.resume()
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Personnaliser le message pour différents types de partage
        controller.setValue("Fait intéressant sur Lyon", forKey: "subject")
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Pas de mise à jour nécessaire
    }
}

// MARK: - Cached Photo View
struct CachedPhotoView: View {
    let imageUrl: String
    @StateObject private var imageLoader: PhotoLoader
    
    init(imageUrl: String) {
        self.imageUrl = imageUrl
        self._imageLoader = StateObject(wrappedValue: PhotoLoader(url: imageUrl))
    }
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: UIScreen.main.bounds.width,
                        height: UIScreen.main.bounds.height
                    )
                    .clipped()
                    .ignoresSafeArea(.all) // ✅ Ignore TOUTES les safe areas
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(
                        width: UIScreen.main.bounds.width,
                        height: UIScreen.main.bounds.height
                    )
                    .ignoresSafeArea(.all) // ✅ Placeholder aussi
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    )
            }
        }
    }
}

// MARK: - Photo Loader
class PhotoLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private var cancellable: AnyCancellable?
    private let url: String
    
    init(url: String) {
        self.url = url
        loadImage()
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    private func loadImage() {
        if let cachedImage = PhotoCache.shared.get(forKey: url) {
            self.image = cachedImage
            return
        }
        
        guard let url = URL(string: url) else { return }
        
        isLoading = true
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] downloadedImage in
                guard let self = self else { return }
                self.isLoading = false
                if let downloadedImage = downloadedImage {
                    self.image = downloadedImage
                    PhotoCache.shared.set(downloadedImage, forKey: self.url)
                }
            }
        }
}

// MARK: - Photo Cache
class PhotoCache {
    static let shared = PhotoCache()
    private init() {
        setupCache()
    }
    
    private let cache = NSCache<NSString, UIImage>()
    
    private func setupCache() {
        cache.countLimit = 10
        cache.totalCostLimit = 100 * 1024 * 1024
    }
    
    func set(_ image: UIImage, forKey key: String) {
        let cost = estimateImageCost(image)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    private func estimateImageCost(_ image: UIImage) -> Int {
        let pixelCount = Int(image.size.width * image.size.height)
        return pixelCount * 4
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - View Model
class LyonFactsViewModel: ObservableObject {
    @Published var facts: [LyonFact] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellable: AnyCancellable?
    
    init() {
        // ✅ MODIFICATION: Ne plus charger automatiquement dans l'init
        // loadFacts() <- SUPPRIMÉ pour éviter le double chargement
    }
    
    // ✅ AJOUT: Méthode pour utiliser les facts préchargés
    func usePreloadedFacts(_ preloadedFacts: [LyonFact]) {
        self.facts = preloadedFacts
        self.currentIndex = 0
        self.isLoading = false
        self.error = nil
        print("✅ Facts préchargés utilisés: \(preloadedFacts.count) éléments")
    }
    
    func loadFacts() {
        guard !isLoading else { return }
        isLoading = true
        
        let url = URL(string: "https://lyon-facts.vercel.app/api/facts?shuffle=true")!
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: LyonFactsResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] response in
                    self?.facts = response.facts
                }
            )
    }
    
    func moveToNext() {
        if currentIndex < facts.count - 1 {
            currentIndex += 1
        }
    }
    
    func moveToPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
}

// MARK: - Models
struct LyonFact: Codable, Identifiable {
    let id: Int
    let category: String
    let title: String
    let description: String
    let imageUrl: String
}

struct LyonFactsResponse: Codable {
    let facts: [LyonFact]
    let meta: Meta
    
    struct Meta: Codable {
        let total: Int
        let imageFormat: String
        let averageImageSize: String
        let totalDataSize: String
        let optimized: Bool
        let timestamp: Int
        let version: String
    }
}

// MARK: - Preview
#Preview {
    LyonFactsView()
}
