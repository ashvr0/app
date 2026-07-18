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
    private var arrivalsCache: [String: (data: ArrivalsResponse, timestamp: Date)] = [:]
    private let cacheExpirationSeconds: TimeInterval = 30
    private var inFlightRequests: [String: Task<Any, Error>] = [:]
    
    private let cacheLock = NSLock()
    private let requestLock = NSLock()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public requests
    func fetchArrivals(stopID: String) async throws -> ArrivalsResponse {
        let cacheKey = "arrivals:\(stopID)"

        if let cached = getCachedArrivals(stopID: stopID) {
            return cached
        }
        
        if let existingTask = getInFlightRequest(key: cacheKey) {
            return try await (existingTask.value as! ArrivalsResponse)
        }
        
        // Create task for this request
        let task: Task<ArrivalsResponse, Error> = Task {
            let node = try await fetchXML(.arrivals(stopID: stopID))
            let response = try ArrivalsXMLMapper.map(node)
            
            // Cache the result
            cacheLock.lock()
            arrivalsCache[stopID] = (response, Date())
            cacheLock.unlock()
            
            return response
        }
        
        storeInFlightRequest(key: cacheKey, task: task)
        defer { removeInFlightRequest(key: cacheKey) }
        
        return try await task.value
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
    
    func clearCache() {
        cacheLock.lock()
        arrivalsCache.removeAll()
        cacheLock.unlock()
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
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch {
            throw APIError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200..<300:
            break // Success
        case 400:
            throw APIError.httpStatus(400, "Bad request - check your stop ID or route")
        case 401, 403:
            throw APIError.httpStatus(403, "API key is invalid or expired")
        case 404:
            throw APIError.httpStatus(404, "Resource not found")
        case 429:
            throw APIError.httpStatus(429, "Rate limit exceeded - too many requests")
        case 500..<600:
            throw APIError.httpStatus(httpResponse.statusCode, "Server error - TheBus API is unavailable")
        default:
            throw APIError.httpStatus(httpResponse.statusCode, "Unexpected HTTP status \(httpResponse.statusCode)")
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
    
    // MARK: - Cache Management
    private func getCachedArrivals(stopID: String) -> ArrivalsResponse? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let cached = arrivalsCache[stopID] else { return nil }
        
        let elapsed = Date().timeIntervalSince(cached.timestamp)
        guard elapsed < cacheExpirationSeconds else {
            arrivalsCache.removeValue(forKey: stopID)
            return nil
        }
        
        return cached.data
    }
    
    // MARK: - Request Deduplication
    private func getInFlightRequest(key: String) -> Task<Any, Error>? {
        requestLock.lock()
        defer { requestLock.unlock() }
        return inFlightRequests[key]
    }
    
    private func storeInFlightRequest(key: String, task: Task<Any, Error>) {
        requestLock.lock()
        defer { requestLock.unlock() }
        inFlightRequests[key] = task
    }
    
    private func removeInFlightRequest(key: String) {
        requestLock.lock()
        defer { requestLock.unlock() }
        inFlightRequests.removeValue(forKey: key)
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
        
        let success = parser.parse()
        
        guard let root = delegate.root else {
            if let parserError = parser.parserError {
                NSLog("XML parsing error: \(parserError)")
                throw APIError.decodingFailed(parserError)
            } else if !success {
                let parseError = NSError(
                    domain: "SimpleXMLParser",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "XML parsing failed without error details"]
                )
                NSLog("XML parsing failed: unknown error")
                throw APIError.decodingFailed(parseError)
            } else {
                NSLog("XML parsing succeeded but returned no root element")
                throw APIError.invalidResponse
            }
        }
        
        return root
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var root: XMLNode?
        private var stack: [XMLNode] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
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

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            NSLog("XML parse error occurred: \(parseError)")
        }
    }
}

// MARK: - Mappers
enum ArrivalsXMLMapper {
    static func map(_ root: XMLNode) throws -> ArrivalsResponse {
        let stop = root.firstChild("stop")?.trimmedText
        let timestamp = root.firstChild("timestamp")?.trimmedText
        let errorMessage = root.firstChild("errorMessage")?.trimmedText
        let arrivals: [Arrival] = root.allChildren("arrival").compactMap { node in
            // Validate required fields
            guard let route = node.firstChild("route")?.trimmedText, !route.isEmpty else {
                NSLog("Warning: Arrival missing or empty required field 'route'")
                return nil
            }
            
            guard let id = node.firstChild("id")?.trimmedText, !id.isEmpty else {
                NSLog("Warning: Arrival missing or empty required field 'id'")
                return nil
            }
            
            guard let stopTime = node.firstChild("stopTime")?.trimmedText, !stopTime.isEmpty else {
                NSLog("Warning: Arrival \(id) missing or empty required field 'stopTime'")
                return nil
            }

            return Arrival(
                id: id,
                trip: node.firstChild("trip")?.trimmedText,
                route: route,
                headsign: node.firstChild("headsign")?.trimmedText ?? "",
                vehicle: node.firstChild("vehicle")?.trimmedText,
                direction: node.firstChild("direction")?.trimmedText,
                stopTime: stopTime,
                date: node.firstChild("date")?.trimmedText,
                estimated: (node.firstChild("estimated")?.trimmedText == "1"),
                longitude: Double(node.firstChild("longitude")?.trimmedText ?? ""),
                latitude: Double(node.firstChild("latitude")?.trimmedText ?? ""),
                shape: node.firstChild("shape")?.trimmedText,
                canceled: Int(node.firstChild("canceled")?.trimmedText ?? "")
            )
        }

        return ArrivalsResponse(
            stop: stop,
            timestamp: timestamp,
            errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil,
            arrival: arrivals
        )
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
            else {
                NSLog("Warning: Vehicle missing or invalid latitude/longitude")
                return nil
            }
            
            guard let number = node.firstChild("number")?.trimmedText, !number.isEmpty else {
                NSLog("Warning: Vehicle missing or empty required field 'number'")
                return nil
            }

            return Vehicle(
                number: number,
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

        return VehiclesResponse(
            timestamp: timestamp,
            errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil,
            vehicle: vehicles
        )
    }
}

enum RouteXMLMapper {
    static func map(_ root: XMLNode) throws -> RouteResponse {
        let routeName = root.firstChild("routeName")?.trimmedText
        let routeID = root.firstChild("routeID")?.trimmedText
        let errorMessage = root.firstChild("errorMessage")?.trimmedText

        let routes: [BusRoute] = root.allChildren("route").compactMap { node in
            guard let routeNum = node.firstChild("routeNum")?.trimmedText, !routeNum.isEmpty else {
                NSLog("Warning: Route missing or empty required field 'routeNum'")
                return nil
            }
            
            return BusRoute(
                routeNum: routeNum,
                shapeID: node.firstChild("shapeID")?.trimmedText,
                firstStop: node.firstChild("firstStop")?.trimmedText,
                headsign: node.firstChild("headsign")?.trimmedText
            )
        }

        return RouteResponse(
            routeName: routeName,
            routeID: routeID,
            errorMessage: errorMessage?.isEmpty == false ? errorMessage : nil,
            route: routes
        )
    }
}
