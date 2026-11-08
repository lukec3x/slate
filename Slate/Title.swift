//
//  Title.swift
//  Slate
//

import Foundation
import SwiftData

nonisolated enum TitleKind: String, Codable, CaseIterable, Identifiable {
    case movie
    case series

    var id: String { rawValue }

    var title: String {
        switch self {
        case .movie: "Movie"
        case .series: "Series"
        }
    }
}

enum WatchStatus: String, Codable, CaseIterable, Identifiable {
    case want
    case watching
    case watched

    var id: String { rawValue }

    var title: String {
        switch self {
        case .want: "Want to Watch"
        case .watching: "Watching"
        case .watched: "Watched"
        }
    }
}

@Model
final class Title {
    var tmdbID: Int
    var kindRaw: String
    var name: String
    var year: Int?
    var posterPath: String?
    var statusRaw: String
    var seasonNumber: Int?
    var episodeNumber: Int?
    var episodeName: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        tmdbID: Int,
        kind: TitleKind,
        name: String,
        year: Int?,
        posterPath: String?,
        status: WatchStatus = .want,
        createdAt: Date = .now
    ) {
        self.tmdbID = tmdbID
        self.kindRaw = kind.rawValue
        self.name = name
        self.year = year
        self.posterPath = posterPath
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    convenience init(result: CatalogResult, status: WatchStatus = .want, createdAt: Date = .now) {
        self.init(
            tmdbID: result.tmdbID,
            kind: result.kind,
            name: result.name,
            year: result.year,
            posterPath: result.posterPath,
            status: status,
            createdAt: createdAt
        )
    }

    var kind: TitleKind {
        get { TitleKind(rawValue: kindRaw) ?? .movie }
        set {
            kindRaw = newValue.rawValue
            if newValue == .movie {
                seasonNumber = nil
                episodeNumber = nil
                episodeName = nil
            }
        }
    }

    var status: WatchStatus {
        get { WatchStatus(rawValue: statusRaw) ?? .want }
        set {
            statusRaw = newValue.rawValue
            updatedAt = .now
        }
    }

    var progressLabel: String? {
        guard kind == .series, let seasonNumber, let episodeNumber else { return nil }
        return "S\(seasonNumber) E\(episodeNumber)"
    }

    func setProgress(season: Int?, episode: Int?, name: String?) {
        guard kind == .series else {
            seasonNumber = nil
            episodeNumber = nil
            episodeName = nil
            return
        }
        seasonNumber = season
        episodeNumber = episode
        episodeName = name
        updatedAt = .now
    }

    static func existing(tmdbID: Int, kind: TitleKind, in titles: [Title]) -> Title? {
        titles.first { $0.tmdbID == tmdbID && $0.kind == kind }
    }
}
