import Foundation
import Combine

/// Persists favorite and recently-viewed stops locally via UserDefaults.
/// The storage keys below only matter if you need to match existing on-device data exactly.
///
/// Thread Safety: Marked @MainActor to ensure all state mutations happen on the main thread.
/// File I/O operations use a dedicated dispatch queue to prevent blocking the main thread.
@MainActor
final class FavoritesManager: ObservableObject {

    @Published private(set) var favorites: [Stop] = []
    @Published private(set) var recents: [Stop] = []

    private let favoritesKey = "com.thebuslive.favorites"
    private let recentsKey = "com.thebuslive.recents"
    private let maxRecents = 20

    private let defaults: UserDefaults
    
    /// Use a dedicated queue for file I/O to prevent blocking main thread
    /// and to serialize access to UserDefaults
    private let persistenceQueue = DispatchQueue(
        label: "com.thebuslive.favorites.persistence",
        qos: .userInitiated
    )

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isFavorite(_ stop: Stop) -> Bool {
        favorites.contains(stop)
    }

    func toggleFavorite(_ stop: Stop) {
        if let index = favorites.firstIndex(of: stop) {
            favorites.remove(at: index)
            HapticsManager.shared.warning()
        } else {
            favorites.append(stop)
            HapticsManager.shared.success()
        }
        let favoritesToSave = favorites
        persistenceQueue.async { [weak self] in
            self?.saveFavoritesSync(favoritesToSave)
        }
    }

    func removeFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        let favoritesToSave = favorites
        persistenceQueue.async { [weak self] in
            self?.saveFavoritesSync(favoritesToSave)
        }
        
        HapticsManager.shared.warning()
    }

    /// Reorders favorites in place, used to back drag-to-reorder in
    /// `FavoritesView`. `IndexSet`/`Int` signature matches
    /// `ForEach.onMove` directly.
    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)

        let favoritesToSave = favorites
        persistenceQueue.async { [weak self] in
            self?.saveFavoritesSync(favoritesToSave)
        }
    }

    func recordRecent(_ stop: Stop) {
        // Remove existing entry if present (to avoid duplicates)
        recents.removeAll { $0 == stop }
        // Insert at front
        recents.insert(stop, at: 0)
        // Trim to max size
        if recents.count > maxRecents {
            recents.removeLast(recents.count - maxRecents)
        }
        let recentsToSave = recents
        persistenceQueue.async { [weak self] in
            self?.saveRecentsSync(recentsToSave)
        }
    }

    func clearRecents() {
        recents = []
        persistenceQueue.async { [weak self] in
            self?.saveRecentsSync([])
        }
    }

    // MARK: - Private persistence methods
    private func load() {
        favorites = decode(key: favoritesKey)
        recents = decode(key: recentsKey)
    }

    private func decode(key: String) -> [Stop] {
        guard let data = defaults.data(forKey: key) else { return [] }
        
        do {
            return try JSONDecoder().decode([Stop].self, from: data)
        } catch {
            NSLog("Error decoding \(key): \(error)")
            return []
        }
    }

    /// FIX: Synchronous save method to be called on the persistence queue
    private func saveFavoritesSync(_ stops: [Stop]) {
        guard let data = try? JSONEncoder().encode(stops) else {
            NSLog("Error encoding favorites")
            return
        }
        defaults.set(data, forKey: favoritesKey)
        // Ensure the write is synced to disk
        defaults.synchronize()
    }
    
    /// Synchronous save method to be called on the persistence queue
    private func saveRecentsSync(_ stops: [Stop]) {
        guard let data = try? JSONEncoder().encode(stops) else {
            NSLog("Error encoding recents")
            return
        }
        defaults.set(data, forKey: recentsKey)
        // Ensure the write is synced to disk
        defaults.synchronize()
    }
}
