import Foundation
import SwiftUI
import MapKit

@MainActor
final class VehicleMapViewModel: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published private(set) var vehicles: [Vehicle] = []
    @Published private(set) var state: LoadState = .idle
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.3069, longitude: -157.8583),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        )
    )

    private let client: APIClient
    private var refreshTask: Task<Void, Never>?

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// Only recenter the camera automatically on the very first load for
    /// a given tracking session, so the map doesn't keep yanking the
    /// user's view back to the vehicle every refresh if they've panned
    /// around to look at nearby streets.
    private var hasCenteredCamera = false

    func loadVehicle(number: String, animateMovement: Bool = true) async {
        // Only show the full-screen loading state on the very first
        // fetch; subsequent polls should update quietly in the
        // background so the bus visibly glides to its new spot instead
        // of flashing a loading spinner every 15 seconds.
        if vehicles.isEmpty {
            state = .loading
        }
        do {
            let response = try await client.fetchVehicle(number: number)
            if Task.isCancelled {
                return
            }

            if let message = response.errorMessage {
                state = .failed(message)
                vehicles = []
                return
            }

            let results = response.vehicle ?? []
            state = results.isEmpty ? .empty : .loaded

            if animateMovement {
                withAnimation(.linear(duration: 1.0)) {
                    vehicles = results
                }
            } else {
                vehicles = results
            }

            if let first = results.first, !hasCenteredCamera {
                hasCenteredCamera = true
                withAnimation {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: first.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )
                    )
                }
            }
        } catch is CancellationError {
            // Task was cancelled, no action needed
            return
        } catch let error as APIError {
            if error.isCancellation {
                return
            }
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Polls a vehicle's position every 15 seconds for a more responsive,
    /// smoothly-animated view of where the bus actually is. TheBus's AVL
    /// feed itself may not update faster than ~30-60s, but polling more
    /// often means we pick up a fresh position sooner after it posts,
    /// rather than waiting up to 30s beyond that.
    func startAutoRefresh(number: String) {
        stopAutoRefresh()
        hasCenteredCamera = false
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadVehicle(number: number)
                if Task.isCancelled {
                    break
                }

                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                } catch is CancellationError {
                    break
                } catch {
                    // Sleep was interrupted, but not cancelled
                    continue
                }
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    deinit {
        // `deinit` is nonisolated, so it cannot synchronously call the
        // @MainActor `stopAutoRefresh()`. Cancelling the task directly
        // here is safe from any context since `Task.cancel()` itself is
        // not actor-isolated.
        refreshTask?.cancel()
    }
}