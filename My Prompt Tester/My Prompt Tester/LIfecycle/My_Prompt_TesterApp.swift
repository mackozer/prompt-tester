//
//  My_Prompt_TesterApp.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 05/09/2025.
//

import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

@main
struct My_Prompt_TesterApp: App {
    let container: ModelContainer

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        #if os(macOS)
        // Let the window follow the content’s ideal size (macOS 14+).
        .windowResizability(.contentSize)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .padding()
        }
        #endif
    }
    
    init() {
        do {
            container = try ModelContainer(for: Item.self)
        } catch {
            fatalError("Failed to create ModelContainer for Session.")
        }
    }
}

