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

    @State private var seasons: [TMDBSeason] = []
    @State private var episodes: [TMDBEpisode] = []
    @State private var isLoading = true
    @State private var catalogFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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

                if showsProgress {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Where you stopped")
                            .font(.headline)
                        progressFields
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WatchlistTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    modelContext.delete(title)
                    dismiss()
                }
            }
        }
        .background {
            Button("Back") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .onExitCommand { dismiss() }
        .task(id: progressTaskID) {
            await loadCatalog()
        }
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

    private var progressTaskID: String {
        "\(title.persistentModelID)-\(title.statusRaw)"
    }

    @ViewBuilder
    private var progressFields: some View {
        if !seasons.isEmpty {
            Picker("Season", selection: seasonSelection) {
                Text("Select").tag(Optional<Int>.none)
                ForEach(seasons) { season in
                    Text(seasonLabel(season)).tag(Optional(season.seasonNumber))
                }
            }
            .pickerStyle(.menu)

            if title.seasonNumber == nil {
                Text("Select a season to choose an episode.")
                    .foregroundStyle(WatchlistTheme.muted)
            } else if !episodes.isEmpty {
                Picker("Episode", selection: episodeSelection) {
                    Text("Select").tag(Optional<Int>.none)
                    ForEach(episodes) { episode in
                        Text(episodeLabel(episode)).tag(Optional(episode.episodeNumber))
                    }
                }
                .pickerStyle(.menu)
            } else if isLoading {
                ProgressView("Loading episodes")
            } else {
                episodeField
            }
        } else if isLoading {
            ProgressView("Loading episodes")
        } else {
            seasonField
            episodeField
            if catalogFailed {
                Text("The catalog is unavailable. Season and episode can still be edited here.")
                    .font(.footnote)
                    .foregroundStyle(WatchlistTheme.muted)
            }
        }
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
            guard let newValue else {
                title.setProgress(season: nil, episode: nil, name: nil)
                episodes = []
                return
            }
            if newValue != title.seasonNumber {
                title.setProgress(season: newValue, episode: nil, name: nil)
                episodes = []
            }
            Task { await loadEpisodes(season: newValue) }
        }
    }

    private var episodeSelection: Binding<Int?> {
        Binding {
            title.episodeNumber
        } set: { newValue in
            guard let newValue else {
                title.setProgress(season: title.seasonNumber, episode: nil, name: nil)
                return
            }
            let name = episodes.first { $0.episodeNumber == newValue }?.name
            title.setProgress(season: title.seasonNumber, episode: newValue, name: name)
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

    private func loadCatalog() async {
        guard showsProgress else {
            isLoading = false
            catalogFailed = false
            return
        }
        guard let client = TMDBCredentials.client else {
            seasons = []
            episodes = []
            catalogFailed = true
            isLoading = false
            return
        }

        isLoading = true
        catalogFailed = false
        do {
            let loadedSeasons = try await client.seasons(seriesID: title.tmdbID)
            guard !Task.isCancelled else { return }
            seasons = loadedSeasons
            if let season = title.seasonNumber {
                episodes = try await client.episodes(seriesID: title.tmdbID, season: season)
            } else {
                episodes = []
            }
            guard !Task.isCancelled else { return }
            catalogFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            seasons = []
            episodes = []
            catalogFailed = true
        }
        isLoading = false
    }

    private func loadEpisodes(season: Int) async {
        guard let client = TMDBCredentials.client else {
            episodes = []
            catalogFailed = true
            return
        }
        isLoading = true
        do {
            let loaded = try await client.episodes(seriesID: title.tmdbID, season: season)
            guard !Task.isCancelled else { return }
            episodes = loaded
            catalogFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            episodes = []
            catalogFailed = true
            seasons = []
        }
        isLoading = false
    }
}
