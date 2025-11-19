//
//  ImageView.swift
//  My Prompt Tester
//
//  Created by Codex on 11/11/2025.
//

import SwiftUI
import ImagePlayground
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct ImageView: View {
    @State private var imageService = ImageGenerationService()
    @State private var promptText: String = ""
    @State private var selectedStyleIndex: Int = -1
    @State private var generatedImage: CGImage?
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    @State private var currentTask: Task<Void, Never>?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var referenceImage: CGImage?
    @State private var isLoadingReferenceImage: Bool = false
#if os(macOS)
    @State private var isShowingFileImporter: Bool = false
    @State private var isDropTargeted: Bool = false
#endif

    private var canGenerate: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    private let previewCornerRadius: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            promptEditor
            stylePicker
            referencePhotoSection

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
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                await loadReferenceImage(from: newItem)
            }
        }
        #if os(macOS)
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                Task { await loadReferenceImage(from: url) }
            case .failure:
                errorMessage = "Unable to open the selected file."
            }
        }
        #endif
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

    private var referencePhotoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reference Photo")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                #if os(macOS)
                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("Choose Photo", systemImage: "person.crop.square.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                #else
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose Photo", systemImage: "person.crop.square.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                #endif

                if referenceImage != nil {
                    Button("Remove", systemImage: "trash", action: removeReferenceImage)
                        .buttonStyle(.bordered)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .frame(height: 160)
                    .overlay(
                        Group {
                            if isLoadingReferenceImage {
                                ProgressView()
                            } else if let referenceImage {
                                Image(decorative: referenceImage, scale: 1.0, orientation: .up)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(8)
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                    Text("Optional portrait helps Image Playground personalize people scenes.")
                                        .font(.footnote)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    )
                    #if os(macOS)
                    .onDrop(of: [.image], isTargeted: $isDropTargeted) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                            if let data, let cgImage = makeCGImage(from: data) {
                                Task { @MainActor in referenceImage = cgImage }
                            }
                        }
                        return true
                    }
                    #endif
            }
        }
    }

    private var canClear: Bool {
        let hasPrompt = !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasPrompt || generatedImage != nil || isGenerating || referenceImage != nil
    }

    private func generateTapped() {
        guard !isGenerating else { return }
        errorMessage = nil
        isGenerating = true

        let prompt = promptText
        let style = styleForSelection()
        let referenceImage = referenceImage

        currentTask = Task {
            defer {
                if !Task.isCancelled {
                    isGenerating = false
                }
                currentTask = nil
            }

            do {
                let image = try await imageService.generateImage(from: prompt, style: style, referenceImage: referenceImage)
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
        removeReferenceImage()
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

    private func removeReferenceImage() {
        referenceImage = nil
        selectedPhotoItem = nil
        isLoadingReferenceImage = false
    }

    @MainActor
    private func loadReferenceImage(from item: PhotosPickerItem?) async {
        guard let item else {
            removeReferenceImage()
            return
        }

        isLoadingReferenceImage = true
        defer { isLoadingReferenceImage = false }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let cgImage = makeCGImage(from: data) {
                referenceImage = cgImage
            } else {
                referenceImage = nil
            }
        } catch {
            referenceImage = nil
            errorMessage = "Failed to load the selected photo."
        }
    }

    #if os(macOS)
    @MainActor
    private func loadReferenceImage(from url: URL) async {
        isLoadingReferenceImage = true
        defer { isLoadingReferenceImage = false }
        do {
            let data = try Data(contentsOf: url)
            referenceImage = makeCGImage(from: data)
        } catch {
            referenceImage = nil
            errorMessage = "Failed to load the selected photo."
        }
    }
    #endif

    private func makeCGImage(from data: Data) -> CGImage? {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data)?.cgImage {
            return uiImage
        }
        #elseif os(macOS)
        if let nsImage = NSImage(data: data) {
            return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        #endif
        return nil
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
