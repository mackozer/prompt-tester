//
//  ImageGenerationService.swift
//  My Prompt Tester
//
//  Created by Codex on 11/11/2025.
//

import Foundation
import ImagePlayground
import Observation
import SwiftUI

typealias ImageStyle = ImagePlaygroundStyle


@MainActor
@Observable
final class ImageGenerationService {
    enum GenerationError: LocalizedError {
        case noImageProduced
        case noStylesAvailable
        case unsupportedLanguage

        var errorDescription: String? {
            switch self {
            case .noImageProduced:
                return "The generator did not return an image."
            case .noStylesAvailable:
                return "No styles are currently available."
            case .unsupportedLanguage:
                return "Image Playground currently supports only English prompts."
            }
        }
    }
    
    var availableStyles: [ImageStyle] = []
    private var creator: ImageCreator?

    func refreshAvailableStyles() async {
        do {
            let creator = try await prepareCreator()
            availableStyles = creator.availableStyles
        } catch {
            availableStyles = []
        }
    }

    func generateImage(from prompt: String, style: ImageStyle?, referenceImage: CGImage? = nil) async throws -> CGImage {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw GenerationError.noImageProduced
        }

        do {
            let creator = try await prepareCreator()
            let resolvedStyle = style ?? creator.availableStyles.first

            guard let styleToUse = resolvedStyle else {
                throw GenerationError.noStylesAvailable
            }

            var concepts: [ImagePlaygroundConcept] = [.text(trimmedPrompt)]
            if let referenceImage {
                concepts.append(.image(referenceImage))
            }

            let imageSequence = creator.images(
                for: concepts,
                style: styleToUse,
                limit: 1
            )

            for try await generated in imageSequence {
                return generated.cgImage
            }

            throw GenerationError.noImageProduced
        } catch let creatorError as ImageCreator.Error {
            if creatorError == .unsupportedLanguage {
                throw GenerationError.unsupportedLanguage
            }
            throw creatorError
        }
    }

    private func prepareCreator() async throws -> ImageCreator {
        if let creator {
            return creator
        }
        let newCreator = try await ImageCreator()
        creator = newCreator
        return newCreator
    }
}
