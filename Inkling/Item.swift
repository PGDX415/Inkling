//
//  Item.swift
//  Inkling
//
//  Created by Paul Dexin Gong on 2026/7/16.
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
