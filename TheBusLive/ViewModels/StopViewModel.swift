import Foundation

@MainActor
final class StopViewModel: ObservableObject {

    enum LoadState {
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
        state = .loading
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
        } catch let error as APIError {
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}