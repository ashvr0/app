import SwiftUI

/// A tiny in-app log buffer so debug prints are visible on-device
/// without Xcode attached. Call `DebugConsole.shared.log(...)` anywhere
/// instead of (or alongside) `print(...)`.
@MainActor
final class DebugConsole: ObservableObject {
    static let shared = DebugConsole()

    @Published private(set) var lines: [String] = []

    private init() {}

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        print(entry)
        lines.append(entry)
        if lines.count > 500 {
            lines.removeFirst(lines.count - 500)
        }
    }

    func clear() {
        lines.removeAll()
    }
}

/// A pull-up debug console, shown from the Debug Console button in
/// Settings. Displays everything logged via `DebugConsole.shared.log`.
struct DebugConsoleView: View {
    @ObservedObject private var console = DebugConsole.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(console.lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(colorFor(line))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: console.lines.count) { _, _ in
                    if let last = console.lines.indices.last {
                        withAnimation {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { console.clear() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func colorFor(_ line: String) -> Color {
        if line.contains("🔴") { return .red }
        if line.contains("🟢") { return .green }
        if line.contains("🔵") { return .blue }
        return .primary
    }
}