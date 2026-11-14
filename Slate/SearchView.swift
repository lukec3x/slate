//
//  SearchView.swift
//  Slate
//

import SwiftUI
import SwiftData

enum WatchlistHit: Identifiable {
    case saved(Title)
    case catalog(CatalogResult)

    var id: String {
        switch self {
        case .saved(let title):
            "\(title.kind.rawValue)-\(title.tmdbID)"
        case .catalog(let result):
            result.id
        }
    }
}

enum WatchlistSearch {
    static func hits(
        query: String,
        category: LibraryFilter,
        titles: [Title],
        catalog: [CatalogResult]
    ) -> [WatchlistHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = titles.filter { title in
            category.includes(title.status)
                && (trimmed.isEmpty || title.name.localizedStandardContains(trimmed))
        }
        let savedIDs = Set(titles.map { "\($0.kind.rawValue)-\($0.tmdbID)" })
        let fresh = catalog.filter { !savedIDs.contains($0.id) }
        return saved.map(WatchlistHit.saved) + fresh.map(WatchlistHit.catalog)
    }

    static func highlight(current: Int?, count: Int, movingBy offset: Int) -> Int? {
        guard count > 0 else { return nil }
        let start = min(max(current ?? 0, 0), count - 1)
        return min(max(start + offset, 0), count - 1)
    }

    static func category(_ category: LibraryFilter, movingBy offset: Int) -> LibraryFilter {
        let cases = Array(LibraryFilter.allCases)
        guard let index = cases.firstIndex(of: category) else { return category }
        let next = min(max(index + offset, 0), cases.count - 1)
        return cases[next]
    }
}

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss

    var library: [Title]
    var onPickSaved: (Title) -> Void
    var onPickCatalog: (CatalogResult) -> Void

    @FocusState private var fieldFocused: Bool
    @State private var category: LibraryFilter
    @State private var query = ""
    @State private var results: [CatalogResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var selection: Int? = 0

    private var client: TMDBClient? { TMDBCredentials.client }

    init(
        library: [Title],
        category: LibraryFilter,
        onPickSaved: @escaping (Title) -> Void,
        onPickCatalog: @escaping (CatalogResult) -> Void
    ) {
        self.library = library
        self.onPickSaved = onPickSaved
        self.onPickCatalog = onPickCatalog
        _category = State(initialValue: category)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            field
                .padding(.horizontal, 20)
            chips
            ScrollViewReader { proxy in
                ScrollView {
                    content
                        .padding(.horizontal, 8)
                        .padding(.bottom, 24)
                }
                .onChange(of: selection) { _, newValue in
                    scroll(proxy, to: newValue)
                }
                .onChange(of: category) { _, _ in
                    selection = hits.isEmpty ? nil : 0
                    scroll(proxy, to: selection)
                }
                .onChange(of: hitIDs) { _, _ in
                    selection = hits.isEmpty ? nil : 0
                    scroll(proxy, to: selection)
                }
            }
            attribution
        }
        .background(WatchlistTheme.background)
        .onAppear { fieldFocused = true }
        .onExitCommand { dismiss() }
        .task(id: query) { await search() }
    }

    private var header: some View {
        HStack {
            Text("Search")
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
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WatchlistTheme.muted)
            TextField("Movies, series, and your list", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(.white)
                .focused($fieldFocused)
                .onSubmit { openHighlighted() }
                .onKeyPress(phases: [.down, .repeat]) { press in
                    switch press.key {
                    case .upArrow:
                        selection = WatchlistSearch.highlight(current: selection, count: hits.count, movingBy: -1)
                        return .handled
                    case .downArrow:
                        selection = WatchlistSearch.highlight(current: selection, count: hits.count, movingBy: 1)
                        return .handled
                    case .leftArrow:
                        category = WatchlistSearch.category(category, movingBy: -1)
                        return .handled
                    case .rightArrow:
                        category = WatchlistSearch.category(category, movingBy: 1)
                        return .handled
                    case .escape:
                        dismiss()
                        return .handled
                    default:
                        return .ignored
                    }
                }
            if isSearching {
                ProgressView()
                    .controlSize(.small)
            }
            if !query.isEmpty {
                Button {
                    query = ""
                    fieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WatchlistTheme.muted)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(WatchlistTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { item in
                    Button {
                        category = item
                        fieldFocused = true
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(.white)
                            .background(category == item ? WatchlistTheme.accent : WatchlistTheme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var attribution: some View {
        Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
            .font(.footnote)
            .foregroundStyle(WatchlistTheme.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        if !hits.isEmpty {
            VStack(spacing: 4) {
                ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                    Button {
                        pick(hit)
                    } label: {
                        row(hit, selected: index == selection)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .id(hit.id)
                }
            }
        } else if client == nil && trimmedQuery.count >= 2 {
            missingToken
        } else if let errorMessage {
            message("Couldn't Search", text: errorMessage, systemImage: "wifi.exclamationmark")
        } else if trimmedQuery.isEmpty {
            message("No Titles", text: emptyDescription, systemImage: "film")
        } else if trimmedQuery.count < 2 {
            message("Keep typing", text: "Enter at least 2 characters.", systemImage: "magnifyingglass")
        } else if isSearching {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
        } else {
            ContentUnavailableView.search(text: trimmedQuery)
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
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
        .padding(.top, 32)
    }

    private func row(_ hit: WatchlistHit, selected: Bool) -> some View {
        HStack(spacing: 12) {
            PosterImage(path: posterPath(hit), width: 40, cornerRadius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(name(hit))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle(hit))
                    .font(.subheadline)
                    .foregroundStyle(WatchlistTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if case .saved = hit {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, WatchlistTheme.accent)
                    .accessibilityLabel("On your watchlist")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? WatchlistTheme.card : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hits: [WatchlistHit] {
        WatchlistSearch.hits(query: query, category: category, titles: library, catalog: results)
    }

    private var hitIDs: [String] {
        hits.map(\.id)
    }

    private var emptyDescription: String {
        if category == .all {
            return "Nothing is saved yet."
        }
        return "Nothing is saved in \(category.title)."
    }

    private func posterPath(_ hit: WatchlistHit) -> String? {
        switch hit {
        case .saved(let title): title.posterPath
        case .catalog(let result): result.posterPath
        }
    }

    private func name(_ hit: WatchlistHit) -> String {
        switch hit {
        case .saved(let title): title.name
        case .catalog(let result): result.name
        }
    }

    private func subtitle(_ hit: WatchlistHit) -> String {
        switch hit {
        case .saved(let title):
            var parts: [String] = [title.kind.title]
            if let year = title.year {
                parts.insert(String(year), at: 0)
            }
            if title.status != .want, let progress = title.progressLabel {
                parts.append(progress)
            }
            return parts.joined(separator: " · ")
        case .catalog(let result):
            var parts: [String] = []
            if let year = result.year {
                parts.append(String(year))
            }
            parts.append(result.kind.title)
            return parts.joined(separator: " · ")
        }
    }

    private func pick(_ hit: WatchlistHit) {
        switch hit {
        case .saved(let title):
            onPickSaved(title)
        case .catalog(let result):
            onPickCatalog(result)
        }
    }

    private func openHighlighted() {
        guard let selection, hits.indices.contains(selection) else { return }
        pick(hits[selection])
    }

    private func scroll(_ proxy: ScrollViewProxy, to index: Int?) {
        guard let index, hits.indices.contains(index) else { return }
        proxy.scrollTo(hits[index].id)
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
