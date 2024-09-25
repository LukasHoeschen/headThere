//
//  Item.swift
//  Compass to
//
//  Created by Lukas Marius Hoeschen on 25.09.24.
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
