import SwiftUI
import SafariServices

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SettingsView: View {

    @EnvironmentObject private var favoritesManager: FavoritesManager
    @AppStorage("com.thebuslive.preferredColorScheme") private var preferredColorSchemeRaw: String = "system"
    @AppStorage(AppPreferenceKeys.accentColor) private var accentColorRaw: String = AppAccentColor.blue.rawValue
    @AppStorage(AppPreferenceKeys.mapStyle) private var mapStyleRaw: String = AppMapStyleOption.standard.rawValue
    @AppStorage(AppPreferenceKeys.debugModeEnabled) private var debugModeEnabled: Bool = false
    @AppStorage(AppPreferenceKeys.hapticsEnabled) private var hapticsEnabled: Bool = true
    @AppStorage(AppPreferenceKeys.apiKey) private var apiKey: String = ""
    @State private var showingClearRecentsConfirmation = false
    @State private var showingPrivacyDetails = false
    @State private var showingAPIKeyInfo = false
    @State private var showingMissingKeyAlert = false
    @State private var showingDebugConsole = false
    @State private var selectedURL: IdentifiableURL?
    @FocusState private var apiKeyFieldFocused: Bool

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

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
                        Label {
                            Text("Haptic Feedback")
                        } icon: {
                            Image(systemName: hapticsEnabled ? "hand.tap.fill" : "hand.tap")
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .onChange(of: hapticsEnabled) { _, newValue in
                        if newValue {
                            HapticsManager.shared.selectionChanged()
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("Paste your TheBus API key", text: $apiKey)
                            .focused($apiKeyFieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                        if !apiKey.isEmpty {
                            Button {
                                apiKey = ""
                                apiKeyFieldFocused = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("TheBus API Key (Required)")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Required. The app can't fetch arrivals, routes, or vehicles without your own key.")
                        Text("Each key is limited to 250,000 requests/day by TheBus, so use your own key rather than sharing one — a shared key can run out for everyone.")
                        Button("Get your own key") {
                            showingAPIKeyInfo = true
                        }
                        .font(.caption)
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showingClearRecentsConfirmation = true
                    } label: {
                        Label("Clear recent stops", systemImage: "clock.arrow.circlepath")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Button {
                        if let url = URL(string: "https://api.thebus.org/NewAccount/") {
                            selectedURL = IdentifiableURL(url: url)
                        }
                    } label: {
                        Label("TheBus API registration", systemImage: "link")
                    }
                    Button {
                        if let url = URL(string: "https://www.thebus.org") {
                            selectedURL = IdentifiableURL(url: url)
                        }
                    } label: {
                        Label("TheBus website", systemImage: "safari")
                    }
                    Button {
                        if let url = URL(string: "https://github.com/ashvr0") {
                            selectedURL = IdentifiableURL(url: url)
                        }
                    } label: {
                        Label("Made by ashvr0", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Button {
                        if let url = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html") {
                            selectedURL = IdentifiableURL(url: url)
                        }
                    } label: {
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

                        Button {
                            showingDebugConsole = true
                        } label: {
                            Label("Debug Console", systemImage: "terminal")
                        }
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
            .sheet(isPresented: $showingDebugConsole) {
                DebugConsoleView()
            }
            .sheet(item: $selectedURL) { identifiableURL in
                SafariView(url: identifiableURL.url)
            }
            .alert("Get your own API key", isPresented: $showingAPIKeyInfo) {
                Button("OK") {}
            } message: {
                Text("Register for a free key at hea.thebus.org (see the link under About), then paste it here.")
            }
            .alert("API Key Not Detected", isPresented: $showingMissingKeyAlert) {
                Button("OK") {}
            } message: {
                Text("An API key is required for this app to work. Get your own free key at hea.thebus.org and paste it above.")
            }
            .onAppear {
                if !APIConfig.hasKey {
                    showingMissingKeyAlert = true
                }
            }
        }
    }
}

/// Presents a URL in an in-app Safari sheet rather than switching to the
/// standalone Safari app, so the user stays inside TheBus Live.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}

/// A short, plain-language explanation of the app's data practices,
/// shown from the "No data collected" row in Settings.
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
            detail: "Favorites, recent stops, preferences, and app settings are stored locally on your device only, using standard iOS storage. They're never uploaded anywhere."
        ),
        Point(
            systemImage: "person.2.slash",
            title: "No tracking or third parties",
            detail: "This app contains no analytics SDKs, advertising networks, user tracking tools, or data brokers."
        ),
        Point(
            systemImage: "network",
            title: "Direct connection to TheBus",
            detail: "Transit information is fetched directly from TheBus's official Web API. Requests are not routed through our servers and are not used to build a user profile."
        ),
        Point(
            systemImage: "lock.shield",
            title: "Your API key stays private",
            detail: "Your TheBus API key is stored securely on your device and is only used to request transit data from TheBus."
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
                    Text("Our promise: this app will remain free, open source, and free of ads and tracking. Any future privacy related changes will be clearly explained here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("Privacy statement last updated: July 16, 2026.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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