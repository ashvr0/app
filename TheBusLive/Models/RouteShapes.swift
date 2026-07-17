import Foundation
import CoreLocation

/// Road-following polylines for a route, bundled from TheBus's GTFS
/// `shapes.txt` (see `Scripts/generate_shapes_json.py`), keyed by route
/// short name to match what the live Route API returns as `routeNum`.
/// A route can have more than one shape (for example, one per direction
/// or branch), so lookups return an array of polylines rather than one.
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

    /// Returns the bundled polyline(s) for a route short name (for
    /// example "8" or "A LINE"), or an empty array if none are bundled.
    static func polylines(forRouteShortName routeShortName: String) -> [[CLLocationCoordinate2D]] {
        byRoute[routeShortName] ?? []
    }
}
