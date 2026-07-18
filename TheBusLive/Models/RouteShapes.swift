import Foundation
import CoreLocation

/// Road following polylines for each route, loaded from the bundled
/// Keyed by route short name and containing one or more polylines for each route.
enum RouteShapes {

    /// route short name -> array of polylines, each an array of coordinates.
    private static let byRoute: [String: [[CLLocationCoordinate2D]]] = {
        guard
            let url = Bundle.main.url(forResource: "shapes", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: [[[Double]]]].self, from: data)
        else {
            return [:]
        }

        var result: [String: [[CLLocationCoordinate2D]]] = [:]
        for (route, polylines) in decoded {
            result[route] = polylines.map { points in
                points.compactMap { point -> CLLocationCoordinate2D? in
                    guard point.count == 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: point[0], longitude: point[1])
                }
            }
        }
        return result
    }()

    /// Returns the bundled polyline(s) for a route short name,
    /// such as "8" or "A LINE". Returns an empty array if none exist.
    static func polylines(forRouteShortName routeShortName: String) -> [[CLLocationCoordinate2D]] {
        byRoute[routeShortName] ?? []
    }
}
