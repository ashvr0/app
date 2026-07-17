import Foundation
import CoreLocation

/// Represents a single TheBus stop.
/// TheBus's official API does not expose a stop search endpoint, so stop
/// metadata (name, coordinates) is expected to be seeded from a bundled
/// stops list (for example, an exported copy of TheBus's public GTFS
/// `stops.txt`). The `stopID` is the only value actually required to call
/// the live arrivals endpoint.
struct Stop: Identifiable, Codable, Hashable {
    /// The stop number used by TheBus's arrivals API.
    let stopID: String
    let name: String
    let latitude: Double
    let longitude: Double
    let routeShortNames: [String]

    var id: String { stopID }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(stopID: String, name: String, latitude: Double, longitude: Double, routeShortNames: [String] = []) {
        self.stopID = stopID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.routeShortNames = routeShortNames
    }
}

extension Stop {
    /// A small built-in sample used only as a fallback if `stops.json`
    /// fails to load or hasn't been generated yet. See
    /// `Scripts/generate_stops_json.py` for producing the full dataset
    /// from TheBus's GTFS feed.
    static let sampleStops: [Stop] = [
        Stop(stopID: "925", name: "Ala Moana Center - Mall", latitude: 21.2906, longitude: -157.8420, routeShortNames: ["8", "20", "42"]),
        Stop(stopID: "302", name: "Waikiki - Kuhio Ave", latitude: 21.2793, longitude: -157.8294, routeShortNames: ["2", "13", "20"]),
        Stop(stopID: "1", name: "Downtown - King St", latitude: 21.3070, longitude: -157.8583, routeShortNames: ["1", "2", "3"])
    ]

    /// Full island-wide stop list, loaded once from the bundled
    /// `stops.json` (generated from TheBus's GTFS `stops.txt` +
    /// `stop_times.txt` + `trips.txt` + `routes.txt`). Falls back to
    /// `sampleStops` if the resource is missing or fails to decode.
    static let allStops: [Stop] = {
        guard
            let url = Bundle.main.url(forResource: "stops", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([Stop].self, from: data),
            !decoded.isEmpty
        else {
            return sampleStops
        }
        return decoded
    }()
}
