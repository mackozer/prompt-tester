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
    
    @ViewBuilder
    private var promptTab: some View {
        if isAppleIntelligenceAvailable {
            #if os(iOS)
            NavigationStack { SettingsWrapper { PromptView() } }
            #else
            PromptView()
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        SettingsLink {
                            Image(systemName: "gearshape").imageScale(.medium)
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            #endif
        } else {
            #if os(iOS)
            NavigationStack { appleIntelligenceUnavailableView }
            #else
            appleIntelligenceUnavailableView
            #endif
        }
    }

    @ViewBuilder
    private var historyTab: some View {
        #if os(iOS)
        NavigationStack { SettingsWrapper { HistoryView() } }
        #else
        HistoryView()
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    SettingsLink {
                        Image(systemName: "gearshape").imageScale(.medium)
                    }
                    .accessibilityLabel("Settings")
                }
            }
        #endif
    }

    @ViewBuilder
    private var infoTab: some View {
        #if os(iOS)
        NavigationStack { SettingsWrapper { InfoView() } }
        #else
        InfoView()
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    SettingsLink {
                        Image(systemName: "gearshape").imageScale(.medium)
                    }
                    .accessibilityLabel("Settings")
                }
            }
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
            promptTab
                .tabItem { Label("Prompt", systemImage: "square.and.pencil") }

            historyTab
                .tabItem { Label("History", systemImage: "clock") }

            infoTab
                .tabItem { Label("Info", systemImage: "info.circle") }
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

