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
    /// When arrivals were last successfully fetched, used to show a
    /// "Last refresh: h:mm a" subtitle under the stop name.
    @Published private(set) var lastRefreshed: Date?

    let stop: Stop
    private let client: APIClient

    init(stop: Stop, client: APIClient = .shared) {
        self.stop = stop
        self.client = client
    }

    func loadArrivals() async {
        // Only show the full-screen loading state on the very first
        // fetch. Pull-to-refresh already has its own spinner, so
        // flipping state to .loading here would blank out the list
        // underneath it for no reason.
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
                case let (l?, r?):
                    return l < r
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                }
            }

            arrivals = sorted
            state = sorted.isEmpty ? .empty : .loaded
            lastRefreshed = Date()
        } catch is CancellationError {
            // The task was cancelled (e.g. the view disappeared or a
            // newer refresh superseded this one). Not a real failure,
            // so leave whatever state was already showing alone rather
            // than flashing an error at the user.
            return
        } catch let error as APIError {
            if error.isCancellation {
                return
            }
            state = .failed(error.localizedDescription)
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}