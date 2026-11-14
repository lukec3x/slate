//
//  SearchTests.swift
//  SlateTests
//

import Testing
@testable import Slate

@MainActor
struct SearchTests {
    @Test func savedMatchesComeBeforeUnsavedCatalogHits() {
        let fightClub = Title(tmdbID: 550, kind: .movie, name: "Fight Club", year: 1999, posterPath: nil)
        let theFight = Title(tmdbID: 680, kind: .movie, name: "The Fight", year: 2018, posterPath: nil)
        let pulp = Title(tmdbID: 680, kind: .series, name: "Pulp Fiction", year: 1994, posterPath: nil)
        let catalog = [
            CatalogResult(tmdbID: 550, kind: .movie, name: "Fight Club", year: 1999, posterPath: "/p.jpg"),
            CatalogResult(tmdbID: 77, kind: .movie, name: "Fight Song", year: 2001, posterPath: nil),
        ]

        let hits = WatchlistSearch.hits(
            query: "fight",
            category: .all,
            titles: [fightClub, theFight, pulp],
            catalog: catalog
        )

        #expect(labels(hits) == [
            "saved:Fight Club",
            "saved:The Fight",
            "catalog:Fight Song",
        ])
    }

    @Test func aSavedTitleOutsideTheCategoryIsNotListedAsNew() {
        let watching = Title(
            tmdbID: 1396,
            kind: .series,
            name: "Breaking Bad",
            year: 2008,
            posterPath: nil,
            status: .watching
        )
        let catalog = [
            CatalogResult(tmdbID: 1396, kind: .series, name: "Breaking Bad", year: 2008, posterPath: "/b.jpg"),
        ]

        let hits = WatchlistSearch.hits(
            query: "break",
            category: .want,
            titles: [watching],
            catalog: catalog
        )

        #expect(hits.isEmpty)
    }

    @Test func anEmptyQueryReturnsTheWholeCategory() {
        let dune = Title(tmdbID: 438631, kind: .movie, name: "Dune", year: 2021, posterPath: nil, status: .want)
        let alien = Title(tmdbID: 348, kind: .movie, name: "Alien", year: 1979, posterPath: nil, status: .watched)

        let hits = WatchlistSearch.hits(
            query: "  ",
            category: .want,
            titles: [dune, alien],
            catalog: []
        )

        #expect(labels(hits) == ["saved:Dune"])
    }

    @Test func highlightAndCategoryStopAtTheEnds() {
        #expect(WatchlistSearch.highlight(current: 0, count: 3, movingBy: -1) == 0)
        #expect(WatchlistSearch.highlight(current: 1, count: 3, movingBy: 1) == 2)
        #expect(WatchlistSearch.highlight(current: 2, count: 3, movingBy: 1) == 2)
        #expect(WatchlistSearch.highlight(current: 0, count: 0, movingBy: 1) == nil)

        #expect(WatchlistSearch.category(.all, movingBy: -1) == .all)
        #expect(WatchlistSearch.category(.watching, movingBy: 1) == .want)
        #expect(WatchlistSearch.category(.want, movingBy: -1) == .watching)
        #expect(WatchlistSearch.category(.watched, movingBy: 1) == .watched)
    }

    private func labels(_ hits: [WatchlistHit]) -> [String] {
        hits.map { hit in
            switch hit {
            case .saved(let title): "saved:\(title.name)"
            case .catalog(let result): "catalog:\(result.name)"
            }
        }
    }
}
