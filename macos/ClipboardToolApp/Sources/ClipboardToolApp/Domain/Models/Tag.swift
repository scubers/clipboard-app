import Foundation

// MARK: - Tag Models

struct ItemTag: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}

struct TagWithCount: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let createdAtMs: Int64
    let colorHex: String
    let itemCount: Int
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}

// MARK: - SwiftUI Color Extension

import SwiftUI

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex)
        
        if hex.hasPrefix("#") {
            scanner.currentIndex = hex.index(after: hex.startIndex)
        }
        
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
