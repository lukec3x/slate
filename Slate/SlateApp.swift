//
//  SlateApp.swift
//  Slate
//

import SwiftUI
import SwiftData

@main
struct SlateApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Title.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        // The Xcode template store only held sample items. Drop it and start the watchlist fresh.
        let storeURL = configuration.url
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
        try? fileManager.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .preferredColorScheme(.dark)
                .tint(WatchlistTheme.accent)
        }
        .modelContainer(sharedModelContainer)
    }
}
