import SwiftUI
import MapKit

struct SearchView: View {

    enum SearchScope: String, CaseIterable, Identifiable, Hashable {
        case stops = "Stops"
        case routes = "Routes"
        var id: String { rawValue }
    }

    private enum RouteFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case express = "Express"
        var id: String { rawValue }
    }

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @AppStorage(AppPreferenceKeys.mapStyle) private var mapStyleRaw: String = AppMapStyleOption.standard.rawValue

    @State private var query: String = ""
    @State private var debouncedQuery: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var scope: SearchScope = .stops
    @State private var routeFilter: RouteFilter = .all

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.3000, longitude: -157.8500),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var showingAllStopsMap = false

    private var mapStyle: MapStyle {
        (AppMapStyleOption(rawValue: mapStyleRaw) ?? .standard).mapStyle
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var visibleStops: [Stop] {
        guard let region = visibleRegion, region.span.latitudeDelta < 0.12 else { return [] }

        let latDelta = region.span.latitudeDelta / 2
        let lonDelta = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - latDelta
        let maxLat = region.center.latitude + latDelta
        let minLon = region.center.longitude - lonDelta
        let maxLon = region.center.longitude + lonDelta

        return Stop.allStops.filter {
            $0.latitude >= minLat && $0.latitude <= maxLat &&
            $0.longitude >= minLon && $0.longitude <= maxLon
        }
    }

    private var filteredStops: [Stop] {
        guard !debouncedQuery.isEmpty else { return [] }
        let q = debouncedQuery.lowercased()
        return Array(Stop.allStops
            .filter { $0.name.lowercased().contains(q) || $0.stopID == debouncedQuery }
            .prefix(100))
    }

    private var filteredRoutes: [BusRoute] {
        guard !debouncedQuery.isEmpty else { return [] }
        let q = debouncedQuery.lowercased()

        let exactMatches = BusRoute.allRoutes.filter { $0.routeNum.lowercased() == q }
        let partialMatches = BusRoute.allRoutes.filter {
            $0.routeNum.lowercased().contains(q) ||
            ($0.headsign ?? "").lowercased().contains(q)
        }.filter { !exactMatches.contains($0) }

        let matched = exactMatches + partialMatches
        let scoped = routeFilter == .express ? matched.filter(\.isExpressRoute) : matched
        return Array(scoped.prefix(100))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .navigationDestination(for: Stop.self) { stop in
                    StopDetailView(stop: stop)
                }
                .navigationDestination(for: BusRoute.self) { route in
                    RouteView(route: route)
                }
                .navigationDestination(isPresented: $showingAllStopsMap) {
                    AllStopsMapView()
                }
        }
        .searchable(text: $query, prompt: "Stop name, stop number, or route")
        .searchScopes($scope) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .onChange(of: query) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled {
                    debouncedQuery = newValue.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        if trimmedQuery.isEmpty {
            defaultState
        } else {
            switch scope {
            case .stops:
                stopsResults
            case .routes:
                routesResults
            }
        }
    }

    /// Shown before the person types anything: the island map preview
    /// (moved here from the old Home tab), plus favorites and recents,
    /// so Search doubles as the app's browsing home.
    private var defaultState: some View {
        List {
            Section {
                mapPreview
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            if !favoritesManager.favorites.isEmpty {
                Section("Favorite stops") {
                    ForEach(favoritesManager.favorites) { stop in
                        NavigationLink(value: stop) {
                            StopRow(stop: stop)
                        }
                    }
                }
            }

            if !favoritesManager.recents.isEmpty {
                Section("Recently viewed") {
                    ForEach(favoritesManager.recents) { stop in
                        NavigationLink(value: stop) {
                            StopRow(stop: stop)
                        }
                    }
                }
            }

            if favoritesManager.favorites.isEmpty && favoritesManager.recents.isEmpty {
                Section {
                    StatusView(kind: .empty(
                        title: "Search for a stop or route",
                        message: "Type a stop name, stop number, or route number above.",
                        systemImage: "magnifyingglass"
                    ))
                    .listRowSeparator(.hidden)
                    .frame(minHeight: 220)
                }
            }

            Section {
                Text(APIConfig.attributionText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var stopsResults: some View {
        Group {
            if filteredStops.isEmpty {
                StatusView(kind: .empty(
                    title: "No stops found",
                    message: "Try a different stop name or number.",
                    systemImage: "magnifyingglass"
                ))
            } else {
                List {
                    Section {
                        ForEach(filteredStops) { stop in
                            NavigationLink(value: stop) {
                                StopRow(
                                    stop: stop,
                                    isFavorite: favoritesManager.isFavorite(stop),
                                    onToggleFavorite: { favoritesManager.toggleFavorite(stop) }
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var routesResults: some View {
        Group {
            if filteredRoutes.isEmpty {
                StatusView(kind: .empty(
                    title: "No routes found",
                    message: "Try a different route number or headsign text.",
                    systemImage: "magnifyingglass"
                ))
            } else {
                VStack(spacing: 0) {
                    Picker("Route type", selection: $routeFilter) {
                        ForEach(RouteFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    List(filteredRoutes) { route in
                        NavigationLink(value: route) {
                            RouteResultRow(route: route)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
    }

    /// Uses a plain `Button` with programmatic navigation instead of
    /// `NavigationLink` to avoid the List row chevron over the map preview.
    private var mapPreview: some View {
        Button {
            HapticsManager.shared.light()
            showingAllStopsMap = true
        } label: {
            Map(position: $cameraPosition, interactionModes: []) {
                ForEach(visibleStops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate) {
                        Image(systemName: favoritesManager.isFavorite(stop) ? "star.circle.fill" : "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(favoritesManager.isFavorite(stop) ? .yellow : Color.accentColor)
                            .background(Circle().fill(.white).frame(width: 12, height: 12))
                    }
                }
            }
            .onMapCameraChange { context in
                visibleRegion = context.region
            }
            .mapStyle(mapStyle)
            .allowsHitTesting(false)
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct RouteResultRow: View {
    let route: BusRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Route \(route.routeNum)")
                    .font(.headline)
                if route.isExpressRoute {
                    ExpressBadge()
                }
            }
            if let headsign = route.headsign, !headsign.isEmpty {
                Text(headsign)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Small capsule marking a route as one of TheBus's Express routes
/// (A, C, E, U, W). Reused across search results, arrival rows, and
/// stop rows so Express status reads consistently throughout the app.
struct ExpressBadge: View {
    var body: some View {
        Text("Express")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(BusRoute.expressColor.opacity(0.15), in: Capsule())
            .foregroundStyle(BusRoute.expressColor)
    }
}

#Preview {
    SearchView()
        .environmentObject(FavoritesManager())
}