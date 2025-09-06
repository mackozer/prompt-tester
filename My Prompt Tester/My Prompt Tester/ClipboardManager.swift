//
//  ClipboardManager.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 05/09/2025.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if os(macOS)
import AppKit
#endif

enum ClipboardManager {
    // Low-level API that sets clipboard contents directly.
    static func copy(text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        // No-op on unsupported platforms
        #endif
    }

    // High-level API that mirrors the app's desired copy formatting.
    // Trims prompt and answer, validates non-empty, joins with a separator, then copies.
    @discardableResult
    static func copy(prompt: String, answer: String) -> Bool {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !trimmedAnswer.isEmpty else { return false }

        let separator = "\n--------------------\n"
        let combined = "\(trimmedPrompt)\(separator)\(trimmedAnswer)"

        copy(text: combined)
        return true
    }

    // Convenience overload for copying from a model Item.
    @discardableResult
    static func copy(from item: Item) -> Bool {
        copy(prompt: item.prompt, answer: item.aiAnswer)
    }
}

