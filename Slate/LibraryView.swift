//
//  LibraryView.swift
//  Slate
//

import SwiftUI
import SwiftData

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case watching
    case want
    case watched

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .watching: "Watching"
        case .want: "Want"
        case .watched: "Watched"
        }
    }

    func includes(_ status: WatchStatus) -> Bool {
        switch self {
        case .all: true
        case .watching: status == .watching
        case .want: status == .want
        case .watched: status == .watched
        }
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Title.updatedAt, order: .reverse) private var titles: [Title]

    @State private var filter: LibraryFilter = .all
    @State private var path: [PersistentIdentifier] = []
    @State private var showingSearch = false
    @State private var showingFind = false
    @State private var pendingTitleID: PersistentIdentifier?

    private let columns = [GridItem(.adaptive(minimum: 108, maximum: 160), spacing: 14)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    filters

                    if visibleTitles.isEmpty {
                        ContentUnavailableView {
                            Label(emptyTitle, systemImage: "film")
                        } description: {
                            Text(emptyDescription)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                            ForEach(visibleTitles) { title in
                                NavigationLink(value: title.persistentModelID) {
                                    PosterCard(title: title)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        delete(title)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(WatchlistTheme.background)
            .navigationTitle("Watchlist")
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let title = title(for: id) {
                    TitleDetailView(title: title)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Find", systemImage: "magnifyingglass") {
                        showingFind = true
                    }
                    .keyboardShortcut("f", modifiers: [])
                    .disabled(showingSearch || showingFind || !path.isEmpty)
                    .help("Find in this category (F)")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Title", systemImage: "plus") {
                        showingSearch = true
                    }
                    .keyboardShortcut("a", modifiers: [])
                    .disabled(showingSearch || showingFind)
                    .help("Add a title (A)")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 560)
        #endif
        .sheet(isPresented: $showingSearch, onDismiss: openPendingTitle) {
            SearchView(library: titles, onPick: add)
                .presentationBackground(WatchlistTheme.background)
                #if os(macOS)
                .frame(width: 720, height: 640)
                #endif
        }
        .sheet(isPresented: $showingFind, onDismiss: openPendingTitle) {
            FindView(titles: titles, category: filter, onPick: openFound)
                .presentationBackground(WatchlistTheme.background)
                #if os(macOS)
                .frame(width: 560, height: 640)
                #endif
        }
    }

    private func openFound(_ title: Title) {
        pendingTitleID = title.persistentModelID
        showingFind = false
    }

    private func title(for id: PersistentIdentifier) -> Title? {
        if let match = titles.first(where: { $0.persistentModelID == id }) {
            return match
        }
        return modelContext.model(for: id) as? Title
    }

    private func openPendingTitle() {
        guard let pendingTitleID else { return }
        path = [pendingTitleID]
        self.pendingTitleID = nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Watchlist")
                .font(.largeTitle.bold())
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(WatchlistTheme.muted)
        }
        .foregroundStyle(.white)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(.white)
                            .background(filter == item ? WatchlistTheme.accent : WatchlistTheme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var visibleTitles: [Title] {
        titles.filter { filter.includes($0.status) }
    }

    private var summary: String {
        let count = titles.count
        let noun = count == 1 ? "title" : "titles"
        return "\(count) \(noun)"
    }

    private var emptyTitle: String {
        switch filter {
        case .all: "Your watchlist is empty"
        case .watching: "Nothing in progress"
        case .want: "Nothing saved for later"
        case .watched: "Nothing finished yet"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .all: "Add a movie or series to start tracking."
        case .watching: "Titles you are currently watching show up here."
        case .want: "Titles you want to watch show up here."
        case .watched: "Titles you have finished show up here."
        }
    }

    private func add(_ result: CatalogResult) {
        let title: Title
        if let existing = Title.existing(tmdbID: result.tmdbID, kind: result.kind, in: titles) {
            title = existing
        } else {
            title = Title(result: result)
            modelContext.insert(title)
            try? modelContext.save()
            filter = .all
        }
        pendingTitleID = title.persistentModelID
        showingSearch = false
    }

    private func delete(_ title: Title) {
        path.removeAll { $0 == title.persistentModelID }
        modelContext.delete(title)
    }
}

private struct FindView: View {
    @Environment(\.dismiss) private var dismiss

    var titles: [Title]
    var onPick: (Title) -> Void

    @State private var category: LibraryFilter
    @State private var query = ""
    @FocusState private var fieldFocused: Bool

    init(titles: [Title], category: LibraryFilter, onPick: @escaping (Title) -> Void) {
        self.titles = titles
        self.onPick = onPick
        _category = State(initialValue: category)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Find")
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

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(WatchlistTheme.muted)
                TextField("Titles in \(category.title)", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .focused($fieldFocused)
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
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LibraryFilter.allCases) { item in
                        Button {
                            category = item
                        } label: {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(category == item ? WatchlistTheme.accent : WatchlistTheme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            ScrollView {
                if matches.isEmpty {
                    ContentUnavailableView {
                        Label("No Titles", systemImage: "film")
                    } description: {
                        Text(emptyDescription)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(matches) { title in
                            Button {
                                onPick(title)
                            } label: {
                                HStack(spacing: 12) {
                                    PosterImage(path: title.posterPath, width: 40, cornerRadius: 6)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(title.name)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(subtitle(for: title))
                                            .font(.subheadline)
                                            .foregroundStyle(WatchlistTheme.muted)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .background(WatchlistTheme.background)
        .onAppear { fieldFocused = true }
    }

    private var emptyDescription: String {
        if !trimmed.isEmpty {
            return "Nothing in \(category.title) matches that."
        }
        if category == .all {
            return "Nothing is saved yet."
        }
        return "Nothing is saved in \(category.title)."
    }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matches: [Title] {
        titles.filter { title in
            category.includes(title.status)
                && (trimmed.isEmpty || title.name.localizedStandardContains(trimmed))
        }
    }

    private func subtitle(for title: Title) -> String {
        var parts: [String] = [title.kind.title]
        if let year = title.year {
            parts.insert(String(year), at: 0)
        }
        if title.status != .want, let progress = title.progressLabel {
            parts.append(progress)
        }
        return parts.joined(separator: " · ")
    }
}

private struct PosterCard: View {
    let title: Title

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PosterImage(path: title.posterPath, cornerRadius: 12)
                .overlay(alignment: .bottomLeading) {
                    if title.status != .want, let progress = title.progressLabel {
                        Text(progress)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.72), in: Capsule())
                            .padding(8)
                    }
                }

            Text(title.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

struct PosterImage: View {
    var path: String?
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = 10

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if let width {
                artwork
                    .frame(width: width, height: width * 1.5)
            } else {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay { artwork }
            }
        }
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private var artwork: some View {
        ZStack {
            WatchlistTheme.card
            if let url = TMDBImage.url(path: path) {
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
    }

    private var placeholder: some View {
        Image(systemName: "film")
            .font(.title2)
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Title.self, inMemory: true)
        .preferredColorScheme(.dark)
}
