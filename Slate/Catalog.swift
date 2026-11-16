//
//  Catalog.swift
//  Slate
//

import Foundation

nonisolated struct CatalogResult: Identifiable, Equatable {
    var tmdbID: Int
    var kind: TitleKind
    var name: String
    var year: Int?
    var posterPath: String?

    var id: String { "\(kind.rawValue)-\(tmdbID)" }
}

nonisolated struct SeriesDetail: Equatable {
    var overview: String?
    var tagline: String?
    var backdropPath: String?
    var genres: [String]
    var status: String?
    var firstAirDate: String?
    var lastAirDate: String?
    var episodeRuntimes: [Int]
    var numberOfSeasons: Int?
    var numberOfEpisodes: Int?
    var networks: [String]
    var originCountries: [String]
    var originalLanguage: String?
    var voteAverage: Double?
    var voteCount: Int?
    var creators: [String]
    var nextEpisode: AiredEpisode?
    var lastEpisode: AiredEpisode?
    var seasons: [TMDBSeason]
}

nonisolated struct AiredEpisode: Equatable {
    var name: String
    var seasonNumber: Int
    var episodeNumber: Int
    var airDate: String?
}

nonisolated struct MovieDetail: Equatable {
    var overview: String?
    var tagline: String?
    var backdropPath: String?
    var genres: [String]
    var releaseDate: String?
    var runtime: Int?
    var status: String?
    var voteAverage: Double?
    var voteCount: Int?
    var countries: [String]
    var originalLanguage: String?
    var collectionName: String?
}

nonisolated struct TMDBSeason: Identifiable, Equatable, Decodable {
    var id: Int
    var seasonNumber: Int
    var name: String
    var episodeCount: Int
    var airDate: String?
    var posterPath: String?
    var overview: String?
}

nonisolated struct TMDBEpisode: Identifiable, Equatable, Decodable {
    var id: Int
    var episodeNumber: Int
    var name: String
    var seasonNumber: Int
    var stillPath: String?
    var overview: String?
    var airDate: String?
    var runtime: Int?
}

nonisolated enum TMDBError: Error {
    case badResponse
    case badStatus(Int)
}

nonisolated enum TMDBImage {
    nonisolated enum Width: String {
        case poster = "w185"
        case backdrop = "w780"
        case still = "w300"
    }

    static func url(path: String?, width: Width = .poster) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(width.rawValue)\(path)")
    }
}

nonisolated enum CatalogDecoder {
    static func searchResults(from data: Data) throws -> [CatalogResult] {
        let response = try decoder.decode(TMDBSearchResponse.self, from: data)
        return response.results.compactMap(CatalogResult.init(item:))
    }

    static func series(from data: Data) throws -> SeriesDetail {
        let payload = try decoder.decode(TMDBSeriesPayload.self, from: data)
        let seasons = (payload.seasons ?? []).map(season).sorted { $0.seasonNumber < $1.seasonNumber }
        return SeriesDetail(
            overview: text(payload.overview),
            tagline: text(payload.tagline),
            backdropPath: text(payload.backdropPath),
            genres: names(payload.genres),
            status: text(payload.status),
            firstAirDate: text(payload.firstAirDate),
            lastAirDate: text(payload.lastAirDate),
            episodeRuntimes: payload.episodeRunTime ?? [],
            numberOfSeasons: payload.numberOfSeasons,
            numberOfEpisodes: payload.numberOfEpisodes,
            networks: names(payload.networks),
            originCountries: texts(payload.originCountry),
            originalLanguage: text(payload.originalLanguage),
            voteAverage: payload.voteAverage,
            voteCount: payload.voteCount,
            creators: names(payload.createdBy),
            nextEpisode: aired(payload.nextEpisodeToAir),
            lastEpisode: aired(payload.lastEpisodeToAir),
            seasons: seasons
        )
    }

    static func movie(from data: Data) throws -> MovieDetail {
        let payload = try decoder.decode(TMDBMoviePayload.self, from: data)
        let namedCountries = names(payload.productionCountries)
        return MovieDetail(
            overview: text(payload.overview),
            tagline: text(payload.tagline),
            backdropPath: text(payload.backdropPath),
            genres: names(payload.genres),
            releaseDate: text(payload.releaseDate),
            runtime: payload.runtime,
            status: text(payload.status),
            voteAverage: payload.voteAverage,
            voteCount: payload.voteCount,
            countries: namedCountries.isEmpty ? texts(payload.originCountry) : namedCountries,
            originalLanguage: text(payload.originalLanguage),
            collectionName: text(payload.belongsToCollection?.name)
        )
    }

    static func episodes(from data: Data) throws -> [TMDBEpisode] {
        let response = try decoder.decode(TMDBSeasonDetails.self, from: data)
        return response.episodes.map(episode).sorted { $0.episodeNumber < $1.episodeNumber }
    }

    private static func season(_ season: TMDBSeason) -> TMDBSeason {
        TMDBSeason(
            id: season.id,
            seasonNumber: season.seasonNumber,
            name: season.name,
            episodeCount: season.episodeCount,
            airDate: text(season.airDate),
            posterPath: text(season.posterPath),
            overview: text(season.overview)
        )
    }

    private static func episode(_ episode: TMDBEpisode) -> TMDBEpisode {
        TMDBEpisode(
            id: episode.id,
            episodeNumber: episode.episodeNumber,
            name: episode.name,
            seasonNumber: episode.seasonNumber,
            stillPath: text(episode.stillPath),
            overview: text(episode.overview),
            airDate: text(episode.airDate),
            runtime: episode.runtime
        )
    }

    private static func aired(_ episode: TMDBAiredEpisode?) -> AiredEpisode? {
        guard let episode, let seasonNumber = episode.seasonNumber, let episodeNumber = episode.episodeNumber else {
            return nil
        }
        return AiredEpisode(
            name: text(episode.name) ?? "",
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            airDate: text(episode.airDate)
        )
    }

    private static func names(_ values: [TMDBName]?) -> [String] {
        texts(values?.map(\.name))
    }

    private static func texts(_ values: [String]?) -> [String] {
        (values ?? []).compactMap(text)
    }

    private static func text(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

nonisolated struct TMDBClient {
    var token: String
    var session: URLSession = .shared

    func search(query: String) async throws -> [CatalogResult] {
        let data = try await fetch(
            path: "search/multi",
            query: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "include_adult", value: "false"),
                language
            ]
        )
        return try CatalogDecoder.searchResults(from: data)
    }

    func series(seriesID: Int) async throws -> SeriesDetail {
        let data = try await fetch(path: "tv/\(seriesID)", query: [language])
        return try CatalogDecoder.series(from: data)
    }

    func movie(movieID: Int) async throws -> MovieDetail {
        let data = try await fetch(path: "movie/\(movieID)", query: [language])
        return try CatalogDecoder.movie(from: data)
    }

    func episodes(seriesID: Int, season: Int) async throws -> [TMDBEpisode] {
        let data = try await fetch(path: "tv/\(seriesID)/season/\(season)", query: [language])
        return try CatalogDecoder.episodes(from: data)
    }

    private var language: URLQueryItem {
        URLQueryItem(name: "language", value: "en-US")
    }

    private func fetch(path: String, query: [URLQueryItem]) async throws -> Data {
        guard var components = URLComponents(string: "https://api.themoviedb.org/3/\(path)") else {
            throw TMDBError.badResponse
        }
        components.queryItems = query
        guard let url = components.url else { throw TMDBError.badResponse }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse }
        guard (200...299).contains(http.statusCode) else { throw TMDBError.badStatus(http.statusCode) }
        return data
    }
}

