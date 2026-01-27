//
//  Item.swift
//  Schieber
//
//  Created by Joerg Ammann on 27.01.2026.
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
