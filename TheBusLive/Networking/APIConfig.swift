import Foundation
/// Central place for TheBus API configuration.
enum APIConfig {
    /// TheBus API application id (AppID). Replace this placeholder with your registered key.
    static let key = "3D6DF239-6FE0-4FDE-A88D-CA6D0A7881FB"
    static let scheme = "https"
    static let host = "api.thebus.org"
    
    /// TheBus's Terms of Use require this attribution to be shown
    /// wherever route or arrival data appears in the app.
    static let attributionText = "Route and arrival data provided by permission of Oahu Transit Services, Inc."
}
