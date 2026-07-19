import SwiftUI
import MapKit

struct MapView: View {

    let vehicleNumber: String

    @StateObject private var viewModel = VehicleMapViewModel()
    @AppStorage(AppPreferenceKeys.mapStyle) private var mapStyleRaw: String = AppMapStyleOption.standard.rawValue
    @AppStorage(AppPreferenceKeys.debugModeEnabled) private var debugModeEnabled: Bool = false
    @State private var previewStop: Stop?
    @State private var detailStop: Stop?

    private var mapStyle: MapStyle {
        (AppMapStyleOption(rawValue: mapStyleRaw) ?? .standard).mapStyle
    }

    private var routePolylines: [[CLLocationCoordinate2D]] {
        guard let routeShortName = viewModel.vehicles.first?.routeShortName else { return [] }
        return RouteShapes.polylines(forRouteShortName: routeShortName)
    }

    /// Stops along the vehicle's current route, so riders can see where
    /// the bus is headed next, not just its current position. Matching is
    /// done case-/whitespace-insensitively since the route short name on
    /// a vehicle and on a stop don't always come from the API in exactly
    /// the same format (e.g. "8" vs "08", or trailing whitespace).
    private var routeStops: [Stop] {
        guard let routeShortName = viewModel.vehicles.first?.routeShortName else { return [] }
        let target = routeShortName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Stop.allStops.filter { stop in
            stop.routeShortNames.contains { candidate in
                candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
            }
        }
    }

    /// The stop nearest to the vehicle's current position, used to
    /// highlight "next stop" without needing full GTFS stop-sequence
    /// data (which isn't available on the client).
    private var nearestUpcomingStop: Stop? {
        guard let vehicle = viewModel.vehicles.first else { return nil }
        let vehicleLocation = CLLocation(latitude: vehicle.coordinate.latitude, longitude: vehicle.coordinate.longitude)
        return routeStops.min { lhs, rhs in
            let lhsDistance = CLLocation(latitude: lhs.coordinate.latitude, longitude: lhs.coordinate.longitude).distance(from: vehicleLocation)
            let rhsDistance = CLLocation(latitude: rhs.coordinate.latitude, longitude: rhs.coordinate.longitude).distance(from: vehicleLocation)
            return lhsDistance < rhsDistance
        }
    }

    /// Diagnostic banner shown only when Debug Mode is enabled in
    /// Settings. Useful for troubleshooting missing route/stop pins by
    /// showing the vehicle's raw route name and how many stops matched.
    @ViewBuilder
    private func debugBanner(for vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DEBUG")
                .font(.caption2.bold())
                .foregroundStyle(.red)
            Text("vehicle.routeShortName = \"\(vehicle.routeShortName ?? "nil")\"")
                .font(.caption2)
            Text("Stop.allStops.count = \(Stop.allStops.count)")
                .font(.caption2)
            Text("routeStops.count = \(routeStops.count)")
                .font(.caption2)
            Text("distinct route names in data = \(Set(Stop.allStops.flatMap { $0.routeShortNames }).count)")
                .font(.caption2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $viewModel.cameraPosition) {
                ForEach(Array(routePolylines.enumerated()), id: \.offset) { _, points in
                    MapPolyline(coordinates: points)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 3)
                }

                ForEach(routeStops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate) {
                        Button {
                            HapticsManager.shared.light()
                            previewStop = stop
                        } label: {
                            RouteStopPin(isNextStop: stop.id == nearestUpcomingStop?.id)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .popover(item: Binding(
                            get: { previewStop?.id == stop.id ? previewStop : nil },
                            set: { previewStop = $0 }
                        )) { selectedStop in
                            StopArrivalsPreview(stop: selectedStop) {
                                previewStop = nil
                                detailStop = selectedStop
                            }
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                }

                ForEach(viewModel.vehicles) { vehicle in
                    Annotation(vehicle.routeShortName ?? vehicle.number, coordinate: vehicle.coordinate) {
                        VehicleMarker(vehicle: vehicle)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .mapStyle(mapStyle)
            .ignoresSafeArea(edges: .bottom)

            GlassGroup {
                switch viewModel.state {
                case .idle, .loading:
                    if viewModel.vehicles.isEmpty {
                        StatusView(kind: .loading)
                            .glassBackground(in: Rectangle())
                    }
                case .empty:
                    StatusView(kind: .empty(
                        title: "Vehicle not found",
                        message: "Bus \(vehicleNumber) isn't currently reporting a position.",
                        systemImage: "location.slash"
                    ))
                    .glassBackground(in: Rectangle())
                case .failed(let message):
                    StatusView(kind: .error(message: message, retry: {
                        Task { await viewModel.loadVehicle(number: vehicleNumber) }
                    }))
                    .glassBackground(in: Rectangle())
                case .loaded:
                    if let vehicle = viewModel.vehicles.first {
                        VStack(spacing: 8) {
                            if debugModeEnabled {
                                debugBanner(for: vehicle)
                            }
                            VehicleInfoCard(vehicle: vehicle, nextStop: nearestUpcomingStop)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Bus \(vehicleNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.startAutoRefresh(number: vehicleNumber)
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .sheet(item: $detailStop) { stop in
            NavigationStack {
                StopDetailView(stop: stop)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct RouteStopPin: View {
    let isNextStop: Bool

    var body: some View {
        Circle()
            .fill(isNextStop ? Color.accentColor : Color.secondary.opacity(0.5))
            .frame(width: isNextStop ? 12 : 7, height: isNextStop ? 12 : 7)
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: isNextStop ? 2 : 1)
            )
            .shadow(radius: isNextStop ? 2 : 0)
    }
}

private struct VehicleMarker: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "bus.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 2)
        }
    }
}

private struct VehicleInfoCard: View {
    let vehicle: Vehicle
    var nextStop: Stop? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Route \(vehicle.routeShortName ?? "?")")
                    .font(.headline)
                Spacer()
                if let minutes = vehicle.adherenceMinutes {
                    Text(adherenceText(minutes))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(minutes < 0 ? .red : .green)
                }
            }

            if let headsign = vehicle.headsign, !headsign.isEmpty {
                Text(headsign)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let nextStop {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    Text("Next stop:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MarqueeText(text: nextStop.name, font: .caption, fontWeight: .semibold)
                        .frame(maxWidth: 200)
                }
            }

            if let lastMessage = vehicle.lastMessage, !lastMessage.isEmpty {
                Text("Last update: \(lastMessage)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(in: RoundedRectangle(cornerRadius: 16))
    }

    private func adherenceText(_ minutes: Int) -> String {
        if minutes == 0 { return "On time" }
        return minutes > 0 ? "\(minutes) min early" : "\(abs(minutes)) min late"
    }
}

#Preview {
    NavigationStack {
        MapView(vehicleNumber: "101")
    }
}