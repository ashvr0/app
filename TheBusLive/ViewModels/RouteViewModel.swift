import Foundation

@MainActor
final class RouteViewModel: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published private(set) var routes: [BusRoute] = []
    @Published private(set) var state: LoadState = .idle
    @Published var searchText: String = ""

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// Loads details for a single known route number, such as when
    /// navigating in from a stop's arrival list.
    func loadRoute(routeNum: String) async {
        state = .loading
        do {
            let response = try await client.fetchRoutes(routeNum: routeNum)
            handle(response)
        } catch let error as APIError {
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Searches routes by matching text against their headsign, used by
    /// the Search tab's route search mode.
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            routes = []
            state = .idle
            return
        }

        state = .loading
        do {
            let response = try await client.searchRoutes(headsign: query)
            handle(response)
        } catch let error as APIError {
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func handle(_ response: RouteResponse) {
        if let message = response.errorMessage {
            state = .failed(message)
            routes = []
            return
        }
        routes = response.route
        state = response.route.isEmpty ? .empty : .loaded
    }
}