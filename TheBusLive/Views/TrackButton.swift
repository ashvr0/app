import SwiftUI

/// A "Track" button shown on each live estimated arrival row.
/// Tapping it starts a Live Activity for that arrival so the countdown
/// appears on the Dynamic Island and lock screen.
///
/// Add this inside `ArrivalRow` or place it as a swipe action on the row.
struct TrackButton: View {
    let arrival: Arrival
    let stop: Stop
    @StateObject private var manager = LiveActivityManager.shared

    @State private var isTracking = false

    var body: some View {
        // Only show for live estimated arrivals — scheduled ones
        // have no vehicle position and won't update meaningfully.
        guard arrival.estimated && !arrival.isCanceled else {
            return AnyView(EmptyView())
        }

        return AnyView(
            Button {
                if isTracking {
                    Task { await LiveActivityManager.shared.end() }
                    isTracking = false
                } else {
                    LiveActivityManager.shared.start(
                        stopName: stop.name,
                        stopID: stop.stopID,
                        routeNumber: arrival.route,
                        headsign: arrival.headsign,
                        isExpress: RouteCategory.isExpress(routeNum: arrival.route),
                        arrival: arrival
                    )
                    isTracking = true
                    HapticsManager.shared.success()
                }
            } label: {
                Label(
                    isTracking ? "Stop tracking" : "Track",
                    systemImage: isTracking ? "dot.radiowaves.left.and.right" : "record.circle"
                )
            }
            .tint(isTracking ? .red : .green)
        )
    }
}
