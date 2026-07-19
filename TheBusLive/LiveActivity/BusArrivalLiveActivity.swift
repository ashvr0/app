import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity widget extension for TheBus Live.
/// Shows the next bus arrival on the Dynamic Island and lock screen.
///
/// Add this file to a new Widget Extension target in Xcode:
///   File > New > Target > Widget Extension
///   Name it "TheBusLiveActivityExtension"
///   Uncheck "Include Configuration Intent"
///
/// Then add BusArrivalAttributes.swift to both the main app target
/// and this extension target.
struct BusArrivalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusArrivalAttributes.self) { context in
            // Lock screen / StandBy banner
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view — shown when user long-presses the island
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(context: context)
                }
            } compactLeading: {
                // Left side of compact island
                CompactLeading(context: context)
            } compactTrailing: {
                // Right side of compact island
                CompactTrailing(context: context)
            } minimal: {
                // Single dot when two activities are competing
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<BusArrivalAttributes>

    var body: some View {
        HStack(spacing: 14) {
            // Route badge
            VStack(spacing: 2) {
                Text(context.attributes.routeNumber)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(context.attributes.isExpress ? Color.purple : Color.green)
                    )

                if context.attributes.isExpress {
                    Text("EXPRESS")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.purple)
                }
            }

            // Stop and arrival info
            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.stopName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Text(context.attributes.headsign)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if context.state.isCancelled {
                        Label("Cancelled", systemImage: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    } else if context.state.isLive {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    if let next = context.state.nextStopTime, !context.state.isCancelled {
                        Text("Then \(next)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            // Countdown
            if context.state.isCancelled {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    if let minutes = context.state.minutesAway {
                        if minutes <= 0 {
                            Text("Now")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.green)
                        } else {
                            Text("\(minutes)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text("min")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else {
                        Text(context.state.stopTime)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Dynamic Island: Expanded Regions

private struct ExpandedLeading: View {
    let context: ActivityViewContext<BusArrivalAttributes>

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bus.fill")
                .font(.caption)
                .foregroundStyle(context.attributes.isExpress ? .purple : .green)

            Text("Route \(context.attributes.routeNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.leading, 4)
    }
}

private struct ExpandedTrailing: View {
    let context: ActivityViewContext<BusArrivalAttributes>

    var body: some View {
        Group {
            if context.state.isCancelled {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            } else if let minutes = context.state.minutesAway {
                HStack(spacing: 2) {
                    if minutes <= 0 {
                        Text("Now")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    } else {
                        Text("\(minutes)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("min")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            } else {
                Text(context.state.stopTime)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 4)
    }
}

private struct ExpandedBottom: View {
    let context: ActivityViewContext<BusArrivalAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.stopName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(context.attributes.headsign)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Live indicator or next bus
            if context.state.isLive && !context.state.isCancelled {
                HStack(spacing: 3) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Live")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            if let next = context.state.nextStopTime, !context.state.isCancelled {
                Text("Next: \(next)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

// MARK: - Dynamic Island: Compact

private struct CompactLeading: View {
    let context: ActivityViewContext<BusArrivalAttributes>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bus.fill")
                .font(.caption2)
                .foregroundStyle(context.attributes.isExpress ? .purple : .green)
            Text(context.attributes.routeNumber)
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
        .padding(.leading, 4)
    }
}

private struct CompactTrailing: View {
    let context: ActivityViewContext<BusArrivalAttributes>

    var body: some View {
        Group {
            if context.state.isCancelled {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if let minutes = context.state.minutesAway {
                if minutes <= 0 {
                    Text("Now")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                } else {
                    Text("\(minutes)m")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            } else {
                Text(context.state.stopTime)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 4)
    }
}

// MARK: - Dynamic Island: Minimal

private struct MinimalView: View {
    let context: ActivityViewContext<BusArrivalAttributes>

    var body: some View {
        if context.state.isCancelled {
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        } else if let minutes = context.state.minutesAway, minutes <= 0 {
            Image(systemName: "bus.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        } else {
            Image(systemName: "bus.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: BusArrivalAttributes(
    stopName: "Ala Moana Center",
    stopID: "925",
    routeNumber: "8",
    headsign: "Kalihi via Downtown",
    isExpress: false
)) {
    BusArrivalLiveActivity()
} contentStates: {
    BusArrivalAttributes.ContentState(
        minutesAway: 4,
        stopTime: "3:45 PM",
        isLive: true,
        isCancelled: false,
        nextStopTime: "4:02 PM",
        lastUpdated: Date()
    )
    BusArrivalAttributes.ContentState(
        minutesAway: 0,
        stopTime: "3:45 PM",
        isLive: true,
        isCancelled: false,
        nextStopTime: "4:02 PM",
        lastUpdated: Date()
    )
    BusArrivalAttributes.ContentState(
        minutesAway: nil,
        stopTime: "3:45 PM",
        isLive: false,
        isCancelled: true,
        nextStopTime: nil,
        lastUpdated: Date()
    )
}
