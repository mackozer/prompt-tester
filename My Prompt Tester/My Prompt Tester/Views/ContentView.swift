//
//  ContentView.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 05/09/2025.
//

import SwiftUI
import FoundationModels

struct ContentView: View {
    private var isAppleIntelligenceAvailable: Bool {
        #if os(iOS) || os(macOS)
        if #available(iOS 18.0, macOS 15.0, *) {
            return SystemLanguageModel.default.availability == .available
        } else {
            // Apple Intelligence APIs are not available on earlier systems
            return false
        }
        #else
        // For platforms other than iOS/macOS, treat as available to keep existing behavior
        return true
        #endif
    }
    
    var body: some View {
        mainTabView
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 700)
        #endif
    }
    
    @ViewBuilder
    var mainTabView: some View {
        TabView {
            Group {
                if isAppleIntelligenceAvailable {
                    PromptView()
                } else {
                    appleIntelligenceUnavailableView
                }
            }
            .tabItem {
                Label("Prompt", systemImage: "square.and.pencil")
            }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
        }
    }
    
    @ViewBuilder
    private var appleIntelligenceUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Apple Intelligence is not available on this device.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("Please use a compatible device and enable Apple Intelligence in Settings if supported.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
