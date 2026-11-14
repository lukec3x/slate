//
//  SlateApp.swift
//  Slate
//

import SwiftUI
import SwiftData

@main
struct SlateApp: App {
    private let modelContainerResult: Result<ModelContainer, Error>

    init() {
        let schema = Schema([Title.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        modelContainerResult = Result {
            try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    var body: some Scene {
        WindowGroup {
            switch modelContainerResult {
            case .success(let container):
                LibraryView()
                    .preferredColorScheme(.dark)
                    .tint(WatchlistTheme.accent)
                    .modelContainer(container)
            case .failure(let error):
                LibraryStoreErrorView(error: error)
                    .preferredColorScheme(.dark)
            }
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 680)
        #endif
    }
}

private struct LibraryStoreErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't Open Library", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("The saved library is still on this Mac. Slate left it untouched.\n\n\(error.localizedDescription)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchlistTheme.background)
    }
}
