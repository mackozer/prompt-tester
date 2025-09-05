//
//  PromptView.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 05/09/2025.
//

import SwiftUI
import SwiftData
import FoundationModels

struct PromptView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var promptText: String = ""
    @State private var aiAnswer: String? = nil
    @State private var isSubmitting: Bool = false
    @State private var lastSubmittedPrompt: String? = nil

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prompt
            VStack(alignment: .leading, spacing: 6) {
                Text("Prompt")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $promptText)
                    .applyTextInputAutocapitalizationSentences()
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 160)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )
            }

            // Submit button aligned trailing relative to editor
            HStack {
                Spacer()
                Button(action: submitTapped) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text(submitButtonTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // AI Answer area always visible with a compact fixed height
            VStack(alignment: .leading, spacing: 8) {
                Text(aiAnswer ?? "AI response will be presented here")
                    .foregroundStyle(aiAnswer == nil ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 200)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.2))
                    )

                // Save button under the answer
                HStack {
                    Button {
                        saveTapped()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(aiAnswer == nil)
                    Spacer()
                }
            }
        }
        .padding()
        // Encourage the view to report an intrinsic vertical size so the window can fit to content.
        #if os(macOS)
        .fixedSize(horizontal: false, vertical: false)
        #endif
    }

    private func submitTapped() {
        guard !isSubmitting else { return }
        isSubmitting = true

        let modelSession = LanguageModelSession()
        let submittingPrompt = promptText
        Task {
            do {
                aiAnswer = try await modelSession.respond(to: submittingPrompt).content
                lastSubmittedPrompt = submittingPrompt
            } catch {
                aiAnswer = "Failed to fetch an AI response."
            }
            isSubmitting = false
        }
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
            aiAnswer: trimmedAnswer
        )
        modelContext.insert(item)
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
}

#Preview {
    PromptView()
        .modelContainer(for: Item.self, inMemory: true)
}

@Generable
struct PromptResponse {
    @Guide(description: "Motivation for a dog to reach the goal in a session of training to fight dog separation anxiety")
    var slogan: String
}
