# My Prompt Tester — Architecture Overview & “Image” View Plan

## 1. Current Application Summary
- **Purpose**: My Prompt Tester is a SwiftUI universal app that helps users compose prompts and optional instructions for Apple Intelligence’s text Foundation Model APIs, preview the assistant’s response, and save useful exchanges for later reuse.
- **Tech stack**: SwiftUI scene app, `SwiftData` for persistence (`Item` model storing prompt/instructions/answer/timestamp), `FoundationModels` for Apple Intelligence text generation, `StoreKit` (tips), plus per-platform helpers (`AppStorage`, UIKit/AppKit integration, `SettingsLink`, etc.).
- **Structure**: `ContentView` (`Views/ContentView.swift`) hosts a `TabView` with Prompt, History, and Info tabs. Each tab renders either an inline view (macOS) or is wrapped in `NavigationStack` + `SettingsWrapper` (iOS) to surface the app’s settings sheet. The macOS scene also exposes a native Settings window.
- **Prompt experience** (`Views/PromptView.swift`):
  - Dual `TextEditor`s collect the “Prompt” and “Instructions” fields with focus management (`TabFocusSwitcher`) and dynamic sizing for iPad/iPhone/macOS layouts.
  - Submission uses `LanguageModelSession` from Foundation Models, storing cancellable `Task` state, last prompt, and a parsed Markdown answer. The response area stays visible, supports resubmission, and exposes copy/save affordances.
  - Saves persist unique `(prompt, answer)` pairs into SwiftData and copies use `ClipboardManager` with optional instructions/AI answer inclusion controlled by settings.
- **History** (`Views/HistoryView.swift`):
  - Fetches `Item`s sorted by timestamp, supporting list navigation, inline copy/delete, iOS swipe actions, confirmation alerts, and a detail screen that renders Markdown answers via `String.attributed()`.
  - Copy logic mirrors PromptView including AppStorage-controlled flags.
- **Info & tipping** (`Views/InfoView.swift`, `Views/TipStore.swift`):
  - Presents branding, contact links, and a tipping surface backed by a SwiftUI `@Observable` `TipStore` that loads non-consumable `StoreKit.Product`s, handles purchases/restores, and persists the “has tipped” state.
- **Settings** (`Lifecycle/SettingsView.swift` + `Views/SettingsWrapper.swift`):
  - Two toggles (include instructions/response) drive copy behavior. On iOS the wrapper exposes a toolbar button + sheet; macOS uses the dedicated Settings scene.
- **Utilities**: `ClipboardManager` abstracts platform pasteboard writes with overloads for prompt/answer/instructions, while `String+Extensions` exposes Markdown parsing helpers reused in history detail.
- **Platform polish**: The app selectively adapts to macOS/iOS (window sizing, focus shortcuts, toolbar gear button, safe-area handling) and includes custom icon assets and entitlements.

## 2. Observations & Extension Opportunities
- Prompt workflows are text-only; there is no support for multimodal (image) creativity despite Apple offering the Image Playground stack.
- The UI pattern (editor → action buttons → preview area → secondary actions) is reusable; extracting a smaller component library would ease additional creative surfaces.
- Persistence exists for prompt history but not for non-text assets—design decisions are needed on how/if generated images are stored and reused.
- Dependency boundaries are light: a dedicated service layer for model invocations would simplify mocking/testing when adding more modalities.

## 3. Plan for the New “Image” View (Image Playground)

