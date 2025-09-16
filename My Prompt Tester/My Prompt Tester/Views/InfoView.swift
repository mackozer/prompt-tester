import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct InfoView: View {
    @ViewBuilder
    private var appIconView: some View {
        #if os(macOS)
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 126, height: 126)
            .cornerRadius(20)
            .shadow(radius: 4)
        #elseif canImport(UIKit)
        if let uiImage = UIImage(named: "icon") {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(20)
                .shadow(radius: 4)
        } else {
            Image(systemName: "app")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundStyle(.secondary)
        }
        #else
        Image(systemName: "app")
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 72)
            .foregroundStyle(.secondary)
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 16) {
                appIconView

                Text("My Prompt Tester")
                    .font(.largeTitle)
                    .bold()

                Text("This app helps users explore and experiment with Apple Intelligence prompts and instructions to build more interactive and engaging user experiences. It's a great way to practice and improve your skills in this exciting field!")
                    #if os(macOS)
                    .font(.title3)
                    #endif
                    .multilineTextAlignment(.center)

                VStack(alignment: .center, spacing: 8) {
                    Text("Creator")
                        .font(.headline)
                    Text("Krystian Kozerawski")
                    #if os(macOS)
                    .font(.title3)
                    #endif
                }

                VStack(alignment: .center, spacing: 8) {
                    Text("Contact")
                        .font(.headline)
                    Group {
                        // Website placeholder: open a blank page for now
                        Link("Website", destination: URL(string: "about:blank")!)
                        // Email link
                        Link("Email Developer", destination: URL(string: "mailto:mackozer@icloud.com")!)
                        // Mastodon handle and link
                        Link("Mastodon", destination: URL(string: "https://mastodon.social/@mackozer")!)
                    }
                    #if os(macOS)
                    .font(.title3)
                    #endif
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(20)
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
    }
}

#Preview {
    InfoView()
}
