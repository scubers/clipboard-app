import Foundation

struct Item: Codable, Identifiable {
    let id: String
    let createdAtMs: Int64
    let lastCopiedAtMs: Int64
    let type: String
    let summary: String
    let sourceApp: String?
    let pinned: Bool
    let ocrMatched: Bool?
}
