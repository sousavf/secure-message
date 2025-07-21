//
//  Item.swift
//  Safe Whisper
//
//  Created by Vasco Sousa on 21/07/2025.
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
