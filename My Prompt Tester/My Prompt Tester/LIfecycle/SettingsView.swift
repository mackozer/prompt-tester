import SwiftUI

struct SettingsView: View {
    @AppStorage("copyIncludeInstructions") private var copyIncludeInstructions: Bool = true
    @AppStorage("copyIncludeResponse") private var copyIncludeResponse: Bool = false

    #if os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        VStack(alignment: .center, spacing: 16) {

            Text("Copy to clipboard")
                .font(.title2)
                .bold()

            Text("The prompt is always copied.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    SettingsToggle(label: "Add instructions", isOn: $copyIncludeInstructions)
                    SettingsToggle(label: "Add response", isOn: $copyIncludeResponse)
                }
        }
        .padding(20)
        #if os(macOS)
        .frame(minWidth: 300)
        #endif
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }
        #endif
    }
}

#Preview {
    SettingsView()
}

struct SettingsToggle: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(label, isOn: $isOn)
            #if os(macOS)
            .toggleStyle(.checkbox)
            #endif
    }
}
