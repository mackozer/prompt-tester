//
//  PromptView.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 05/09/2025.
//

import SwiftUI
import SwiftData
import FoundationModels

#if canImport(UIKit)
import UIKit
#endif

#if os(macOS)
import AppKit
#endif

struct PromptView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("copyIncludeInstructions") private var copyIncludeInstructions: Bool = true
    @AppStorage("copyIncludeResponse") private var copyIncludeResponse: Bool = false

    @State private var promptText: String = ""
    @State private var instructionsText: String = ""
    @State private var aiAnswer: String? = nil
    @State private var isSubmitting: Bool = false
    @State private var lastSubmittedPrompt: String? = nil
    @State private var currentTask: Task<Void, Never>? = nil

    // Focus management for switching between editors
    @FocusState private var focusedField: FocusField?
    enum FocusField: Hashable {
        case prompt
        case instructions
    }

    // Dynamic sizing for iPad
    private var isPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    private var promptMinHeight: CGFloat { isPad ? 260 : 180 }
    private var promptMaxHeight: CGFloat { isPad ? 300 : 200 }
    private var instructionsMinHeight: CGFloat { isPad ? 200 : 140 }
    private var instructionsMaxHeight: CGFloat { isPad ? 220 : 140 }
    // Removed: private var answerFixedHeight: CGFloat { isPad ? 320 : 200 }

    private var hasPromptChangedSinceLastAnswer: Bool {
        guard let last = lastSubmittedPrompt else { return true }
        return last != promptText
    }

    private var submitButtonTitle: String {
        if aiAnswer != nil && !hasPromptChangedSinceLastAnswer {
            return "Resubmit"
        } else {
            return "Submit"
        }
    }

    // Parsed Markdown version of the AI answer when available
    private var aiAnswerAttributed: AttributedString? {
        guard let aiAnswer, !aiAnswer.isEmpty else { return nil }
        return try? AttributedString(
            markdown: aiAnswer,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnly
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let answerHeight: CGFloat = {
                if isPad {
                    return isLandscape ? 260 : 320
                } else {
                    return 200
                }
            }()

            VStack(alignment: .leading, spacing: 12) {
                // Prompt
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prompt")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $promptText)
                        .applyTextInputAutocapitalizationSentences()
#if os(macOS)
                        .font(.title3)
#endif
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: promptMinHeight, maxHeight: promptMaxHeight)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                        .focused($focusedField, equals: .prompt)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Instructions")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $instructionsText)
                        .applyTextInputAutocapitalizationSentences()
#if os(macOS)
                        .font(.title3)
#endif
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: instructionsMinHeight, maxHeight: instructionsMaxHeight)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                        .focused($focusedField, equals: .instructions)
                }
                
                // Submit button aligned trailing relative to editor
                HStack {
                    Button(action: {
                        clearTapped()
                    }) {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canClear)
                    
                    Spacer()
                    Button(action: {
                        if isSubmitting {
                            stopTapped()
                        } else {
                            submitTapped()
                        }
                    }) {
                        if isSubmitting {
                            Label("Stop", systemImage: "stop.fill")
                        } else {
                            Label(submitButtonTitle, systemImage: "apple.intelligence")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    #if os(macOS)
                    // Add Command + Return shortcut on macOS
                    .keyboardShortcut(.return, modifiers: [.command])
                    #endif
                    .disabled(!isSubmitting && promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .tint(isSubmitting ? .red : nil)
                    .fixedSize()
                }
                
                // AI Answer area always visible with a compact fixed height
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        ScrollView {
                            Group {
                                if let attributed = aiAnswerAttributed {
                                    Text(attributed)
                                } else {
                                    Text(aiAnswer ?? "AI response will be presented here")
                                }
                            }
                            .foregroundStyle(aiAnswer == nil ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.large)
                        }
                    }
                    .frame(height: answerHeight)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.2))
                            .frame(height: answerHeight)
                    )
                    // Save and Copy buttons under the answer
                    HStack {
                        Button {
                            saveTapped()
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(aiAnswer == nil)
                        
                        Spacer()
                        
                        Button {
                            copyTapped()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canCopy)
                    }
                }
            }
            .padding()
            #if os(iOS)
            .safeAreaPadding(.top)
            #endif
            #if os(macOS)
            // Encourage the view to report an intrinsic vertical size so the window can fit to content.
            .fixedSize(horizontal: false, vertical: false)
            #endif
            // Handle Tab / Shift+Tab to switch focus between TextEditors (iOS 17+, macOS 14+)
            .modifier(TabFocusSwitcher(focusedField: $focusedField))
            .onAppear {
                #if os(iOS)
                // Do not auto-focus on iOS to avoid popping the software keyboard when no external keyboard is connected.
                #else
                if focusedField == nil {
                    focusedField = .prompt
                }
                #endif
            }
            #if os(iOS)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                focusedField = nil
            })
            #endif
            #if os(iOS)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            #endif
        }
    }

    private var canCopy: Bool {
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = aiAnswer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if copyIncludeResponse {
            return !trimmedPrompt.isEmpty && !trimmedAnswer.isEmpty
        } else {
            return !trimmedPrompt.isEmpty
        }
    }

    private var canClear: Bool {
        let hasPrompt = !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasInstructions = !instructionsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAnswer = !(aiAnswer?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasPrompt || hasInstructions || hasAnswer || isSubmitting
    }

    private func submitTapped() {
        guard !isSubmitting else { return }
        isSubmitting = true

        let submittingPrompt = promptText
        let submittingInstructions = instructionsText

        let modelSession: LanguageModelSession

        if submittingInstructions.isEmpty {
            modelSession = LanguageModelSession()
        } else {
            modelSession = LanguageModelSession(instructions: instructionsText)
        }

        currentTask = Task { [submittingPrompt] in
            defer {
                // Only clear submitting state if not cancelled; if cancelled, stopTapped() already reset state
                if !Task.isCancelled {
                    isSubmitting = false
                }
                currentTask = nil
            }
            do {
                let response = try await modelSession.respond(to: submittingPrompt).content
                if Task.isCancelled { return }
                aiAnswer = response
                lastSubmittedPrompt = submittingPrompt
            } catch {
                if Task.isCancelled { return }
                aiAnswer = "Failed to fetch an AI response."
            }
        }
    }

    private func stopTapped() {
        currentTask?.cancel()
        currentTask = nil
        isSubmitting = false
    }

    private func clearTapped() {
        if isSubmitting {
            stopTapped()
        }
        promptText = ""
        instructionsText = ""
        aiAnswer = nil
        lastSubmittedPrompt = nil
        focusedField = nil
    }

    private func saveTapped() {
        // Ensure we have something to save
        guard let answer = aiAnswer, !answer.isEmpty else { return }
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !trimmedAnswer.isEmpty else { return }

        // Check for existing item with the same prompt and aiAnswer
        do {
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { item in
                    item.prompt == trimmedPrompt && item.aiAnswer == trimmedAnswer
                },
                sortBy: []
            )
            let existing = try modelContext.fetch(descriptor)
            guard existing.isEmpty else {
                // Duplicate found, do not insert
                return
            }
        } catch {
            // If fetch fails, you may choose to bail out or proceed; we'll bail out to be safe.
            return
        }

        // Insert new unique item
        let item = Item(
            timestamp: Date(),
            prompt: trimmedPrompt,
            aiAnswer: trimmedAnswer,
            instructions: instructionsText
        )
        modelContext.insert(item)
    }

    private func copyTapped() {
        // Always require a non-empty prompt to copy
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        let composite: String
        if !copyIncludeInstructions && !copyIncludeResponse {
            // Only prompt requested: copy raw prompt content without labels
            composite = prompt
        } else {
            var parts: [String] = []
            parts.append("Prompt:\n\(prompt)")

            if copyIncludeInstructions {
                let instr = instructionsText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !instr.isEmpty {
                    parts.append("Instructions:\n\(instr)")
                }
            }

            if copyIncludeResponse {
                let answer = aiAnswer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !answer.isEmpty {
                    parts.append("Response:\n\(answer)")
                }
            }

            composite = parts.joined(separator: "\n\n")
        }

        // Keep existing behavior for potential internal uses
        _ = ClipboardManager.copy(prompt: promptText, instructions: instructionsText, answer: aiAnswer ?? "")

        // And write the composed string to the system pasteboard as requested
        #if canImport(UIKit)
        UIPasteboard.general.string = composite
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(composite, forType: .string)
        #endif
    }
}

// MARK: - Tab focus switcher

private struct TabFocusSwitcher: ViewModifier {
    // Accept a FocusState.Binding, not a standard Binding
    var focusedField: FocusState<PromptView.FocusField?>.Binding

    func body(content: Content) -> some View {
        content
            // Handle Tab and Shift+Tab with a single handler; inspect modifiers on the press.
            .onKeyPress(.tab) {
                focusNext()
                return .handled
            }
    }

    private func focusNext() {
        switch focusedField.wrappedValue {
        case .prompt:
            focusedField.wrappedValue = .instructions
        case .instructions:
            focusedField.wrappedValue = .prompt
        case .none:
            focusedField.wrappedValue = .instructions
        }
    }
}

private extension View {
    // Applies sentences autocapitalization on platforms/SDKs where available.
    @ViewBuilder
    func applyTextInputAutocapitalizationSentences() -> some View {
        #if canImport(UIKit)
        self.textInputAutocapitalization(.sentences)
        #else
        self
        #endif
    }
}

#Preview {
    PromptView()
        .modelContainer(for: Item.self, inMemory: true)
}
