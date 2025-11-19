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
import Photos
#elseif os(macOS)
import AppKit
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
#else
    @State private var isShowingShareSheet: Bool = false
    @State private var shareImage: UIImage?
    @State private var isShowingPhotosPicker: Bool = false
    @State private var photoPermissionAlertMessage: String = ""
    @State private var isShowingPhotoPermissionAlert: Bool = false
    @FocusState private var isPromptFocused: Bool
    @State private var buttonStackHeight: CGFloat = 120
#endif

    private var canGenerate: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    @ViewBuilder
    private var referencePhotoContent: some View {
        if isLoadingReferenceImage {
            ProgressView()
        } else if let referenceImage {
            Image(decorative: referenceImage, scale: 1.0, orientation: .up)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
        } else {
#if os(iOS)
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Add a face photo for personalization.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
#else
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
#endif
        }
    }

    private let previewCornerRadius: CGFloat = 10

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                promptAndReferenceSection
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
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
#else
        .photosPicker(isPresented: $isShowingPhotosPicker, selection: $selectedPhotoItem, matching: .images)
        .alert("Photo Access Required", isPresented: $isShowingPhotoPermissionAlert) {
            Button("OK", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(photoPermissionAlertMessage)
        }
#endif
#if os(iOS)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            isPromptFocused = false
        })
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $isShowingShareSheet, onDismiss: { shareImage = nil }) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
#endif
    }

    @ViewBuilder
    private var promptAndReferenceSection: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: 20) {
            promptEditor
                .frame(maxWidth: .infinity)
            referencePhotoSection
                .frame(width: 260)
        }
        #else
        VStack(alignment: .leading, spacing: 16) {
            promptEditor
            referencePhotoSection
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
#if os(iOS)
                .frame(minHeight: 100, maxHeight: 120)
#else
                .frame(minHeight: 180, maxHeight: 260)
#endif
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
#if os(iOS)
                .focused($isPromptFocused)
#endif
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

            HStack(spacing: 12) {
#if os(macOS)
                Button {
                    saveGeneratedImage()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(generatedImage == nil)
#endif

                Button {
                    shareGeneratedImage()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(generatedImage == nil)
            }
        }
    }

    @ViewBuilder
    private var referencePhotoSection: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 8) {
            Text("Reference Photo")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("Choose Photo", systemImage: "person.crop.square.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                if referenceImage != nil {
                    Button("Remove", systemImage: "trash", action: removeReferenceImage)
                        .buttonStyle(.bordered)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 200)
                    .overlay(referencePhotoContent)
                    .onDrop(of: [.image], isTargeted: $isDropTargeted) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                            if let data, let cgImage = makeCGImage(from: data) {
                                Task { @MainActor in referenceImage = cgImage }
                            }
                        }
                        return true
                    }
            }
        }
        #else
        VStack(alignment: .leading, spacing: 8) {
            Text("Reference Photo")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        requestPhotoPermissionAndPresentPicker()
                    } label: {
                        Label(referenceImage == nil ? "Add Reference Photo" : "Replace photo", systemImage: "person.crop.square.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)

                    if referenceImage != nil {
                        Button("Remove", systemImage: "trash", action: removeReferenceImage)
                            .buttonStyle(.bordered)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ButtonStackHeightKey.self, value: proxy.size.height)
                    }
                )

                Spacer()

                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.clear))
                        .overlay(referencePhotoContent)
                }
                .frame(width: buttonStackHeight, height: buttonStackHeight)
            }
        }
        #endif
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

#if os(macOS)
    private func saveGeneratedImage() {
        guard let generatedImage else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "GeneratedImage.png"
        panel.allowedContentTypes = [.png]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try writePNG(image: generatedImage, to: url)
                } catch {
                    errorMessage = "Failed to save image."
                }
            }
        }
    }
#else
    private func saveGeneratedImage() { }
#endif

    private func shareGeneratedImage() {
        guard let generatedImage else { return }
#if os(macOS)
        let size = NSSize(width: generatedImage.width, height: generatedImage.height)
        let nsImage = NSImage(cgImage: generatedImage, size: size)
        let picker = NSSharingServicePicker(items: [nsImage])
        if let window = NSApplication.shared.keyWindow,
           let view = window.contentView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
        }
#else
        let image = UIImage(cgImage: generatedImage)
        shareImage = image
        isShowingShareSheet = true
#endif
    }

#if os(macOS)
    private func writePNG(image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImageGenerationService", code: -1)
        }
        try data.write(to: url)
    }
#endif

    #if os(iOS)
    @MainActor
    private func requestPhotoPermissionAndPresentPicker() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            isShowingPhotosPicker = true
        case .notDetermined:
            Task {
                let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                await MainActor.run {
                    if newStatus == .authorized || newStatus == .limited {
                        isShowingPhotosPicker = true
                    } else {
                        photoPermissionAlertMessage = "Please allow photo access in Settings to add a reference image."
                        isShowingPhotoPermissionAlert = true
                    }
                }
            }
        default:
            photoPermissionAlertMessage = "Please allow photo access in Settings to add a reference image."
            isShowingPhotoPermissionAlert = true
        }
    }
    #endif
}

private extension ImagePlaygroundStyle {
    var displayName: String {
        String(describing: self.id).replacingOccurrences(of: "_", with: " ").capitalized
    }
}

#if os(iOS)
private struct ButtonStackHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 120
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
#endif

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif

#Preview {
    ImageView()
}
