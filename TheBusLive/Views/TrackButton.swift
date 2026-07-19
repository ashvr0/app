import SwiftUI

struct TrackButton: View {
    let arrival: Arrival
    let stop: Stop
    @StateObject private var manager = LiveActivityManager.shared

    @State private var isTracking = false

    var body: some View {
        if arrival.estimated && !arrival.isCanceled {
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
        }
    }
}