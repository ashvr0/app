import SwiftUI

struct FavoritesView: View {

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @State private var moveCount = 0

    var body: some View {
        NavigationStack {
            if favoritesManager.favorites.isEmpty {
                StatusView(kind: .empty(
                    title: "No favorite stops",
                    message: "Tap the star on any stop to save it here for quick access.",
                    systemImage: "star"
                ))
            } else {
                List {
                    Section("Favorite stops") {
                        ForEach(favoritesManager.favorites) { stop in
                            NavigationLink(value: stop) {
                                StopRow(stop: stop)
                            }
                        }
                        .onDelete { offsets in
                            favoritesManager.removeFavorite(at: offsets)
                        }
                        .onMove { source, destination in
                            favoritesManager.moveFavorite(from: source, to: destination)
                            moveCount += 1
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .sensoryFeedback(.impact(weight: .heavy), trigger: moveCount)
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: Stop.self) { stop in
                StopDetailView(stop: stop)
            }
            .toolbar {
                if !favoritesManager.favorites.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(FavoritesManager())
}
