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
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            return try? AttributedString(
                markdown: aiAnswer,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnly
                )
            )
        } else {
            return nil
        }
    }

    var body: some View {
        GeometryReader { _ in
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
                        .frame(minHeight: 180, maxHeight: 200)
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
                        .frame(minHeight: 140, maxHeight: 140)
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
                    .applyBorderedButtonStyle()
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
                    .applyPrimaryButtonStyle(isSubmitting: isSubmitting)
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
                    .frame(height: 200)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.2))
                            .frame(height: 200)
                    )
                    // Save and Copy buttons under the answer
                    HStack {
                        Button {
                            saveTapped()
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .applyBorderedButtonStyle()
                        .disabled(aiAnswer == nil)
                        
                        Spacer()
                        
                        Button {
                            copyTapped()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .applyBorderedButtonStyle()
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
        return !trimmedPrompt.isEmpty && !trimmedAnswer.isEmpty
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
        guard let answer = aiAnswer else { return }
        _ = ClipboardManager.copy(prompt: promptText, instructions: instructionsText, answer: answer)
    }
}

// MARK: - Tab focus switcher

private struct TabFocusSwitcher: ViewModifier {
    // Accept a FocusState.Binding, not a standard Binding
    var focusedField: FocusState<PromptView.FocusField?>.Binding

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            content
                // Handle Tab and Shift+Tab with a single handler; inspect modifiers on the press.
                .onKeyPress(.tab) {
                    focusNext()
                    return .handled
                }
        } else {
            content
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

    private func focusPrevious() {
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
        if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
            self.textInputAutocapitalization(SwiftUI.TextInputAutocapitalization.sentences)
        } else {
            self
        }
        #else
        // macOS and other platforms: TextEditor doesn't support textInputAutocapitalization
        self
        #endif
    }

    @ViewBuilder
    func applyPrimaryButtonStyle(isSubmitting: Bool) -> some View {
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            self.buttonStyle(.automatic)
        } else {
            self.buttonStyle(DefaultButtonStyle())
        }
    }

    @ViewBuilder
    func applyBorderedButtonStyle() -> some View {
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            self.buttonStyle(.automatic)
        } else {
            self.buttonStyle(DefaultButtonStyle())
        }
    }
}

#Preview {
    PromptView()
        .modelContainer(for: Item.self, inMemory: true)
}

