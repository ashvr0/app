import Foundation

/// Networking client for TheBus's Web API.
///
/// TheBus's API returns XML rather than JSON, so this client uses
/// `XMLParser` to build a generic node tree, then maps that tree onto the
/// app's Codable models. This avoids any third party dependency, which
/// keeps the GitHub Actions build simple.
actor APIClient {

    static let shared = APIClient()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public requests
    func fetchArrivals(stopID: String) async throws -> ArrivalsResponse {
        let node = try await fetchXML(.arrivals(stopID: stopID))
        return try ArrivalsXMLMapper.map(node)
    }

    func fetchVehicle(number: String) async throws -> VehiclesResponse {
        let node = try await fetchXML(.vehicle(number: number))
        return try VehicleXMLMapper.map(node)
    }

    func fetchRoutes(routeNum: String) async throws -> RouteResponse {
        let node = try await fetchXML(.routeByNumber(routeNum: routeNum))
        return try RouteXMLMapper.map(node)
    }

    func searchRoutes(headsign: String) async throws -> RouteResponse {
        let node = try await fetchXML(.routeByHeadsign(text: headsign))
        return try RouteXMLMapper.map(node)
    }

    // MARK: - Core fetch
    private func fetchXML(_ endpoint: Endpoint) async throws -> XMLNode {
        guard APIConfig.hasKey else {
            throw APIError.missingAPIKey
        }
        guard let url = endpoint.url() else {
            throw APIError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw APIError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpStatus(httpResponse.statusCode)
        }
        guard !data.isEmpty else {
            throw APIError.noData
        }

        do {
            return try SimpleXMLParser.parse(data: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}

// MARK: - Minimal XML tree
/// A minimal generic XML node used as an intermediate representation
/// before mapping into the app's typed models.
final class XMLNode {
    let name: String
    var text: String = ""
    var children: [XMLNode] = []
    weak var parent: XMLNode?

    init(name: String, parent: XMLNode? = nil) {
        self.name = name
        self.parent = parent
    }

    func firstChild(_ name: String) -> XMLNode? {
        children.first { $0.name == name }
    }

    func allChildren(_ name: String) -> [XMLNode] {
        children.filter { $0.name == name }
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Parses raw XML data into a simple `XMLNode` tree using Foundation's
/// event driven `XMLParser`.
enum SimpleXMLParser {
    static func parse(data: Data) throws -> XMLNode {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), let root = delegate.root else {
            throw parser.parserError ?? APIError.invalidResponse
        }
        return root
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var root: XMLNode?
        private var stack: [XMLNode] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let node = XMLNode(name: elementName, parent: stack.last)
            stack.last?.children.append(node)
            stack.append(node)
            if root == nil {
                root = node
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            stack.removeLast()
        }
    }
}

// MARK: - Mappers

enum ArrivalsXMLMapper {
    static func map(_ root: XMLNode) throws -> ArrivalsResponse {
        let stop = root.firstChild("stop")?.trimmedText
        let timestamp = root.firstChild("timestamp")?.trimmedText
        let errorMessage = root.firstChild("errorMessage")?.trimmedText

        let arrivals: [Arrival] = root.allChildren("arrival").map { node in
            Arrival(
                id: node.firstChild("id")?.trimmedText ?? UUID().uuidString,
                trip: node.firstChild("trip")?.trimmedText,
                route: node.firstChild("route")?.trimmedText ?? "",
                headsign: node.firstChild("headsign")?.trimmedText ?? "",
                vehicle: node.firstChild("vehicle")?.trimmedText,
                direction: node.firstChild("direction")?.trimmedText,
                stopTime: node.firstChild("stopTime")?.trimmedText ?? "",
                date: node.firstChild("date")?.trimmedText,
                estimated: (node.firstChild("estimated")?.trimmedText == "1"),
                longitude: Double(node.firstChild("longitude")?.trimmedText ?? ""),
                latitude: Double(node.firstChild("latitude")?.trimmedText ?? ""),
                shape: node.firstChild("shape")?.trimmedText,
                canceled: Int(node.firstChild("canceled")?.trimmedText ?? "")
            )
        }

        return ArrivalsResponse(stop: stop, timestamp: timestamp, errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil, arrival: arrivals)
    }
}

enum VehicleXMLMapper {
    static func map(_ root: XMLNode) throws -> VehiclesResponse {
        let timestamp = root.firstChild("timestamp")?.trimmedText
        let errorMessage = root.firstChild("errorMessage")?.trimmedText

        let vehicles: [Vehicle] = root.allChildren("vehicle").compactMap { node in
            guard
                let lat = Double(node.firstChild("latitude")?.trimmedText ?? ""),
                let lon = Double(node.firstChild("longitude")?.trimmedText ?? "")
            else { return nil }

            return Vehicle(
                number: node.firstChild("number")?.trimmedText ?? "",
                trip: node.firstChild("trip")?.trimmedText,
                driver: node.firstChild("driver")?.trimmedText,
                latitude: lat,
                longitude: lon,
                adherence: node.firstChild("adherence")?.trimmedText,
                lastMessage: node.firstChild("last_message")?.trimmedText,
                routeShortName: node.firstChild("route_short_name")?.trimmedText,
                headsign: node.firstChild("headsign")?.trimmedText
            )
        }

        return VehiclesResponse(timestamp: timestamp, errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil, vehicle: vehicles)
    }
}

enum RouteXMLMapper {
    static func map(_ root: XMLNode) throws -> RouteResponse {
        let routeName = root.firstChild("routeName")?.trimmedText
        let routeID = root.firstChild("routeID")?.trimmedText
        let errorMessage = root.firstChild("errorMessage")?.trimmedText

        let routes: [BusRoute] = root.allChildren("route").map { node in
            BusRoute(
                routeNum: node.firstChild("routeNum")?.trimmedText ?? "",
                shapeID: node.firstChild("shapeID")?.trimmedText,
                firstStop: node.firstChild("firstStop")?.trimmedText,
                headsign: node.firstChild("headsign")?.trimmedText
            )
        }

        return RouteResponse(routeName: routeName, routeID: routeID, errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil, route: routes)
    }
}