# Slate

Native Apple app for a personal watchlist of movies and series.

Track titles you want to watch, titles you are watching, and titles you have already watched. For a series, Slate also stores the episode where you stopped.

## Status

The library is on device. Search uses [TMDB](https://www.themoviedb.org/) to add a movie or series. Slate does not have accounts, sync, or recommendations.

This product uses the TMDB API but is not endorsed or certified by TMDB.

## Requirements

- Xcode with the iOS 27.2, macOS 26.7, and visionOS 27.2 SDKs
- Swift 5
- A TMDB read access token

Slate runs on iPhone, iPad, Mac, and visionOS.

## TMDB token

1. Create a read access token at [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api).
2. Copy `Secrets.example.plist` to `Slate/Secrets.plist`.
3. Set `TMDBReadAccessToken` to that token.

`Slate/Secrets.plist` stays out of git. Without it, the library still opens and search explains how to add the token.

## Run

Open `Slate.xcodeproj` and run the `Slate` scheme. Pick an iOS, macOS, or visionOS destination.

`SlateTests` uses Swift Testing. `SlateUITests` uses XCTest. Run them from Xcode with the matching scheme.

## Layout

- `Slate/SlateApp.swift` — app entry and SwiftData container
- `Slate/Title.swift` — watchlist model
- `Slate/LibraryView.swift` — dark poster grid of the watchlist
- `Slate/SearchView.swift` — search saved titles and TMDB
- `Slate/TitleDetailView.swift` — status and, for a series, the episode where you stopped
- `Slate/Catalog.swift` — TMDB client
- `SlateTests/` — unit tests that do not call the network
- `AGENTS.md` — instructions for coding agents working in this repo

User-facing copy is English. Saved titles stay on device through SwiftData.
