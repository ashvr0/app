import ActivityKit
import Foundation

/// Manages the lifecycle of bus arrival Live Activities.
///
/// Call `start()` when a user taps "Track" on an arrival.
/// The activity updates automatically on each arrival refresh.
/// Call `end()` when the user leaves the tracking screen or the bus arrives.
@MainActor
final class LiveActivityManager: ObservableObject {

    static let shared = LiveActivityManager()

    private init() {}

    /// The currently running activity, if any.
    private var currentActivity: Activity<BusArrivalAttributes>?

    /// Whether Live Activities are supported on this device.
    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Start

    func start(
        stopName: String,
        stopID: String,
        routeNumber: String,
        headsign: String,
        isExpress: Bool,
        arrival: Arrival
    ) {
        guard isSupported else { return }

        // End any existing activity before starting a new one
        Task { await endCurrent() }

        let attributes = BusArrivalAttributes(
            stopName: stopName,
            stopID: stopID,
            routeNumber: routeNumber,
            headsign: headsign,
            isExpress: isExpress
        )

        let initialState = contentState(from: [arrival], nextArrival: nil)

        let content = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(120) // Mark stale after 2 min
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil // No push notifications, we update manually
            )
        } catch {
            NSLog("Live Activity failed to start: \(error)")
        }
    }

    // MARK: - Update

    /// Call this every time new arrivals are fetched for the tracked stop.
    /// Pass the full sorted arrivals array; the manager picks the first
    /// two matching the tracked route.
    func update(arrivals: [Arrival], routeNumber: String) async {
        guard let activity = currentActivity else { return }

        let matching = arrivals.filter {
            $0.route.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            == routeNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }

        let first = matching.first
        let second = matching.dropFirst().first

        let state = contentState(from: first.map { [$0] } ?? [], nextArrival: second)

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(120)
        )

        await activity.update(content)
    }

    // MARK: - End

    /// Call when the user stops tracking or the bus has arrived.
    func end(dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        await endCurrent(dismissalPolicy: dismissalPolicy)
    }

    private func endCurrent(dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = currentActivity else { return }
        await activity.end(nil, dismissalPolicy: dismissalPolicy)
        currentActivity = nil
    }

    // MARK: - Helpers

    private func contentState(from arrivals: [Arrival], nextArrival: Arrival?) -> BusArrivalAttributes.ContentState {
        let first = arrivals.first

        let minutesAway: Int?
        if let date = first?.arrivalDate {
            let raw = Int(date.timeIntervalSinceNow / 60)
            minutesAway = max(raw, 0)
        } else {
            minutesAway = nil
        }

        return BusArrivalAttributes.ContentState(
            minutesAway: minutesAway,
            stopTime: first?.stopTime ?? "",
            isLive: first?.estimated ?? false,
            isCancelled: first?.isCanceled ?? false,
            nextStopTime: nextArrival?.stopTime,
            lastUpdated: Date()
        )
    }
}
