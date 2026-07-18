import Foundation

/// A single predicted or scheduled arrival, matching the `arrival`
/// element returned by `http://api.thebus.org/arrivals/`.
struct Arrival: Identifiable, Codable, Hashable {
    let id: String
    let trip: String?
    let route: String
    let headsign: String
    let vehicle: String?
    let direction: String?
    let stopTime: String
    let date: String?
    let estimated: Bool
    let longitude: Double?
    let latitude: Double?
    let shape: String?
    let canceled: Int?

    enum CodingKeys: String, CodingKey {
        case id, trip, route, headsign, vehicle, direction
        case stopTime = "stopTime"
        case date = "Date"
        case estimated, longitude, latitude, shape, canceled
    }

    var isCanceled: Bool {
        canceled == 1
    }

    /// Parses `stopTime` (and `date`, when present) into a `Date` for
    /// display and sorting. TheBus returns local Honolulu time strings.
    var arrivalDate: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Pacific/Honolulu")

        if let date, !date.isEmpty {
            formatter.dateFormat = "MM/dd/yyyy h:mm a"
            if let parsed = formatter.date(from: "\(date) \(stopTime)") {
                return parsed
            }
        }

        formatter.dateFormat = "h:mm a"
        return formatter.date(from: stopTime)
    }
}

/// Wrapper matching the top level `stopTimes` element.
struct ArrivalsResponse: Codable {
    let stop: String?
    let timestamp: String?
    let errorMessage: String?
    let arrival: [Arrival]?
}
