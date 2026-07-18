import SwiftUI

struct SearchView: View {

    private enum SearchMode: String, CaseIterable, Identifiable {
        case stops = "Stops"
        case routes = "Routes"
        var id: String { rawValue }
    }

    @EnvironmentObject private var favoritesManager: FavoritesManager

    @State private var mode: SearchMode = .stops
    @State private var stopQuery: String = ""
    @State private var routeQuery: String = ""
    @State private var debouncedStopQuery: String = ""
    @State private var debouncedRouteQuery: String = ""

    private var trimmedStopQuery: String {
        stopQuery.trimmingCharacters(in: .whitespaces)
    }

    private var trimmedRouteQuery: String {
        routeQuery.trimmingCharacters(in: .whitespaces)
    }

    private var filteredStops: [Stop] {
        guard !debouncedStopQuery.isEmpty else { return [] }
        let query = debouncedStopQuery.lowercased()
        return Array(Stop.allStops
            .filter { $0.name.lowercased().contains(query) || $0.stopID == debouncedStopQuery }
            .prefix(100))
    }

    private var filteredRoutes: [BusRoute] {
        guard !debouncedRouteQuery.isEmpty else { return [] }
        let query = debouncedRouteQuery.lowercased()

        let exactMatches = BusRoute.allRoutes.filter { $0.routeNum.lowercased() == query }
        let partialMatches = BusRoute.allRoutes.filter {
            $0.routeNum.lowercased().contains(query) ||
            ($0.headsign ?? "").lowercased().contains(query)
        }.filter { !exactMatches.contains($0) }

        return Array((exactMatches + partialMatches).prefix(100))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Search mode", selection: $mode) {
                    ForEach(SearchMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: mode) { _, _ in
                    debouncedStopQuery = ""
                    debouncedRouteQuery = ""
                }

                switch mode {
                case .stops:
                    stopsList
                case .routes:
                    routesList
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: Stop.self) { stop in
                StopDetailView(stop: stop)
            }
            .navigationDestination(for: BusRoute.self) { route in
                RouteView(route: route)
            }
        }
        .onChange(of: stopQuery) { _, newValue in
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                debouncedStopQuery = newValue.trimmingCharacters(in: .whitespaces)
            }
        }
        .onChange(of: routeQuery) { _, newValue in
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                debouncedRouteQuery = newValue.trimmingCharacters(in: .whitespaces)
            }
        }
    }

    private var stopsList: some View {
        Group {
            if trimmedStopQuery.isEmpty {
                StatusView(kind: .empty(
                    title: "Search for a stop",
                    message: "Type a stop name or stop number, like \"Ala Moana\" or \"925\".",
                    systemImage: "signpost.right.fill"
                ))
            } else if filteredStops.isEmpty {
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
        .searchable(text: $stopQuery, prompt: "Stop name or number")
    }

    private var routesList: some View {
        Group {
            if trimmedRouteQuery.isEmpty {
                StatusView(kind: .empty(
                    title: "Search for a route",
                    message: "Type a route number or a headsign, like \"Ala Moana\" or \"20\".",
                    systemImage: "arrow.triangle.turn.up.right.circle"
                ))
            } else if filteredRoutes.isEmpty {
                StatusView(kind: .empty(
                    title: "No routes found",
                    message: "Try a different route number or headsign text.",
                    systemImage: "magnifyingglass"
                ))
            } else {
                List(filteredRoutes) { route in
                    NavigationLink(value: route) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Route \(route.routeNum)")
                                .font(.headline)
                            if let headsign = route.headsign, !headsign.isEmpty {
                                Text(headsign)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .searchable(text: $routeQuery, prompt: "Route number or headsign")
    }
}

#Preview {
    SearchView()
        .environmentObject(FavoritesManager())
}