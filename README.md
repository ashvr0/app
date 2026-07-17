# TheBus Live

A modern, unofficial SwiftUI replacement for the old TheBus iOS app, built on top of TheBus's official public Web API (Oahu Transit Services, Inc).

This app is not affiliated with or endorsed by Oahu Transit Services, Inc. Route and arrival data is provided by permission of Oahu Transit Services, Inc, per the terms at https://hea.thebus.org/api_info.asp.

## What's included

- SwiftUI app targeting iOS 17+, built with MVVM
- Live arrivals, stop and route search, route details, vehicle tracking on a MapKit map
- Favorites and recently viewed stops, persisted locally
- Pull to refresh, loading/empty/error states throughout
- A settings page with a light/dark/system appearance toggle
- A GitHub Actions workflow that builds the project on macOS runners, since the project is authored on Linux/Windows
- No third party dependencies: networking uses `URLSession` and `XMLParser`, both part of Foundation

## Project structure

```
TheBusLive/
├── project.yml                  XcodeGen spec; generates the .xcodeproj
├── TheBusLive/
│   ├── TheBusLiveApp.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Models/
│   │   ├── Stop.swift
│   │   ├── Route.swift
│   │   ├── Arrival.swift
│   │   └── Vehicle.swift
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   ├── APIConfig.swift
│   │   ├── Endpoints.swift
│   │   └── APIError.swift
│   ├── ViewModels/
│   │   ├── StopViewModel.swift
│   │   ├── RouteViewModel.swift
│   │   └── VehicleMapViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── HomeView.swift
│   │   ├── SearchView.swift
│   │   ├── StopDetailView.swift
│   │   ├── RouteView.swift
│   │   ├── MapView.swift
│   │   ├── FavoritesView.swift
│   │   ├── SettingsView.swift
│   │   ├── StatusView.swift
│   │   ├── ArrivalRow.swift
│   │   └── StopRow.swift
│   └── Storage/
│       └── FavoritesManager.swift
└── .github/workflows/ios-build.yml
```

### Why XcodeGen instead of a committed `.xcodeproj`

Hand-maintained `.xcodeproj` files are XML/plist based, are fragile to merge conflicts, and drift out of sync with the file system easily, especially when a project is edited outside Xcode. Instead, `project.yml` declares the target, sources, and settings; both CI and your local machine run `xcodegen generate` to produce a fresh, correct `.xcodeproj` every time. The generated project is gitignored.

## About TheBus API

TheBus's public Web API (documented at https://hea.thebus.org/api_info.asp) is a **read-only, XML-based** API with three endpoints:

| Endpoint | Purpose |
|---|---|
| `GET http://api.thebus.org/arrivals/?key=API_key&stop=stop_ID` | Live/scheduled arrivals for a stop |
| `GET http://api.thebus.org/vehicle/?key=API_key&num=vehicle_num` | Live position of a specific vehicle |
| `GET http://api.thebus.org/route/?key=API_key&route=route_num` (or `&headsign=text`) | Route lookup by number or headsign text |

There is no dedicated stop search endpoint in the official API. This app ships with a small bundled sample stop list (`Stop.sampleStops`) so search and favorites work out of the box; for full island coverage, bundle TheBus's GTFS `stops.txt` (available from TheBus's developer resources) as a JSON resource and load it in `SearchView` in place of `Stop.sampleStops`.

Because responses are XML, `APIClient.swift` includes a small dependency-free `XMLParser`-based mapper rather than pulling in a third-party XML or JSON library.

## Setup: adding your API key

1. Register for a free AppID at **https://hea.thebus.org/api_info.asp**. Registration requires an email address; OTS uses it to notify you of API changes. Each AppID is limited to 250,000 requests/day by default, and is deleted after 6 months of inactivity.
2. Open `TheBusLive/Networking/APIConfig.swift`.
3. Replace the placeholder:

   ```swift
   static let key = "YOUR_API_KEY"
   ```

   with your actual AppID:

   ```swift
   static let key = "abcd1234-your-real-appid"
   ```
4. Save. No other code changes are required; every request in `APIClient` reads from `APIConfig.key`.

If you build or run without replacing the placeholder, the app will surface a clear "No TheBus API key is configured" error instead of making a doomed network request.

### Attribution requirement

TheBus's Terms of Use require any app displaying their data to show the legend "Route and arrival data provided by permission of Oahu Transit Services, Inc." This is already included as `APIConfig.attributionText` and shown in Home, Route, and Settings screens. Keep it if you fork this project.

## Building locally with Xcode

Requires macOS with Xcode 15.4+ installed.

```bash
brew install xcodegen
cd TheBusLive
xcodegen generate
open TheBusLive.xcodeproj
```

Then select the `TheBusLive` scheme and a simulator or device, and build/run as usual (Cmd+R).

## Building via GitHub Actions

The workflow at `.github/workflows/ios-build.yml` runs on `macos-26` runners and:

1. Selects Xcode 26
2. Installs XcodeGen via Homebrew
3. Generates `TheBusLive.xcodeproj` from `project.yml`
4. Builds the Debug configuration for a generic iOS device (compile check)
5. Archives the Release configuration, unsigned
6. Packages an unsigned `.ipa` (a zipped `Payload/TheBusLive.app`)
7. Uploads both the `.ipa` and the raw `.xcarchive` as workflow artifacts

It triggers on pushes and pull requests to `main`, and can also be run manually from the Actions tab (`workflow_dispatch`).

To get your build artifacts:

1. Push to `main` (or open a PR, or trigger manually).
2. Go to the **Actions** tab in GitHub, open the latest **iOS Build** run.
3. Download the `TheBusLive-unsigned-ipa` artifact.

This `.ipa` is **unsigned**. That's intentional: CI has no access to your Apple ID or signing certificate, and unsigned output is what sideloading tools like SideStore expect you to sign yourself, on your own machine or via SideStore's own signing flow.

## Installing via SideStore

SideStore signs and installs apps using your own free or paid Apple Developer account, refreshing the signature periodically (roughly every 7 days for a free account) similarly to AltStore.

1. Install SideStore on your iPhone/iPad following SideStore's own setup guide (https://sidestore.io), including pairing it with SideServer/AltServer on a companion computer, which is required for the initial install and periodic re-signing.
2. Download `TheBusLive-unsigned-ipa` from the GitHub Actions run (see above) and unzip it if needed so you have a `.ipa` file, or keep it zipped, either works with SideStore's import.
3. Transfer the `.ipa` to your iOS device (AirDrop, Files app, iCloud Drive, or the Share extension, depending on your SideStore version).
4. Open the file with SideStore, or use SideStore's "+" / import button and pick the `.ipa` from Files.
5. SideStore will sign the app with your Apple ID's development certificate and install it, prompting you to trust the developer profile in Settings → General → VPN & Device Management if this is the first app signed with that certificate.
6. Launch TheBus Live from the home screen.

## Known limitations / next steps
- Vehicle tracking polls every 30 seconds while the map is open; TheBus's own AVL data is refreshed roughly once a minute, so this has headroom without over-polling.

## Notes
If you encounter issues, open an issue: [issue](https://github.com/ashvr0/app/issues/new).

This project is licensed under the **GPL** see the [LICENSE](https://github.com/ashvr0/app?tab=GPL-3.0-1-ov-file) file for details.