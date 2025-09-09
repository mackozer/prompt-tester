//
//  String+Extensions.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 09/09/2025.
//

import Foundation

extension String {
    func attributed() -> AttributedString? {
        guard !self.isEmpty else { return nil }
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            return try? AttributedString(
                markdown: self,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnly
                )
            )
        } else {
            return nil
        }
    }
}
