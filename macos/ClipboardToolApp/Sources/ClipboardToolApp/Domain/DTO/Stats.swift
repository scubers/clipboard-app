import Foundation

struct Stats: Codable {
    let totalItems: Int64
    let activeItems: Int64
    let deletedItems: Int64
    let pinnedActiveItems: Int64
}
