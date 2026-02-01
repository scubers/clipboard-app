import SwiftUI

struct ItemRowView: View {
    let item: Item
    let selected: Bool

    private var timeText: String {
        let ts = TimeInterval(item.lastCopiedAtMs) / 1000
        let dt = Date(timeIntervalSince1970: ts)
        let now = Date()
        let delta = now.timeIntervalSince(dt)

        if delta < 60 {
            let sec = max(0, Int(delta.rounded(.down)))
            return "\(sec) 秒前"
        }
        if delta < 3600 {
            let min = max(1, Int((delta / 60).rounded(.down)))
            return "\(min) 分前"
        }

        if delta < 86400 {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "HH:mm:ss"
            return f.string(from: dt)
        }

        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: dt)
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
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.10))
                .overlay(
                    Image(systemName: item.type == "image" ? "photo" : "text.alignleft")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                )
                .frame(width: 18, height: 18)

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

                    if item.type == "image", item.ocrMatched == true {
                        Text("OCR")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                            .overlay(Capsule().stroke(Color.accentColor.opacity(0.22), lineWidth: 1))
                            .foregroundStyle(.secondary)
                    }

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(timeText)
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

        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
