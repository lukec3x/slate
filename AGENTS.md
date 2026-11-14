# Slate

Instructions for coding agents working in this repository.

## Product

Slate is a native Apple app for a personal watchlist of movies and series.

The owner tracks:

- titles they want to watch
- titles they are watching
- titles they have already watched
- for a series, the episode where they stopped

Titles are added from TMDB search and then stored on device. Do not add recommendations, accounts, or sync. Do not browse the catalog beyond search, season, and episode lookup.

## Language

English is the language of the repository:

- source code, identifiers, and comments
- user-facing copy
- commit messages and branch names
- documentation, including this file

Conversation with the owner may be in Portuguese. That language stays in chat. It does not enter the repo.

## Platform

- SwiftUI and SwiftData. The model container lives in `SlateApp`.
- Swift 5, with `MainActor` as the default actor isolation.
- iPhone, iPad, Mac, and visionOS (`TARGETED_DEVICE_FAMILY` 1, 2, 7).
- Deployment targets in the project: iOS 27.2, macOS 26.7, visionOS 27.2.
- Bundle identifier: `br.dev.lucasandrade.Slate`.
- Marketing version `1.0` (`MARKETING_VERSION`), build `1` (`CURRENT_PROJECT_VERSION`).
- Development localization: English. User-facing strings go through the String Catalog (`SWIFT_EMIT_LOC_STRINGS` is enabled).
- Unit tests use Swift Testing in `SlateTests`. UI tests use XCTest in `SlateUITests`.
- The interface is a dark, poster-first watchlist on every platform, in one `NavigationStack`. Filter chips narrow the grid. Do not bring back a segmented control or a split-view sidebar for the library.
- The Mac target keeps the App Sandbox and `ENABLE_OUTGOING_NETWORK_CONNECTIONS`. Search and posters need that outgoing client entitlement.
- The TMDB read access token lives in `Slate/Secrets.plist` under `TMDBReadAccessToken`. That file is gitignored. `Secrets.example.plist` is the committed template. Search must show the TMDB attribution line.

Prefer system controls and SF Symbols. Add a third-party dependency only when the owner asks for it.

## Working on the code

- Persist the watchlist with SwiftData.
- When behavior changes, add or update a Swift Testing test in `SlateTests`. Use a UI test only for a flow that needs a launched app.
- Do not commit secrets, provisioning profiles, or `xcuserdata`.

## Git

Release train. `main` is always shippable. There is no long-lived `develop` branch.

Day-to-day work goes on a short-lived branch cut from `main`:

- `feature/<short-description>` — product work. Example: `feature/episode-progress`
- `release/<marketing-version>` — cut only to stabilize a TestFlight or App Store version. Example: `release/1.1`. Only bug fixes and the version bump land here. Merge back into `main`.
- `hotfix/<marketing-version>` — cut from the tag of a shipped version when `main` has already moved on. Example: `hotfix/1.0.1`. Merge back into `main`.

Branch names are English, lowercase, and hyphenated. Do not commit product work directly on `main`.

Tag the commit that matches a submitted build: `v1.1.0`. The tag matches `MARKETING_VERSION`. Bump `CURRENT_PROJECT_VERSION` on each archive meant for TestFlight or the App Store. Change `MARKETING_VERSION` only on a `release/*` or `hotfix/*` branch.

Commit messages follow the style of Apple's open-source repositories. Imperative subject, no type prefix, no trailing period. A blank line, then a body that says why. English.

```
Add the episode where a series was left off

The watchlist has to remember a stop point separately from
the watched flag.
```

## Layout

- `Slate/SlateApp.swift` — app entry and SwiftData container
- `Slate/Title.swift` — watchlist model
- `Slate/LibraryView.swift` — dark poster grid with All, Watching, Want, and Watched chips
- `Slate/SearchView.swift` — one popup to find a saved title and add from TMDB. `/` opens it from the watchlist when a text field is not focused.
- `Slate/TitleDetailView.swift` — status and series progress
- `Slate/Catalog.swift` — TMDB client and response decoding
- `SlateTests/` — unit tests, no network
- `SlateUITests/` — launch UI tests
