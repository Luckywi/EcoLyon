import SwiftUI
import Combine

// MARK: - Lyon Facts Preloader Service
class LyonFactsPreloader: ObservableObject {
    static let shared = LyonFactsPreloader()
    
    @Published var facts: [LyonFact] = []
    @Published var isReady = false
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellable: AnyCancellable?
    private var imageCancellables: Set<AnyCancellable> = []
    
    private init() {
        // Démarre automatiquement le préchargement au lancement
        startPreloading()
    }
    
    deinit {
        cancellable?.cancel()
        imageCancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Public Methods
    
    /// Démarre le préchargement des facts et images
    func startPreloading() {
        guard !isLoading else { return }
        
        print("🔄 LyonFactsPreloader: Démarrage du préchargement...")
        loadFacts()
    }
    
    /// Recharge de nouveaux facts (appelé après fermeture de la vue)
    func refreshFacts() {
        print("🔄 LyonFactsPreloader: Refresh des facts...")
        
        // Vider le cache actuel
        facts.removeAll()
        isReady = false
        PhotoCache.shared.clearCache()
        
        // Recharger de nouveaux facts
        loadFacts()
    }
    
    /// Vérifie si les facts sont prêts à être utilisés
    func getPreloadedFacts() -> [LyonFact]? {
        return isReady ? facts : nil
    }
    
    // MARK: - Private Methods
    
    private func loadFacts() {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
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
                        print("❌ LyonFactsPreloader: Erreur lors du chargement - \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    // ✅ MODIFICATION: Garder TOUS les facts mais précharger que les 6 premiers
                    self?.facts = response.facts // Tous les facts
                    self?.preloadImages()
                    print("✅ LyonFactsPreloader: \(response.facts.count) facts chargés, préchargement des 6 premiers")
                }
            )
    }
    
    private func preloadImages() {
        guard !facts.isEmpty else { return }
        
        print("🖼️ LyonFactsPreloader: Préchargement des 6 premières images...")
        
        // Vider les anciens cancellables
        imageCancellables.forEach { $0.cancel() }
        imageCancellables.removeAll()
        
        let group = DispatchGroup()
        var successCount = 0
        
        // ✅ MODIFICATION: Précharger seulement les 6 premières images
        let factsToPreload = Array(facts.prefix(6))
        
        for fact in factsToPreload {
            // Vérifier si l'image est déjà en cache
            if PhotoCache.shared.get(forKey: fact.imageUrl) != nil {
                successCount += 1
                continue
            }
            
            // Précharger l'image
            guard let url = URL(string: fact.imageUrl) else { continue }
            
            group.enter()
            
            let cancellable = URLSession.shared.dataTaskPublisher(for: url)
                .map { UIImage(data: $0.data) }
                .replaceError(with: nil)
                .receive(on: DispatchQueue.main)
                .sink { downloadedImage in
                    defer { group.leave() }

                    if let image = downloadedImage {
                        PhotoCache.shared.set(image, forKey: fact.imageUrl)
                        successCount += 1
                        print("✅ Image préchargée: \(fact.title)")
                    } else {
                        print("❌ Échec préchargement image: \(fact.title)")
                    }
                }
            
            imageCancellables.insert(cancellable)
        }
        
        // Attendre que toutes les images soient chargées
        group.notify(queue: .main) { [weak self] in
            self?.isReady = true
            print("🎉 LyonFactsPreloader: Préchargement terminé - \(successCount)/6 images sur \(self?.facts.count ?? 0) facts totaux")
        }
    }
}

// MARK: - Extension pour LyonFactsResponse (si pas déjà définie)
extension LyonFactsResponse {
    // Cette extension sera vide si la struct est déjà définie dans LyonFactsView
}
