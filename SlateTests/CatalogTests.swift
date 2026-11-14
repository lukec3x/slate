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

    @Test func seriesDetailReadsTheFactsAndSeasons() throws {
        let detail = try CatalogDecoder.series(from: Data(Self.seriesFixture.utf8))

        #expect(detail == SeriesDetail(
            overview: "A chemistry teacher cooks.",
            tagline: "Change the equation.",
            backdropPath: "/backdrop.jpg",
            genres: ["Drama", "Crime"],
            status: "Ended",
            firstAirDate: "2008-01-20",
            lastAirDate: "2013-09-29",
            episodeRuntimes: [47],
            numberOfSeasons: 5,
            numberOfEpisodes: 62,
            networks: ["AMC"],
            originCountries: ["US"],
            originalLanguage: "en",
            voteAverage: 8.5,
            voteCount: 14000,
            creators: ["Vince Gilligan"],
            nextEpisode: AiredEpisode(
                name: "Pilot",
                seasonNumber: 1,
                episodeNumber: 1,
                airDate: "2008-01-20"
            ),
            lastEpisode: AiredEpisode(
                name: "Felina",
                seasonNumber: 5,
                episodeNumber: 16,
                airDate: "2013-09-29"
            ),
            seasons: [
                TMDBSeason(
                    id: 3573,
                    seasonNumber: 0,
                    name: "Specials",
                    episodeCount: 11,
                    airDate: nil,
                    posterPath: nil,
                    overview: nil
                ),
                TMDBSeason(
                    id: 3572,
                    seasonNumber: 1,
                    name: "Season 1",
                    episodeCount: 7,
                    airDate: "2008-01-20",
                    posterPath: "/s1.jpg",
                    overview: "The first cook."
                ),
            ]
        ))
    }

    @Test func seasonEpisodesKeepStillsAndDropBlankOverviews() throws {
        let episodes = try CatalogDecoder.episodes(from: Data(Self.seasonFixture.utf8))

        #expect(episodes == [
            TMDBEpisode(
                id: 62085,
                episodeNumber: 1,
                name: "Pilot",
                seasonNumber: 1,
                stillPath: "/still.jpg",
                overview: "Walter cooks.",
                airDate: "2008-01-20",
                runtime: 58
            ),
            TMDBEpisode(
                id: 62086,
                episodeNumber: 2,
                name: "Cat's in the Bag...",
                seasonNumber: 1,
                stillPath: nil,
                overview: nil,
                airDate: nil,
                runtime: nil
            ),
        ])
    }

    @Test func movieDetailReadsTheReleaseFactsAndCollection() throws {
        let detail = try CatalogDecoder.movie(from: Data(Self.movieFixture.utf8))

        #expect(detail == MovieDetail(
            overview: "An insomniac meets a soap salesman.",
            tagline: "Mischief. Mayhem. Soap.",
            backdropPath: "/m.jpg",
            genres: ["Drama"],
            releaseDate: "1999-10-15",
            runtime: 139,
            status: "Released",
            voteAverage: 8.5,
            voteCount: 28000,
            countries: ["United States of America"],
            originalLanguage: "en",
            collectionName: "Fight Club Collection"
        ))
    }

    @Test func movieDetailWithoutACollectionKeepsTheOriginCountry() throws {
        let detail = try CatalogDecoder.movie(from: Data(Self.movieWithoutCollectionFixture.utf8))

        #expect(detail.overview == nil)
        #expect(detail.tagline == nil)
        #expect(detail.backdropPath == nil)
        #expect(detail.genres == [])
        #expect(detail.runtime == nil)
        #expect(detail.countries == ["JP"])
        #expect(detail.collectionName == nil)
        #expect(detail.voteCount == 0)
    }

    @Test func imageURLsUseTheSizeThatFitsTheFrame() {
        #expect(TMDBImage.url(path: "/p.jpg")?.absoluteString == "https://image.tmdb.org/t/p/w185/p.jpg")
        #expect(TMDBImage.url(path: "/b.jpg", width: .backdrop)?.absoluteString == "https://image.tmdb.org/t/p/w780/b.jpg")
        #expect(TMDBImage.url(path: "/s.jpg", width: .still)?.absoluteString == "https://image.tmdb.org/t/p/w300/s.jpg")
        #expect(TMDBImage.url(path: "") == nil)
        #expect(TMDBImage.url(path: nil) == nil)
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

    private static let seriesFixture = """
    {
      "backdrop_path": "/backdrop.jpg",
      "created_by": [
        {"id": 1, "name": "Vince Gilligan"},
        {"id": 2, "name": "  "}
      ],
      "episode_run_time": [47],
      "first_air_date": "2008-01-20",
      "genres": [
        {"id": 18, "name": "Drama"},
        {"id": 80, "name": "Crime"}
      ],
      "last_air_date": "2013-09-29",
      "last_episode_to_air": {
        "name": "Felina",
        "air_date": "2013-09-29",
        "episode_number": 16,
        "season_number": 5
      },
      "name": "Breaking Bad",
      "next_episode_to_air": {
        "name": "Pilot",
        "air_date": "2008-01-20",
        "episode_number": 1,
        "season_number": 1
      },
      "networks": [
        {"id": 174, "name": "AMC", "origin_country": "US"}
      ],
      "number_of_episodes": 62,
      "number_of_seasons": 5,
      "origin_country": ["US"],
      "original_language": "en",
      "overview": "A chemistry teacher cooks.",
      "recommendations": {"results": []},
      "seasons": [
        {
          "air_date": "2008-01-20",
          "episode_count": 7,
          "id": 3572,
          "name": "Season 1",
          "overview": "The first cook.",
          "poster_path": "/s1.jpg",
          "season_number": 1
        },
        {
          "air_date": "",
          "episode_count": 11,
          "id": 3573,
          "name": "Specials",
          "overview": "",
          "poster_path": null,
          "season_number": 0
        }
      ],
      "status": "Ended",
      "tagline": "Change the equation.",
      "vote_average": 8.5,
      "vote_count": 14000
    }
    """

    private static let seasonFixture = """
    {
      "episodes": [
        {
          "air_date": "",
          "episode_number": 2,
          "id": 62086,
          "name": "Cat's in the Bag...",
          "overview": "  ",
          "runtime": null,
          "season_number": 1,
          "still_path": "",
          "crew": [{"name": "Vince Gilligan"}]
        },
        {
          "air_date": "2008-01-20",
          "episode_number": 1,
          "id": 62085,
          "name": "Pilot",
          "overview": "Walter cooks.",
          "runtime": 58,
          "season_number": 1,
          "still_path": "/still.jpg"
        }
      ]
    }
    """

    private static let movieFixture = """
    {
      "backdrop_path": "/m.jpg",
      "belongs_to_collection": {
        "id": 10,
        "name": "Fight Club Collection",
        "poster_path": null
      },
      "budget": 63000000,
      "genres": [{"id": 18, "name": "Drama"}],
      "id": 550,
      "origin_country": ["US"],
      "original_language": "en",
      "overview": "An insomniac meets a soap salesman.",
      "production_countries": [{"iso_3166_1": "US", "name": "United States of America"}],
      "release_date": "1999-10-15",
      "runtime": 139,
      "status": "Released",
      "tagline": "Mischief. Mayhem. Soap.",
      "title": "Fight Club",
      "vote_average": 8.5,
      "vote_count": 28000
    }
    """

    private static let movieWithoutCollectionFixture = """
    {
      "backdrop_path": null,
      "belongs_to_collection": null,
      "genres": [],
      "original_language": "ja",
      "overview": "",
      "origin_country": ["JP"],
      "production_countries": [],
      "release_date": "1954-04-26",
      "runtime": null,
      "status": "Released",
      "tagline": "",
      "vote_average": 0,
      "vote_count": 0
    }
    """
}
