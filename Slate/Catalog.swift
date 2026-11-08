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

nonisolated struct TMDBSeason: Identifiable, Equatable, Decodable {
    var id: Int
    var seasonNumber: Int
    var name: String
    var episodeCount: Int
}

nonisolated struct TMDBEpisode: Identifiable, Equatable, Decodable {
    var id: Int
    var episodeNumber: Int
    var name: String
    var seasonNumber: Int
}

nonisolated enum TMDBError: Error {
    case badResponse
    case badStatus(Int)
}

nonisolated enum TMDBImage {
    static func url(path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }
}

nonisolated enum CatalogDecoder {
    static func searchResults(from data: Data) throws -> [CatalogResult] {
        let response = try decoder.decode(TMDBSearchResponse.self, from: data)
        return response.results.compactMap(CatalogResult.init(item:))
    }

    static func seasons(from data: Data) throws -> [TMDBSeason] {
        let response = try decoder.decode(TMDBSeriesDetails.self, from: data)
        return response.seasons.sorted { $0.seasonNumber < $1.seasonNumber }
    }

    static func episodes(from data: Data) throws -> [TMDBEpisode] {
        let response = try decoder.decode(TMDBSeasonDetails.self, from: data)
        return response.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
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

    func seasons(seriesID: Int) async throws -> [TMDBSeason] {
        let data = try await fetch(path: "tv/\(seriesID)", query: [language])
        return try CatalogDecoder.seasons(from: data)
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

private nonisolated struct TMDBSeriesDetails: Decodable {
    var seasons: [TMDBSeason]
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
