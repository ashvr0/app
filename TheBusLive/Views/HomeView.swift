import SwiftUI
import MapKit

struct HomeView: View {

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @AppStorage(AppPreferenceKeys.mapStyle) private var mapStyleRaw: String = AppMapStyleOption.standard.rawValue

    private var mapStyle: MapStyle {
        (AppMapStyleOption(rawValue: mapStyleRaw) ?? .standard).mapStyle
    }

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.3000, longitude: -157.8500),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedStop: Stop?

    @State private var showingAllStopsMap = false

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

    var body: some View {
        NavigationStack {
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
                            title: "No stops yet",
                            message: "Search for a stop to see live arrivals, or add stops to your favorites.",
                            systemImage: "bus.fill"
                        ))
                        .listRowSeparator(.hidden)
                        .frame(minHeight: 260)
                    }
                }

                Section {
                    Text(APIConfig.attributionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("TheBus Live")
            .navigationDestination(for: Stop.self) { stop in
                StopDetailView(stop: stop)
            }
            .navigationDestination(isPresented: $showingAllStopsMap) {
                AllStopsMapView()
            }
            .sheet(item: $selectedStop) { stop in
                NavigationStack {
                    StopDetailView(stop: stop)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    /// Uses a plain `Button` with programmatic navigation instead of
    /// `NavigationLink` to avoid the List row chevron over the map preview.
    /// Map interaction modes are disabled so the full card tap opens
    /// `AllStopsMapView`, where pins remain individually tappable.
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

#Preview {
    HomeView()
        .environmentObject(FavoritesManager())
}