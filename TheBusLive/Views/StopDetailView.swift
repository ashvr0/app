import SwiftUI

struct StopDetailView: View {

    let stop: Stop

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @StateObject private var viewModel: StopViewModel

    init(stop: Stop) {
        self.stop = stop
        _viewModel = StateObject(wrappedValue: StopViewModel(stop: stop))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                StatusView(kind: .loading)
            case .empty:
                StatusView(kind: .empty(
                    title: "No arrivals right now",
                    message: "There are no buses currently scheduled or predicted for this stop.",
                    systemImage: "clock"
                ))
            case .failed(let message):
                StatusView(kind: .error(message: message, retry: {
                    Task { await viewModel.loadArrivals() }
                }))
            case .loaded:
                List(viewModel.arrivals) { arrival in
                    NavigationLink(value: arrival) {
                        ArrivalRow(arrival: arrival)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.loadArrivals()
                }
            }
        }
        .navigationTitle(stop.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Arrival.self) { arrival in
            if let vehicleNumber = arrival.vehicle, !vehicleNumber.isEmpty {
                MapView(vehicleNumber: vehicleNumber)
            } else {
                StatusView(kind: .empty(
                    title: "No vehicle assigned",
                    message: "This arrival doesn't have a vehicle number to track yet.",
                    systemImage: "location.slash"
                ))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesManager.toggleFavorite(stop)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(stop) ? "star.fill" : "star")
                        .foregroundStyle(favoritesManager.isFavorite(stop) ? .yellow : .primary)
                }
                .modifier(GlassButtonModifier())
            }
        }
        .task {
            favoritesManager.recordRecent(stop)
            await viewModel.loadArrivals()
        }
    }
}

#Preview {
    NavigationStack {
        StopDetailView(stop: Stop.sampleStops[0])
            .environmentObject(FavoritesManager())
    }
}