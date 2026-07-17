import SwiftUI

/// A reusable row representing a stop, used in search results, favorites,
/// and the recents list.
struct StopRow: View {
    let stop: Stop
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "signpost.right.fill")
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Stop \(stop.stopID)" + (stop.routeShortNames.isEmpty ? "" : " · Routes \(stop.routeShortNames.joined(separator: ", "))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        StopRow(stop: Stop.sampleStops[0], isFavorite: true, onToggleFavorite: {})
        StopRow(stop: Stop.sampleStops[1], isFavorite: false, onToggleFavorite: {})
    }
}