### Requirements Recap
- Add an “Image” tab that mirrors the Prompt tab’s layout: prompt editor on top, action buttons centered around “Generate”, and a preview canvas below the prompt text.
- Image generation must use Apple’s **ImagePlayground** framework following Majid Jabrayilov’s blog post “[Generating images in Swift using Image Playground](https://swiftwithmajid.com/2025/11/11/generating-images-in-swift-using-image-playground/)”.
- Show the produced image inline (below the prompt) and expose controls akin to PromptView (clear, stop, copy/save as needed).

### Reference Highlights (from the blog post)
- Import `ImagePlayground` and create an `ImageCreator` asynchronously (`let creator = try await ImageCreator()`).
- Determine an `ImageStyle` via `creator.availableStyles` (fall back to the first available style when a preferred style—e.g., `.animation`—is missing).
- Kick off generation with `creator.images(for: [.text(text)], style: style, limit: 1)` which returns an `AsyncSequence` of `GeneratedImage`.
- Iterate over the async sequence to retrieve the generated `CGImage`, handle cancellation, and display the `CGImage`/`Image` in SwiftUI.
- The framework can also take sketches/photos; for the first iteration we focus on text-only prompts plus optional style pickers.

### Proposed Architecture & Steps
1. **Project Setup**
   - Add `import ImagePlayground` where needed, update the project’s capabilities to include the Image Playground entitlement, and target macOS 26 / iOS 26 so every feature (Foundation Models + Image Playground) is available without runtime gating.

2. **Service Layer**
   - Create a lightweight `ImageGenerationService` (e.g., `Utils/ImageGenerationService.swift`) responsible for owning an `ImageCreator`, caching `availableStyles`, and exposing an `async` `generateImage(from prompt: String, style: ImageStyle?) -> CGImage?`.
   - Internally mirror the blog’s sample: lazily instantiate `ImageCreator`, pick an `ImageStyle` (`style ?? creator.availableStyles.first`), call `creator.images(for: [.text(prompt)], style: styleToUse, limit: 1)`, return on the first image, and throw descriptive errors/cancellations.

3. **ImageView UI**
   - Create `Views/ImageView.swift` modeled after `PromptView`: a `TextEditor` (prompt), optional “Style” picker (list of styles retrieved asynchronously), and action buttons (Clear, Generate/Stop).
   - Maintain state: `promptText`, `selectedStyle`, `isGenerating`, `generatedImage: CGImage?`, `generationError`, `currentTask`.
   - The preview area should mimic the PromptView answer block, but instead of text it displays:
     ```swift
     if let cgImage = generatedImage {
         Image(decorative: cgImage, scale: 1.0, orientation: .up)
             .resizable()
             .aspectRatio(contentMode: .fit)
     } else {
         ContentUnavailableView("No image yet", systemImage: "photo")
     }
     ```
     wrapped in the same `.background(.ultraThinMaterial)` styling to stay visually consistent.

4. **Async Flow & Controls**
   - Tapping Generate launches a `Task` that calls the service, updates `generatedImage`, and surfaces any errors.
   - Provide a Stop button (visible during generation) to cancel the task, mirroring the PromptView pattern.
   - Add optional helpers: “Save” (write to Photos on iOS or export on macOS), “Copy” (write the rendered image to the pasteboard). These can reuse a new helper inside `ClipboardManager` (`copy(image:)`), but they can also be deferred if not immediately required.

5. **Tab Integration**
   - Introduce a new tab entry in `ContentView.mainTabView` labeled “Image” with `systemImage: "photo"` positioned between Prompt and History (or wherever fits best).
   - Mirror the Prompt tab’s Apple Intelligence availability check so users see the same placeholder if on unsupported hardware, but otherwise assume the macOS 26 / iOS 26 SDK stack.
   - On iOS wrap `ImageView` in `SettingsWrapper` to keep the settings gear reachable.

6. **Testing & Validation**
   - Manual smoke tests on macOS 26/iOS 26 simulators that support Apple Intelligence & Image Playground to verify generation, cancellation, and UI parity with PromptView.
   - Regression test Prompt/History (especially shared copy/save toggles) because AppStorage-backed settings are reused across tabs.
   - If time permits, add unit tests for `ImageGenerationService` by injecting a mock `ImageCreator` protocol.

### Future Enhancements
- Persist generated images (and prompts) as a new SwiftData model to build an “Image History” gallery.
- Allow multi-modal prompts (text + doodle/photo) once the base experience works.
- Provide style previews (thumbnails) using the palette described in the reference article to help users choose creative directions quickly.

This plan keeps the new Surface aligned with the existing Prompt workflow while grounding the image-generation logic in the Image Playground techniques from the referenced blog post.
