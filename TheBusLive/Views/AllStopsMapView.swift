import SwiftUI
import MapKit

struct AllStopsMapView: View {

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.3069, longitude: -157.8583),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedStop: Stop?

    @EnvironmentObject private var favoritesManager: FavoritesManager

    /// Only render stops inside the current visible region, and only
    /// once zoomed in enough, so the map doesn't try to place
    /// thousands of pins at once.
    private var visibleStops: [Stop] {
        guard let region = visibleRegion else { return [] }

        let latDelta = region.span.latitudeDelta / 2
        let lonDelta = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - latDelta
        let maxLat = region.center.latitude + latDelta
        let minLon = region.center.longitude - lonDelta
        let maxLon = region.center.longitude + lonDelta

        guard region.span.latitudeDelta < 0.12 else { return [] }

        return Stop.allStops.filter {
            $0.latitude >= minLat && $0.latitude <= maxLat &&
            $0.longitude >= minLon && $0.longitude <= maxLon
        }
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(visibleStops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Button {
                        selectedStop = stop
                    } label: {
                        StopPin(stop: stop, isFavorite: favoritesManager.isFavorite(stop))
                    }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .onMapCameraChange { context in
            visibleRegion = context.region
        }
        .overlay(alignment: .top) {
            if visibleRegion == nil || visibleRegion!.span.latitudeDelta >= 0.12 {
                Text("Zoom in to see stop pins")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackground(in: Capsule())
                    .padding(.top, 8)
            }
        }
        .navigationTitle("All Stops")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStop) { stop in
            NavigationStack {
                StopDetailView(stop: stop)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct StopPin: View {
    let stop: Stop
    let isFavorite: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(stop.stopID)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .glassBackground(in: Capsule())
            Image(systemName: isFavorite ? "star.circle.fill" : "mappin.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(isFavorite ? .yellow : Color.accentColor)
                .background(Circle().fill(.white).frame(width: 16, height: 16))
        }
    }
}

#Preview {
    NavigationStack {
        AllStopsMapView()
            .environmentObject(FavoritesManager())
    }
}