import SwiftUI

struct ItemRowView: View {
    let item: Item
    let selected: Bool

    private var timeText: String {
        Date(timeIntervalSince1970: Double(item.lastCopiedAtMs) / 1000).formatted(date: .abbreviated, time: .shortened)
    }

    private var appColor: Color {
        let s = (item.sourceApp ?? "").unicodeScalars.map { UInt32($0.value) }.reduce(0, +)
        switch s % 5 {
        case 0: return .blue
        case 1: return .pink
        case 2: return .green
        case 3: return .orange
        default: return .purple
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.10))
                .overlay(
                    Image(systemName: item.type == "image" ? "photo" : "text.alignleft")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                )
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.summary)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(appColor.opacity(0.85))
                        .frame(width: 14, height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )

                    Text(item.sourceApp ?? "(Unknown)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(item.type == "image" ? "Image" : "Text")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if item.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .padding(.leading, 2)
                    }
                }
            }

            Spacer(minLength: 8)

            Text(timeText)
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selected ? Color.accentColor.opacity(0.22) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(selected ? 0.22 : 0.0), lineWidth: 1)
        )
    }
}
