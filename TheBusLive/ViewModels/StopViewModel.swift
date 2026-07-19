import Foundation

@MainActor
final class StopViewModel: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published private(set) var arrivals: [Arrival] = []
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var lastRefreshed: Date?

    // The route being actively tracked via Live Activity, if any.
    // Set this when the user taps Track, cleared when they stop.
    var trackedRouteNumber: String?

    let stop: Stop
    private let client: APIClient

    init(stop: Stop, client: APIClient = .shared) {
        self.stop = stop
        self.client = client
    }

    func loadArrivals() async {
        if arrivals.isEmpty {
            state = .loading
        }
        do {
            let response = try await client.fetchArrivals(stopID: stop.stopID)

            if let message = response.errorMessage {
                state = .failed(message)
                arrivals = []
                return
            }

            let sorted = (response.arrival ?? []).sorted { lhs, rhs in
                switch (lhs.arrivalDate, rhs.arrivalDate) {
                case let (l?, r?): return l < r
                case (nil, _): return false
                case (_, nil): return true
                }
            }

            arrivals = sorted
            state = sorted.isEmpty ? .empty : .loaded
            lastRefreshed = Date()

            // Push a Live Activity update if tracking is active
            if let route = trackedRouteNumber {
                await LiveActivityManager.shared.update(
                    arrivals: sorted,
                    routeNumber: route
                )
            }

        } catch is CancellationError {
            return
        } catch let error as APIError {
            if error.isCancellation { return }
            state = .failed(error.localizedDescription)
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
