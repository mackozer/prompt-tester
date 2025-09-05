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
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