enum TMDBCredentials {
    private static let placeholder = "YOUR_TMDB_READ_ACCESS_TOKEN"

    static var token: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let token = plist["TMDBReadAccessToken"] as? String
        else { return nil }

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != placeholder else { return nil }
        return trimmed
    }

    static var client: TMDBClient? {
        guard let token else { return nil }
        return TMDBClient(token: token)
    }
}

private nonisolated struct TMDBSearchResponse: Decodable {
    var results: [TMDBSearchItem]
}

private nonisolated struct TMDBSearchItem: Decodable {
    var id: Int
    var mediaType: String?
    var title: String?
    var name: String?
    var posterPath: String?
    var releaseDate: String?
    var firstAirDate: String?
}

private nonisolated struct TMDBSeriesPayload: Decodable {
    var overview: String?
    var tagline: String?
    var backdropPath: String?
    var genres: [TMDBName]?
    var status: String?
    var firstAirDate: String?
    var lastAirDate: String?
    var episodeRunTime: [Int]?
    var numberOfSeasons: Int?
    var numberOfEpisodes: Int?
    var networks: [TMDBName]?
    var originCountry: [String]?
    var originalLanguage: String?
    var voteAverage: Double?
    var voteCount: Int?
    var createdBy: [TMDBName]?
    var nextEpisodeToAir: TMDBAiredEpisode?
    var lastEpisodeToAir: TMDBAiredEpisode?
    var seasons: [TMDBSeason]?
}

private nonisolated struct TMDBMoviePayload: Decodable {
    var overview: String?
    var tagline: String?
    var backdropPath: String?
    var genres: [TMDBName]?
    var releaseDate: String?
    var runtime: Int?
    var status: String?
    var voteAverage: Double?
    var voteCount: Int?
    var productionCountries: [TMDBName]?
    var originCountry: [String]?
    var originalLanguage: String?
    var belongsToCollection: TMDBCollection?
}

private nonisolated struct TMDBName: Decodable {
    var name: String
}

private nonisolated struct TMDBCollection: Decodable {
    var name: String?
}

private nonisolated struct TMDBAiredEpisode: Decodable {
    var name: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var airDate: String?
}

private nonisolated struct TMDBSeasonDetails: Decodable {
    var episodes: [TMDBEpisode]
}

private nonisolated extension CatalogResult {
    init?(item: TMDBSearchItem) {
        switch item.mediaType {
        case "movie":
            guard let name = item.title, !name.isEmpty else { return nil }
            self.init(
                tmdbID: item.id,
                kind: .movie,
                name: name,
                year: Self.year(from: item.releaseDate),
                posterPath: item.posterPath
            )
        case "tv":
            guard let name = item.name, !name.isEmpty else { return nil }
            self.init(
                tmdbID: item.id,
                kind: .series,
                name: name,
                year: Self.year(from: item.firstAirDate),
                posterPath: item.posterPath
            )
        default:
            return nil
        }
    }

    static func year(from date: String?) -> Int? {
        guard let date, date.count >= 4, let year = Int(date.prefix(4)), (1800...2200).contains(year) else {
            return nil
        }
        return year
    }
}
