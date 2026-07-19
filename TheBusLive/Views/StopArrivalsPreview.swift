import SwiftUI

/// A small first-tap popover shown for a stop pin on the vehicle
/// tracking map: just the stop name and its soonest arrival estimate.
/// Tapping this preview expands to the full `StopDetailView` (favorite
/// star, stop number, last refresh, complete arrivals list) via
/// `onSelect`, so the map gives a quick glance before committing to the
/// full screen.
struct StopArrivalsPreview: View {
    let stop: Stop
    let onSelect: () -> Void

    @StateObject private var viewModel: StopViewModel

    init(stop: Stop, onSelect: @escaping () -> Void) {
        self.stop = stop
        self.onSelect = onSelect
        _viewModel = StateObject(wrappedValue: StopViewModel(stop: stop))
    }

    private var soonestArrival: Arrival? {
        viewModel.arrivals.first
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                Text(stop.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .empty:
                    Text("No arrivals right now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .failed:
                    Text("Couldn't load arrivals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .loaded:
                    if let soonestArrival {
                        HStack(spacing: 4) {
                            Text("Bus \(soonestArrival.route)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(arrivalSummary(for: soonestArrival))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Tap for full details")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(width: 220, alignment: .leading)
        }
        .buttonStyle(.plain)
        .task {
            await viewModel.loadArrivals()
        }
    }

    private func arrivalSummary(for arrival: Arrival) -> String {
        guard let date = arrival.arrivalDate else { return arrival.stopTime }
        let minutes = Int(date.timeIntervalSinceNow / 60)
        if minutes <= 0 { return "Arriving now" }
        return "\(minutes) min"
    }
}

#Preview {
    StopArrivalsPreview(stop: Stop.sampleStops[0], onSelect: {})
}