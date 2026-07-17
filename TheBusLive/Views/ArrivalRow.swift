import SwiftUI

/// A single row showing one bus's predicted arrival at a stop. Reused by
/// both `StopDetailView` and, in a lighter mode, `HomeView`.
struct ArrivalRow: View {
    let arrival: Arrival

    /// Minutes from now until the predicted/scheduled arrival, if a date
    /// is available on the arrival. Negative or zero minutes are treated
    /// as "Due" rather than showing a negative countdown.
    private var minutesUntilArrival: Int? {
        guard let date = arrival.arrivalDate else { return nil }
        let minutes = Int(date.timeIntervalSinceNow / 60)
        return minutes
    }

    private var countdownText: String? {
        guard let minutes = minutesUntilArrival else { return nil }
        if minutes <= 0 { return "Due" }
        return "\(minutes) min"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(arrival.route)
                    .font(.headline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Bus \(arrival.route)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }

                MarqueeText(text: arrival.headsign, font: .subheadline, fontWeight: .medium)

                HStack(spacing: 6) {
                    if arrival.isCanceled {
                        Label("Canceled", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if arrival.estimated {
                        Label("Live", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Scheduled", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let direction = arrival.direction, !direction.isEmpty {
                        Text(direction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let countdownText, !arrival.isCanceled {
                    Text(countdownText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                Text(arrival.stopTime)
                    .font(countdownText != nil && !arrival.isCanceled ? .caption : .subheadline)
                    .fontWeight(countdownText != nil && !arrival.isCanceled ? .regular : .semibold)
                    .foregroundStyle(arrival.isCanceled ? .secondary : (countdownText != nil ? .secondary : .primary))
                    .strikethrough(arrival.isCanceled)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ArrivalRow(arrival: Arrival(
            id: "1", trip: "t1", route: "8", headsign: "Ala Moana Center",
            vehicle: "101", direction: "Eastbound", stopTime: "3:45 PM",
            date: nil, estimated: true, longitude: nil, latitude: nil,
            shape: nil, canceled: 0
        ))
        ArrivalRow(arrival: Arrival(
            id: "2", trip: "t2", route: "20", headsign: "Airport - Waikiki",
            vehicle: nil, direction: "Westbound", stopTime: "4:02 PM",
            date: nil, estimated: false, longitude: nil, latitude: nil,
            shape: nil, canceled: 1
        ))
    }
}