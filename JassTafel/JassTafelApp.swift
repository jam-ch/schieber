//
//  JassTafelApp.swift
//  JassTafel
//
//  Created by Joerg Ammann on 27.01.2026.
//

import SwiftUI
import SwiftData

@main
struct JassTafelApp: App {
    @State private var showSplash = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Runde.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
