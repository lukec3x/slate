//
//  TitleDetailView.swift
//  Slate
//

import SwiftUI
import SwiftData

struct TitleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var title: Title

    @State private var seriesDetail: SeriesDetail?
    @State private var movieDetail: MovieDetail?
    @State private var episodes: [TMDBEpisode] = []
    @State private var isLoadingDetail = true
    @State private var isLoadingEpisodes = false
    @State private var detailFailed = false
    @State private var episodesFailed = false
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if backdropPath != nil {
                    backdrop
                }
                header
                if overviewText != nil || taglineText != nil {
                    summary
                }
                if showsDetailSpinner {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                if !facts.isEmpty {
                    factsList
                }
                statusControls
                if showsProgress {
                    progressCard
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(WatchlistTheme.background)
        .navigationTitle(title.name)
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
                .keyboardShortcut("d", modifiers: [])
                .help("Delete (D)")
            }
        }
        .alert("Delete this title?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                modelContext.delete(title)
                dismiss()
            }
            .keyboardShortcut("y", modifiers: [])
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(title.name) from your watchlist.")
        }
        .background {
            Button("Back") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(confirmingDelete)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .onExitCommand {
            if confirmingDelete {
                confirmingDelete = false
            } else {
                dismiss()
            }
        }
        .task(id: title.persistentModelID) {
            await loadDetail()
        }
        .task(id: episodeTaskID) {
            await loadEpisodesIfNeeded()
        }
    }

    private var backdrop: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                FrameImage(path: backdropPath, width: .backdrop, cornerRadius: 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            PosterImage(path: title.posterPath, width: 168, cornerRadius: 16)
            VStack(alignment: .leading, spacing: 8) {
                Text(title.name)
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(meta)
                    .font(.title3)
                    .foregroundStyle(WatchlistTheme.muted)
                if let progress = title.progressLabel, title.status != .want {
                    Text(savedProgress(progress))
                        .font(.headline)
                        .foregroundStyle(WatchlistTheme.accent)
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let overview = overviewText {
                Text(overview)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let tagline = taglineText {
                Text(tagline)
                    .font(.body.italic())
                    .foregroundStyle(WatchlistTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var factsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(facts) { fact in
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(fact.label)
                        .foregroundStyle(WatchlistTheme.muted)
                    Spacer(minLength: 12)
                    Text(fact.value)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
            }
        }
    }

    private var statusControls: some View {
        VStack(spacing: 10) {
            ForEach(WatchStatus.allCases) { status in
                Button {
                    title.status = status
                } label: {
                    HStack {
                        Text(status.title)
                            .font(.body.weight(.semibold))
                        Spacer()
                        if title.status == status {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.bold))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        title.status == status ? WatchlistTheme.accent : WatchlistTheme.card,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Where you stopped")
                .font(.headline)
            progressFields
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WatchlistTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var meta: String {
        var parts: [String] = []
        if let year = title.year {
            parts.append(String(year))
        }
        parts.append(title.kind.title)
        return parts.joined(separator: " · ")
    }

    private var showsProgress: Bool {
        title.kind == .series && title.status != .want
    }

    private var showsDetailSpinner: Bool {
        isLoadingDetail && seriesDetail == nil && movieDetail == nil && !showsProgress
            && title.overview == nil && title.genres.isEmpty && title.backdropPath == nil
    }

    private var episodeTaskID: String {
        guard showsProgress else { return "idle" }
        return "\(title.seasonNumber ?? -1)"
    }

    private var backdropPath: String? {
        seriesDetail?.backdropPath ?? movieDetail?.backdropPath ?? title.backdropPath
    }

    private var overviewText: String? {
        seriesDetail?.overview ?? movieDetail?.overview ?? title.overview
    }

    private var taglineText: String? {
        seriesDetail?.tagline ?? movieDetail?.tagline
    }

    private var genreNames: [String] {
        if let genres = seriesDetail?.genres, !genres.isEmpty { return genres }
        if let genres = movieDetail?.genres, !genres.isEmpty { return genres }
        return title.genres
    }

    private var facts: [CatalogFact] {
        if let series = seriesDetail {
            return seriesFacts(series)
        }
        if let movie = movieDetail {
            return movieFacts(movie)
        }
        return factRows([("Genres", joined(genreNames))])
    }

    private func seriesFacts(_ series: SeriesDetail) -> [CatalogFact] {
        factRows([
            ("Genres", joined(genreNames)),
            ("Status", series.status),
            ("First aired", CatalogDate.display(series.firstAirDate)),
            ("Last aired", CatalogDate.display(series.lastAirDate)),
            ("Runtime", runtimeList(series.episodeRuntimes)),
            ("Seasons", countText(series.numberOfSeasons)),
            ("Episodes", countText(series.numberOfEpisodes)),
            ("Network", joined(series.networks)),
            ("Country", joined(series.originCountries)),
            ("Language", languageText(series.originalLanguage)),
            ("Rating", ratingText(average: series.voteAverage, count: series.voteCount)),
            ("Creators", joined(series.creators)),
            ("Next episode", series.nextEpisode.map(airedText)),
            ("Last episode", series.lastEpisode.map(airedText)),
        ])
    }

    private func movieFacts(_ movie: MovieDetail) -> [CatalogFact] {
        factRows([
            ("Genres", joined(genreNames)),
            ("Released", CatalogDate.display(movie.releaseDate)),
            ("Runtime", movie.runtime.flatMap { $0 > 0 ? "\($0) min" : nil }),
            ("Status", movie.status),
            ("Rating", ratingText(average: movie.voteAverage, count: movie.voteCount)),
            ("Country", joined(movie.countries)),
            ("Language", languageText(movie.originalLanguage)),
            ("Collection", movie.collectionName),
        ])
    }

    private func factRows(_ pairs: [(String, String?)]) -> [CatalogFact] {
        pairs.compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return CatalogFact(label: label, value: value)
        }
    }

    private func joined(_ values: [String]) -> String? {
        let items = values.filter { !$0.isEmpty }
        return items.isEmpty ? nil : items.joined(separator: ", ")
    }

    private func runtimeList(_ minutes: [Int]) -> String? {
        var seen: [Int] = []
        for minute in minutes where minute > 0 && !seen.contains(minute) {
            seen.append(minute)
        }
        guard !seen.isEmpty else { return nil }
        return seen.map { "\($0) min" }.joined(separator: ", ")
    }

    private func countText(_ value: Int?) -> String? {
        guard let value else { return nil }
        return value.formatted(.number.locale(Locale(identifier: "en_US")))
    }

    private func languageText(_ code: String?) -> String? {
        guard let code, !code.isEmpty else { return nil }
        return code.uppercased()
    }

    private func ratingText(average: Double?, count: Int?) -> String? {
        guard let count, count > 0, let average else { return nil }
        let locale = Locale(identifier: "en_US")
        let score = String(format: "%.1f", locale: locale, average)
        let votes = count.formatted(.number.locale(locale))
        return "\(score) · \(votes) votes"
    }

    private func airedText(_ episode: AiredEpisode) -> String {
        var parts = ["S\(episode.seasonNumber) E\(episode.episodeNumber)"]
        if !episode.name.isEmpty {
            parts.append(episode.name)
        }
        if let airDate = CatalogDate.display(episode.airDate) {
            parts.append(airDate)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var progressFields: some View {
        if let seasons = seriesDetail?.seasons, !seasons.isEmpty, !episodesFailed {
            seasonPicker(seasons)
            if let season = selectedSeason(in: seasons) {
                seasonSummary(season)
            }
            episodeChoices
        } else if isLoadingDetail || isLoadingEpisodes {
            ProgressView("Loading episodes")
        } else {
            seasonField
            episodeField
            if detailFailed || episodesFailed {
                Text("The catalog is unavailable. Season and episode can still be edited here.")
                    .font(.footnote)
                    .foregroundStyle(WatchlistTheme.muted)
            }
        }
    }

    private func seasonPicker(_ seasons: [TMDBSeason]) -> some View {
        Picker("Season", selection: seasonSelection) {
            Text("Select").tag(Optional<Int>.none)
            ForEach(seasons) { season in
                Text(seasonLabel(season)).tag(Optional(season.seasonNumber))
            }
        }
        .pickerStyle(.menu)
    }

    private func seasonSummary(_ season: TMDBSeason) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(path: season.posterPath, width: 72, cornerRadius: 8)
            VStack(alignment: .leading, spacing: 6) {
                Text(seasonLabel(season))
                    .font(.headline)
                if let airDate = CatalogDate.display(season.airDate) {
                    Text(airDate)
                        .foregroundStyle(WatchlistTheme.muted)
                }
                if let overview = season.overview {
                    Text(overview)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var episodeChoices: some View {
        if title.seasonNumber == nil {
            Text("Select a season to choose an episode.")
                .foregroundStyle(WatchlistTheme.muted)
        } else if !episodes.isEmpty {
            episodeStrip
            selectedEpisodeDetail
        } else if isLoadingEpisodes {
            ProgressView("Loading episodes")
        } else {
            episodeField
        }
    }

    private var episodeStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(episodes) { episode in
                    Button {
                        choose(episode)
                    } label: {
                        episodeCard(episode, selected: episode.episodeNumber == title.episodeNumber)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(episode.episodeNumber == title.episodeNumber ? .isSelected : [])
                }
            }
        }
    }

    private func episodeCard(_ episode: TMDBEpisode, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FrameImage(path: episode.stillPath, width: .still)
                .frame(width: 160, height: 90)
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(WatchlistTheme.accent, lineWidth: 3)
                    }
                }
            Text(episodeLabel(episode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let overview = episode.overview {
                Text(overview)
                    .font(.caption)
                    .foregroundStyle(WatchlistTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(width: 160, alignment: .leading)
    }

    @ViewBuilder
    private var selectedEpisodeDetail: some View {
        if let episode = episodes.first(where: { $0.episodeNumber == title.episodeNumber }) {
            VStack(alignment: .leading, spacing: 6) {
                if let overview = episode.overview {
                    Text(overview)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let meta = episodeMeta(episode) {
                    Text(meta)
                        .foregroundStyle(WatchlistTheme.muted)
                }
            }
        }
    }

    private func episodeMeta(_ episode: TMDBEpisode) -> String? {
        var parts: [String] = []
        if let airDate = CatalogDate.display(episode.airDate) {
            parts.append(airDate)
        }
        if let runtime = episode.runtime, runtime > 0 {
            parts.append("\(runtime) min")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var seasonField: some View {
        LabeledContent("Season") {
            TextField("Season", value: manualSeason, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        }
    }

    private var episodeField: some View {
        LabeledContent("Episode") {
            TextField("Episode", value: manualEpisode, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        }
    }

    private var seasonSelection: Binding<Int?> {
        Binding {
            title.seasonNumber
        } set: { newValue in
            guard newValue != title.seasonNumber else { return }
            title.setProgress(season: newValue, episode: nil, name: nil)
            episodes = []
            episodesFailed = false
            isLoadingEpisodes = newValue != nil
        }
    }

    private var manualSeason: Binding<Int?> {
        Binding {
            title.seasonNumber
        } set: { newValue in
            guard newValue != title.seasonNumber else { return }
            title.setProgress(season: newValue, episode: title.episodeNumber, name: nil)
        }
    }

    private var manualEpisode: Binding<Int?> {
        Binding {
            title.episodeNumber
        } set: { newValue in
            guard newValue != title.episodeNumber else { return }
            title.setProgress(season: title.seasonNumber, episode: newValue, name: nil)
        }
    }

    private func selectedSeason(in seasons: [TMDBSeason]) -> TMDBSeason? {
        guard let number = title.seasonNumber else { return nil }
        return seasons.first { $0.seasonNumber == number }
    }

    private func choose(_ episode: TMDBEpisode) {
        let name = episode.name.trimmingCharacters(in: .whitespacesAndNewlines)
        title.setProgress(
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            name: name.isEmpty ? nil : name
        )
    }

    private func seasonLabel(_ season: TMDBSeason) -> String {
        season.name.isEmpty ? "Season \(season.seasonNumber)" : season.name
    }

    private func episodeLabel(_ episode: TMDBEpisode) -> String {
        let prefix = "E\(episode.episodeNumber)"
        return episode.name.isEmpty ? prefix : "\(prefix) · \(episode.name)"
    }

    private func savedProgress(_ progress: String) -> String {
        if let episodeName = title.episodeName, !episodeName.isEmpty {
            return "\(progress) · \(episodeName)"
        }
        return progress
    }

    private func loadDetail() async {
        guard let client = TMDBCredentials.client else {
            detailFailed = true
            isLoadingDetail = false
            return
        }

        isLoadingDetail = true
        detailFailed = false
        do {
            switch title.kind {
            case .series:
                let detail = try await client.series(seriesID: title.tmdbID)
                guard !Task.isCancelled else { return }
                seriesDetail = detail
                movieDetail = nil
                title.rememberCatalog(
                    overview: detail.overview,
                    backdropPath: detail.backdropPath,
                    genres: detail.genres
                )
            case .movie:
                let detail = try await client.movie(movieID: title.tmdbID)
                guard !Task.isCancelled else { return }
                movieDetail = detail
                seriesDetail = nil
                title.rememberCatalog(
                    overview: detail.overview,
                    backdropPath: detail.backdropPath,
                    genres: detail.genres
                )
            }
            detailFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            detailFailed = true
        }
        guard !Task.isCancelled else { return }
        isLoadingDetail = false
    }

    private func loadEpisodesIfNeeded() async {
        guard showsProgress, let season = title.seasonNumber else {
            episodes = []
            episodesFailed = false
            isLoadingEpisodes = false
            return
        }
        guard let client = TMDBCredentials.client else {
            episodes = []
            episodesFailed = true
            isLoadingEpisodes = false
            return
        }

        isLoadingEpisodes = true
        episodesFailed = false
        do {
            let loaded = try await client.episodes(seriesID: title.tmdbID, season: season)
            guard !Task.isCancelled else { return }
            episodes = loaded
            episodesFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            episodes = []
            episodesFailed = true
        }
        guard !Task.isCancelled else { return }
        isLoadingEpisodes = false
    }
}

private struct CatalogFact: Identifiable {
    var label: String
    var value: String
    var id: String { label }
}

private enum CatalogDate {
    static func display(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        guard let date = parser.date(from: value) else { return value }
        return output.string(from: date)
    }

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let output: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct FrameImage: View {
    var path: String?
    var width: TMDBImage.Width
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            WatchlistTheme.card
            if let url = TMDBImage.url(path: path, width: width) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "film")
            .font(.title2)
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
