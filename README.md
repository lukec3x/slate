# Slate

Native Apple app for a personal watchlist of movies and series.

Track titles you want to watch, titles you have already watched, and, for a series, the episode where you stopped.

## Status

The watchlist is not built yet. The project is still the Xcode SwiftUI and SwiftData template: a list of timestamped items. That sample is the starting point, not the product.

## Requirements

- Xcode with the iOS 27.2, macOS 26.7, and visionOS 27.2 SDKs
- Swift 5

Slate runs on iPhone, iPad, Mac, and visionOS.

## Run

Open `Slate.xcodeproj` and run the `Slate` scheme. Pick an iOS, macOS, or visionOS destination.

`SlateTests` uses Swift Testing. `SlateUITests` uses XCTest. Run them from Xcode with the matching scheme.

## Layout

- `Slate/` — app target. `SlateApp` owns the SwiftData container. `Item` and `ContentView` are still the template.
- `SlateTests/` — unit tests
- `SlateUITests/` — UI tests
- `AGENTS.md` — instructions for coding agents working in this repo

User-facing copy is English. Data stays on device through SwiftData.
