import Foundation

/// Builds request URLs for TheBus's public Web API.
/// All of TheBus's endpoints are read only, use HTTP GET, and return XML.
/// Each case here maps to one documented service at
/// https://hea.thebus.org/api_info.asp.
enum Endpoint {
    case arrivals(stopID: String)
    case vehicle(number: String)
    case routeByNumber(routeNum: String)
    case routeByHeadsign(text: String)

    private var path: String {
        switch self {
        case .arrivals:
            return "/arrivals/"
        case .vehicle:
            return "/vehicle/"
        case .routeByNumber, .routeByHeadsign:
            return "/route/"
        }
    }

    private var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "key", value: APIConfig.key)]
        switch self {
        case .arrivals(let stopID):
            items.append(URLQueryItem(name: "stop", value: stopID))
        case .vehicle(let number):
            items.append(URLQueryItem(name: "num", value: number))
        case .routeByNumber(let routeNum):
            items.append(URLQueryItem(name: "route", value: routeNum))
        case .routeByHeadsign(let text):
            items.append(URLQueryItem(name: "headsign", value: text))
        }
        return items
    }

    func url() -> URL? {
        var components = URLComponents()
        components.scheme = APIConfig.scheme
        components.host = APIConfig.host
        components.path = path
        components.queryItems = queryItems
        return components.url
    }
}
