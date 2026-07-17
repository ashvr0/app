import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @AppStorage("com.thebuslive.preferredColorScheme") private var preferredColorSchemeRaw: String = "system"
    @AppStorage(AppPreferenceKeys.accentColor) private var accentColorRaw: String = AppAccentColor.blue.rawValue
    @AppStorage(AppPreferenceKeys.mapStyle) private var mapStyleRaw: String = AppMapStyleOption.standard.rawValue
    @AppStorage(AppPreferenceKeys.debugModeEnabled) private var debugModeEnabled: Bool = false
    @AppStorage(AppPreferenceKeys.hapticsEnabled) private var hapticsEnabled: Bool = true
    @State private var showingClearRecentsConfirmation = false
    @State private var showingPrivacyDetails = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
 // Changes apperance
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $preferredColorSchemeRaw) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accent Color")
                        HStack(spacing: 12) {
                            ForEach(AppAccentColor.allCases) { option in
                                Button {
                                    accentColorRaw = option.rawValue
                                } label: {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(.primary, lineWidth: accentColorRaw == option.rawValue ? 2 : 0)
                                                .padding(-3)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                                .opacity(accentColorRaw == option.rawValue ? 1 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.displayName)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Picker("Map Style", selection: $mapStyleRaw) {
                        ForEach(AppMapStyleOption.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }

                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                    .onChange(of: hapticsEnabled) { _, newValue in
                        if newValue {
                            HapticsManager.shared.selectionChanged()
                        }
                    }
                }
                // delte recent stops
                Section("Data") {
                    Button(role: .destructive) {
                        showingClearRecentsConfirmation = true
                    } label: {
                        Label("Clear recent stops", systemImage: "clock.arrow.circlepath")
                    }
                }
                // About section
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: "https://hea.thebus.org/api_info.asp")!) {
                        Label("TheBus API registration", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://www.thebus.org")!) {
                        Label("TheBus website", systemImage: "safari")
                    }
                    Link(destination: URL(string: "https://github.com/ashvr0")!) {
                        Label("Made by ashvr0", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) {
                        Label("Free forever, GPLv3 licensed", systemImage: "checkmark.seal")
                    }
                    Button {
                        showingPrivacyDetails = true
                    } label: {
                        HStack {
                            Label("No data collected", systemImage: "hand.raised")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    Text(APIConfig.attributionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Developer") {
                    Toggle(isOn: $debugModeEnabled) {
                        Label("Debug Mode", systemImage: "ladybug")
                    }
                    if debugModeEnabled {
                        Text("Shows route-matching diagnostics on the vehicle tracking screen (vehicle's route name, stop counts, and match totals). Intended for troubleshooting missing stop pins.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Clear all recently viewed stops?",
                isPresented: $showingClearRecentsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Recents", role: .destructive) {
                    HapticsManager.shared.warning()
                    favoritesManager.clearRecents()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingPrivacyDetails) {
                PrivacyDetailsView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

/// A short, plain-language explanation of the app's data practices,
/// shown from the "No data collected" row in Settings. Kept as a
/// dedicated view (rather than an alert) since alerts truncate long
/// text and don't scroll well.
private struct PrivacyDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Point: Identifiable {
        let id = UUID()
        let systemImage: String
        let title: String
        let detail: String
    }

    private let points: [Point] = [
        Point(
            systemImage: "hand.raised.fill",
            title: "No data collected",
            detail: "This app doesn't collect, log, or transmit any analytics, usage data, or personal information about you."
        ),
        Point(
            systemImage: "iphone",
            title: "Everything stays on your device",
            detail: "Favorites and recently viewed stops are stored locally on your device only, using standard iOS storage. They're never uploaded anywhere."
        ),
        Point(
            systemImage: "person.2.slash",
            title: "No third parties",
            detail: "There are no third-party analytics SDKs, ad networks, or trackers built into this app."
        ),
        Point(
            systemImage: "network",
            title: "Network requests",
            detail: "The only network calls this app makes are directly to TheBus's official Web API (api.thebus.org), to fetch live arrivals, routes, and vehicle positions. No request is routed through any other server."
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(points) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: point.systemImage)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(point.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Text("Our promise: this will always be a free, open source app with no ads and no data collection. If that ever changes, it'll be called out clearly here, not buried in fine print.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(FavoritesManager())
}