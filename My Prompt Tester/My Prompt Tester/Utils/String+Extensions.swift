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
        return try? AttributedString(
            markdown: self,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnly
            )
        )
    }
}
