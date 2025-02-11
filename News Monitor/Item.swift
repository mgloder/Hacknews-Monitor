//
//  Item.swift
//  News Monitor
//
//  Created by Yan Xu on 11/2/2025.
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
