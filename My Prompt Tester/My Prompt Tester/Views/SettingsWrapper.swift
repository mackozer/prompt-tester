import SwiftUI

/// A reusable wrapper that adds a Settings toolbar button and sheet on iOS.
/// On other platforms, it simply renders the provided content.
struct SettingsWrapper<Content: View>: View {
    private let content: Content
    #if os(iOS)
    @State private var isShowingSettings: Bool = false
    #endif

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if os(iOS)
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .imageScale(.medium)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.height(300)])
            }
        #else
        content
        #endif
    }
}

