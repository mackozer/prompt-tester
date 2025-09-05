//
//  ContentView.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 05/09/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PromptView()
                .tabItem {
                    Label("Prompt", systemImage: "square.and.pencil")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
        }
    }
}

#Preview {
    ContentView()
}
