import SwiftUI
import MapKit

struct MapView: View {

    let vehicleNumber: String

    @StateObject private var viewModel = VehicleMapViewModel()

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

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $viewModel.cameraPosition) {
                ForEach(Array(routePolylines.enumerated()), id: \.offset) { _, points in
                    MapPolyline(coordinates: points)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 3)
                }

                ForEach(routeStops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate) {
                        RouteStopPin(isNextStop: stop.id == nearestUpcomingStop?.id)
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
                        message: "Vehicle \(vehicleNumber) isn't currently reporting a position.",
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
                        VehicleInfoCard(vehicle: vehicle, nextStop: nearestUpcomingStop)
                            .padding()
                    }
                }
            }
        }
        .navigationTitle("Vehicle \(vehicleNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.startAutoRefresh(number: vehicleNumber)
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
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