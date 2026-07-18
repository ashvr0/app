import Foundation

/// Represents a single TheBus route entry, matching the `route`
/// element returned by `http://api.thebus.org/route/`.
struct BusRoute: Identifiable, Codable, Hashable {
    let routeNum: String
    let shapeID: String?
    let firstStop: String?
    let headsign: String?

    var id: String { "\(routeNum)-\(headsign ?? "")-\(shapeID ?? "")" }

    init(routeNum: String, shapeID: String? = nil, firstStop: String? = nil, headsign: String? = nil) {
        self.routeNum = routeNum
        self.shapeID = shapeID
        self.firstStop = firstStop
        self.headsign = headsign
    }
}

/// Wrapper for the top level `routes` element returned by the API,
/// including the optional `error` field.
struct RouteResponse: Codable {
    let routeName: String?
    let routeID: String?
    let errorMessage: String?
    let route: [BusRoute]
}

extension BusRoute {
    /// Full list of TheBus routes loaded from the bundled `routes.json`.
    /// Contains route data for route search and browsing.
    /// Live arrival and route shape data are fetched from the API.
    static let allRoutes: [BusRoute] = {
        guard
            let url = Bundle.main.url(forResource: "routes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([BusRoute].self, from: data),
            !decoded.isEmpty
        else {
            return []
        }
        return decoded
    }()
}
