import SwiftUI

struct StopDetailView: View {

    let stop: Stop

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @StateObject private var viewModel: StopViewModel

    init(stop: Stop) {
        self.stop = stop
        _viewModel = StateObject(wrappedValue: StopViewModel(stop: stop))
    }

    /// Shows the stop number by default ("Stop 169"), switching to a
    /// "Last refresh: h:mm a" line once arrivals have loaded at least
    /// once. Uses the device's current locale so the time renders in
    /// whatever 12h/24h format the user's system is set to, rather than
    /// a hardcoded format.
    private var refreshSubtitle: String {
        guard let lastRefreshed = viewModel.lastRefreshed else {
            return "Stop \(stop.stopID)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return "Last refresh: \(formatter.string(from: lastRefreshed))"
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    MarqueeText(text: stop.name, font: .headline)
                        .frame(width: 220)
                    Text(refreshSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // Note: toggleFavorite itself fires a success/warning
                // haptic, so no separate tap haptic is added here to
                // avoid a double-buzz.
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