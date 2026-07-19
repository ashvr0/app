import ActivityKit
import Foundation

/// The static data for a bus arrival Live Activity — things that don't
/// change once the activity is started (stop name, route number, headsign).
struct BusArrivalAttributes: ActivityAttributes {

    /// Dynamic state updated on every refresh.
    struct ContentState: Codable, Hashable {
        /// Minutes until the next arrival. nil = no data yet.
        let minutesAway: Int?
        /// Raw arrival time string from TheBus (e.g. "3:45 PM"), shown
        /// when minutesAway isn't available.
        let stopTime: String
        /// Whether this is a live GPS estimate or a schedule prediction.
        let isLive: Bool
        /// Whether the arrival has been cancelled.
        let isCancelled: Bool
        /// The next arrival after this one, if any — shown as secondary info.
        let nextStopTime: String?
        /// When this state was last updated, shown as "Updated X min ago".
        let lastUpdated: Date

        static var placeholder: ContentState {
            ContentState(
                minutesAway: 4,
                stopTime: "3:45 PM",
                isLive: true,
                isCancelled: false,
                nextStopTime: "4:02 PM",
                lastUpdated: Date()
            )
        }
    }

    let stopName: String
    let stopID: String
    let routeNumber: String
    let headsign: String
    let isExpress: Bool
}
