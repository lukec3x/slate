//
//  TitleTests.swift
//  SlateTests
//

import Testing
@testable import Slate

@MainActor
struct TitleTests {
    @Test func movieDoesNotKeepEpisodeProgress() {
        let movie = Title(tmdbID: 550, kind: .movie, name: "Fight Club", year: 1999, posterPath: nil)

        movie.setProgress(season: 1, episode: 2, name: "Pilot")

        #expect(movie.seasonNumber == nil)
        #expect(movie.episodeNumber == nil)
        #expect(movie.episodeName == nil)
        #expect(movie.progressLabel == nil)
    }

    @Test func seriesKeepsTheEpisodeWhereItStopped() {
        let series = Title(tmdbID: 1396, kind: .series, name: "Breaking Bad", year: 2008, posterPath: nil)

        series.setProgress(season: 2, episode: 5, name: "Breakage")

        #expect(series.seasonNumber == 2)
        #expect(series.episodeNumber == 5)
        #expect(series.episodeName == "Breakage")
        #expect(series.progressLabel == "S2 E5")
    }

    @Test func theSameCatalogTitleIsADuplicate() {
        let existing = Title(tmdbID: 1396, kind: .series, name: "Breaking Bad", year: 2008, posterPath: nil)

        let match = Title.existing(tmdbID: 1396, kind: .series, in: [existing])
        let sameIDDifferentKind = Title.existing(tmdbID: 1396, kind: .movie, in: [existing])

        #expect(match?.name == "Breaking Bad")
        #expect(sameIDDifferentKind == nil)
    }
}
