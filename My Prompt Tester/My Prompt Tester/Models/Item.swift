//
//  Item.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 05/09/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var prompt: String
    var aiAnswer: String
    var instructions: String = ""
    
    init(timestamp: Date, prompt: String, aiAnswer: String, instructions: String = "") {
        self.timestamp = timestamp
        self.prompt = prompt
        self.aiAnswer = aiAnswer
        self.instructions = instructions
    }
}
