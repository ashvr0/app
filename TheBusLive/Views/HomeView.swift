import SwiftUI
import MapKit

struct HomeView: View {

    @EnvironmentObject private var favoritesManager: FavoritesManager

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.3069, longitude: -157.8583),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedStop: Stop?

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
            .sheet(item: $selectedStop) { stop in
                NavigationStack {
                    StopDetailView(stop: stop)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var mapPreview: some View {
        NavigationLink {
            AllStopsMapView()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
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
                .allowsHitTesting(false)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .padding(8)
                    .glassBackground(in: Circle())
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }
}

#Preview {
    HomeView()
        .environmentObject(FavoritesManager())
}