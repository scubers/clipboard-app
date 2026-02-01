import SwiftUI

struct PillButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                // Make the whole visual capsule area clickable, not just the text.
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(
            Capsule()
                .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .foregroundStyle(selected ? .primary : .secondary)
    }
}
