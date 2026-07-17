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

    /// The stops actually rendered on the map. Recomputed only after the
    /// camera settles (see `regionUpdateTask`), rather than on every
    /// intermediate frame of a pinch/pan gesture, which is what was
    /// causing the lag when zooming.
    @State private var visibleStops: [Stop] = []
    @State private var regionUpdateTask: Task<Void, Never>?

    @EnvironmentObject private var favoritesManager: FavoritesManager

    private var isZoomedInEnough: Bool {
        guard let region = visibleRegion else { return false }
        return region.span.latitudeDelta < 0.12
    }

    /// Filters stops for a given region. Run off the main actor so large
    /// stop lists don't block scrolling/zooming.
    nonisolated private func computeVisibleStops(for region: MKCoordinateRegion, allStops: [Stop]) -> [Stop] {
        let latDelta = region.span.latitudeDelta / 2
        let lonDelta = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - latDelta
        let maxLat = region.center.latitude + latDelta
        let minLon = region.center.longitude - lonDelta
        let maxLon = region.center.longitude + lonDelta

        guard region.span.latitudeDelta < 0.12 else { return [] }

        return allStops.filter {
            $0.latitude >= minLat && $0.latitude <= maxLat &&
            $0.longitude >= minLon && $0.longitude <= maxLon
        }
    }

    /// Debounces rapid camera-change callbacks (fired continuously during
    /// pinch-zoom) so we only recompute + re-render pins once movement
    /// pauses briefly, instead of on every single frame.
    private func scheduleVisibleStopsUpdate(for region: MKCoordinateRegion) {
        regionUpdateTask?.cancel()
        let allStops = Stop.allStops
        regionUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000) // ~0.12s debounce
            guard !Task.isCancelled else { return }
            let filtered = computeVisibleStops(for: region, allStops: allStops)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                visibleStops = filtered
            }
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
        .onMapCameraChange(frequency: .continuous) { context in
            // Keep visibleRegion live so the "zoom in" overlay reacts
            // immediately, but debounce the (potentially expensive)
            // stop filtering separately below.
            visibleRegion = context.region
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            scheduleVisibleStopsUpdate(for: context.region)
        }
        .overlay(alignment: .top) {
            if !isZoomedInEnough {
                Text("Zoom in to see stop pins")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassBackground(in: Capsule())
                    .padding(.top, 8)
            }
        }
        .onAppear {
            if let region = visibleRegion {
                scheduleVisibleStopsUpdate(for: region)
            } else if case let .region(region) = cameraPosition {
                visibleRegion = region
                scheduleVisibleStopsUpdate(for: region)
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