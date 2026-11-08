//
//  SearchView.swift
//  Slate
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss

    var library: [Title]
    var onPick: (CatalogResult) -> Void

    @FocusState private var fieldFocused: Bool
    @State private var query = ""
    @State private var results: [CatalogResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 108, maximum: 160), spacing: 14)]
    private var client: TMDBClient? { TMDBCredentials.client }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add")
                    .font(.title2.bold())
                Spacer()
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            field
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }

            Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                .font(.footnote)
                .foregroundStyle(WatchlistTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
        .background(WatchlistTheme.background)
        .onAppear { fieldFocused = true }
        .task(id: query) { await search() }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WatchlistTheme.muted)
            TextField("Movies and series", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(.white)
                .focused($fieldFocused)
            if isSearching {
                ProgressView()
                    .controlSize(.small)
            }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WatchlistTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(WatchlistTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if client == nil {
            missingToken
        } else if let errorMessage {
            message("Couldn't Search", text: errorMessage, systemImage: "wifi.exclamationmark")
        } else if trimmedQuery.isEmpty {
            message("Search movies and series", text: "Type a title. A poster with a check is already on your watchlist.", systemImage: "magnifyingglass")
        } else if trimmedQuery.count < 2 {
            message("Keep typing", text: "Enter at least 2 characters.", systemImage: "magnifyingglass")
        } else if results.isEmpty && !isSearching {
            ContentUnavailableView.search(text: trimmedQuery)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(results) { result in
                    Button {
                        onPick(result)
                    } label: {
                        CatalogPoster(result: result, saved: isSaved(result))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var missingToken: some View {
        message(
            "TMDB Token Needed",
            text: "Copy Secrets.example.plist to Slate/Secrets.plist and set TMDBReadAccessToken. Create a read access token at themoviedb.org/settings/api.",
            systemImage: "key"
        )
    }

    private func message(_ title: String, text: String, systemImage: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(text)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSaved(_ result: CatalogResult) -> Bool {
        Title.existing(tmdbID: result.tmdbID, kind: result.kind, in: library) != nil
    }

    private func search() async {
        let trimmed = trimmedQuery
        guard trimmed.count >= 2, let client else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        errorMessage = nil
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        do {
            let found = try await client.search(query: trimmed)
            guard !Task.isCancelled else { return }
            results = found
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            errorMessage = "Couldn't reach TMDB. Check your connection and try again."
        }
        isSearching = false
    }
}

private struct CatalogPoster: View {
    let result: CatalogResult
    let saved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(path: result.posterPath, cornerRadius: 12)
                .overlay(alignment: .topTrailing) {
                    if saved {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, WatchlistTheme.accent)
                            .padding(8)
                    }
                }

            Text(result.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(WatchlistTheme.muted)
                .lineLimit(1)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let year = result.year {
            parts.append(String(year))
        }
        parts.append(result.kind.title)
        return parts.joined(separator: " · ")
    }
}
