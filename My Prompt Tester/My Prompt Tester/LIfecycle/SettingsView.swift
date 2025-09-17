import SwiftUI

struct SettingsView: View {
    @AppStorage("copyIncludeInstructions") private var copyIncludeInstructions: Bool = true
    @AppStorage("copyIncludeResponse") private var copyIncludeResponse: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .trailing, spacing: 12) {
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
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.15))
        )
        .padding()
        #if os(macOS)
        .frame(minWidth: 480)
        #endif
    }
}

#Preview {
    SettingsView()
}
