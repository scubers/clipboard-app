import Foundation

enum PreviewLayout: Int, Codable, CaseIterable {
    /// Preview on the right (default): list left, preview right
    case previewRight = 0
    /// Preview on the left: preview left, list right
    case previewLeft = 1
    /// Preview at bottom: list top, preview bottom
    case previewBottom = 2

    var next: PreviewLayout {
        switch self {
        case .previewRight: return .previewLeft
        case .previewLeft: return .previewBottom
        case .previewBottom: return .previewRight
        }
    }

    var shortName: String {
        switch self {
        case .previewRight: return "R"
        case .previewLeft: return "L"
        case .previewBottom: return "B"
        }
    }

    var title: String {
        switch self {
        case .previewRight: return "Preview Right"
        case .previewLeft: return "Preview Left"
        case .previewBottom: return "Preview Bottom"
        }
    }
}

enum ItemFilter: Int, Codable, CaseIterable {
    case all = 0
    case text = 1
    case images = 2

    var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .images: return "Images"
        }
    }
}
