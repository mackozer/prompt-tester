//
//  ImageView.swift
//  My Prompt Tester
//
//  Created by Codex on 11/11/2025.
//

import SwiftUI
import ImagePlayground

struct ImageView: View {
    @State private var imageService = ImageGenerationService()
    @State private var promptText: String = ""
    @State private var selectedStyleIndex: Int = -1
    @State private var generatedImage: CGImage?
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    @State private var currentTask: Task<Void, Never>?

    private var canGenerate: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    private let previewCornerRadius: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            promptEditor
            stylePicker

            HStack {
                Button("Clear", systemImage: "xmark.circle", action: clearTapped)
                    .buttonStyle(.bordered)
                    .disabled(!canClear)

                Spacer()

                Button {
                    if isGenerating {
                        stopTapped()
                    } else {
                        generateTapped()
                    }
                } label: {
                    Label(isGenerating ? "Stop" : "Generate", systemImage: isGenerating ? "stop.fill" : "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(isGenerating ? .red : nil)
                .disabled(!canGenerate && !isGenerating)
            }

            previewSection(height: 360)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .padding()
        .task {
            await imageService.refreshAvailableStyles()
        }
        .onChange(of: imageService.availableStyles) { _ in
            clampSelectedStyleIndex()
        }
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prompt")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextEditor(text: $promptText)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 180, maxHeight: 260)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
        }
    }

    @ViewBuilder
    private var stylePicker: some View {
        if !imageService.availableStyles.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Style")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedStyleIndex) {
                    Text("Automatic").tag(-1)
                    ForEach(Array(imageService.availableStyles.enumerated()), id: \.offset) { index, style in
                        Text(style.displayName)
                            .tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private func previewSection(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                Group {
                    if let image = generatedImage {
                        Image(decorative: image, scale: 1.0, orientation: .up)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView("No image generated", systemImage: "photo", description: Text("Enter a prompt and tap Generate."))
                    }
                }
                .padding()

                if isGenerating {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .frame(height: height)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: previewCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: previewCornerRadius)
                    .stroke(Color.secondary.opacity(0.2))
            )
        }
    }

    private var canClear: Bool {
        let hasPrompt = !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasPrompt || generatedImage != nil || isGenerating
    }

    private func generateTapped() {
        guard !isGenerating else { return }
        errorMessage = nil
        isGenerating = true

        let prompt = promptText
        let style = styleForSelection()

        currentTask = Task {
            defer {
                if !Task.isCancelled {
                    isGenerating = false
                }
                currentTask = nil
            }

            do {
                let image = try await imageService.generateImage(from: prompt, style: style)
                if Task.isCancelled { return }
                generatedImage = image
            } catch {
                if Task.isCancelled { return }
                generatedImage = nil
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func stopTapped() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    private func clearTapped() {
        if isGenerating {
            stopTapped()
        }
        promptText = ""
        generatedImage = nil
        errorMessage = nil
    }

    private func styleForSelection() -> ImagePlaygroundStyle? {
        guard selectedStyleIndex >= 0 else { return nil }
        guard imageService.availableStyles.indices.contains(selectedStyleIndex) else { return nil }
        return imageService.availableStyles[selectedStyleIndex]
    }

    private func clampSelectedStyleIndex() {
        if imageService.availableStyles.isEmpty {
            selectedStyleIndex = -1
        } else if selectedStyleIndex >= imageService.availableStyles.count {
            selectedStyleIndex = 0
        }
    }
}

private extension ImagePlaygroundStyle {
    var displayName: String {
        String(describing: self.id).replacingOccurrences(of: "_", with: " ").capitalized
    }
}

#Preview {
    ImageView()
}
