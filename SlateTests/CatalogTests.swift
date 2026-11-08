//
//  CatalogTests.swift
//  SlateTests
//

import Foundation
import Testing
@testable import Slate

struct CatalogTests {
    @Test func searchDropsPeopleAndReadsTheYear() throws {
        let results = try CatalogDecoder.searchResults(from: Data(Self.fixture.utf8))

        #expect(results == [
            CatalogResult(
                tmdbID: 550,
                kind: .movie,
                name: "Fight Club",
                year: 1999,
                posterPath: "/p.jpg"
            ),
            CatalogResult(
                tmdbID: 1396,
                kind: .series,
                name: "Breaking Bad",
                year: 2008,
                posterPath: "/b.jpg"
            ),
        ])
    }

    private static let fixture = """
    {
      "results": [
        {
          "id": 550,
          "media_type": "movie",
          "title": "Fight Club",
          "poster_path": "/p.jpg",
          "release_date": "1999-10-15"
        },
        {
          "id": 1396,
          "media_type": "tv",
          "name": "Breaking Bad",
          "poster_path": "/b.jpg",
          "first_air_date": "2008-01-20"
        },
        {
          "id": 819,
          "media_type": "person",
          "name": "Edward Norton"
        }
      ]
    }
    """
}
