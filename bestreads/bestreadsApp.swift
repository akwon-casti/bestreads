//
//  bestreadsApp.swift
//  bestreads
//
//  Created by Angela Kwon on 3/16/26.
//

import SwiftUI
import SwiftData

@main
struct bestreadsApp: App {
    private let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Book.self)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
