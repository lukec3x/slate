# Slate

Instructions for coding agents working in this repository.

## Product

Slate is a native Apple app for a personal watchlist of movies and series.

The owner tracks:

- titles they want to watch
- titles they have already watched
- for a series, the episode where they stopped

The Xcode template (`Item` with a timestamp) is still in the tree. Replace it with the watchlist domain. Do not keep the sample list as the product.

Stay inside that scope until the owner expands it. Do not add catalogs, recommendations, accounts, or sync on your own.

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
- Mac uses `NavigationSplitView`. The other platforms use `NavigationStack`. Keep that split when adding screens.

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
- `Slate/ContentView.swift` — template list, still the sample UI
- `Slate/Item.swift` — template model, still the sample domain
- `SlateTests/` — unit tests, still the Xcode stub
- `SlateUITests/` — UI tests, still the Xcode stub
