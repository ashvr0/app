import Foundation

/// Central place for TheBus API configuration.
enum APIConfig {
    /// The user's registered TheBus API key, entered in Settings.
    /// TheBus limits each key to 250,000 requests/day, so every
    // install needs its own key rather than sharing one baked into the app.
    static var key: String {
        UserDefaults.standard.string(forKey: AppPreferenceKeys.apiKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var hasKey: Bool {
        !key.isEmpty
    }

    static let scheme = "https"
    static let host = "api.thebus.org"

    /// TheBus's Terms of Use require this attribution to be shown 
    /// wherever route or arrival data appears in the app.
    static let attributionText = "Route and arrival data provided by permission of Oahu Transit Services, Inc."
}