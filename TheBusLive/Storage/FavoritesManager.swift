import Foundation
import Combine

/// Persists favorite and recently-viewed stops locally via UserDefaults.
/// the storage keysw below only matter if you need to match existing on-device data exactly.
@MainActor
final class FavoritesManager: ObservableObject {

    @Published private(set) var favorites: [Stop] = []
    @Published private(set) var recents: [Stop] = []

    private let favoritesKey = "com.thebuslive.favorites"
    private let recentsKey = "com.thebuslive.recents"
    private let maxRecents = 20

    private let defaults: UserDefaults

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
        save(favorites, key: favoritesKey)
    }

    func removeFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        save(favorites, key: favoritesKey)
        HapticsManager.shared.warning()
    }

    /// Reorders favorites in place, used to back drag-to-reorder in
    /// `FavoritesView`. `IndexSet`/`Int` signature matches
    /// `ForEach.onMove` directly.
    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        save(favorites, key: favoritesKey)
    }

    func recordRecent(_ stop: Stop) {
        recents.removeAll { $0 == stop }
        recents.insert(stop, at: 0)
        if recents.count > maxRecents {
            recents.removeLast(recents.count - maxRecents)
        }
        save(recents, key: recentsKey)
    }

    func clearRecents() {
        recents = []
        save(recents, key: recentsKey)
    }

    private func load() {
        favorites = decode(key: favoritesKey)
        recents = decode(key: recentsKey)
    }

    private func decode(key: String) -> [Stop] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Stop].self, from: data)) ?? []
    }

    private func save(_ stops: [Stop], key: String) {
        guard let data = try? JSONEncoder().encode(stops) else { return }
        defaults.set(data, forKey: key)
    }
}