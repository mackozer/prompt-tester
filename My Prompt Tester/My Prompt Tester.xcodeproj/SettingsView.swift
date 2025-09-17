import SwiftUI

struct SettingsView: View {
    @AppStorage("copyIncludeInstructions") private var copyIncludeInstructions: Bool = true
    @AppStorage("copyIncludeResponse") private var copyIncludeResponse: Bool = false

    var body: some View {
        Form {
            Section(header: Text("Settings").font(.headline)) {
                HStack(spacing: 12) {
                    Text("Copy prompt and instructions")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Toggle("", isOn: $copyIncludeInstructions)
                        .labelsHidden()
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                }
                HStack(spacing: 12) {
                    Text("Also copy response")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Toggle("", isOn: $copyIncludeResponse)
                        .labelsHidden()
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480)
        #endif
    }
}

#Preview {
    SettingsView()
}
