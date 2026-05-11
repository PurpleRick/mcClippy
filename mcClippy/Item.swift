//
//  Item.swift
//  mcClippy
//
//  Created by Gordon van Straaten on 11/05/2026.
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
