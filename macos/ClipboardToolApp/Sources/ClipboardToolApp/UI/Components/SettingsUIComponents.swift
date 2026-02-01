import AppKit
import SwiftUI

struct SettingsHeader: View {
    let title: String
    let subtitle: String

    private var versionText: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return v.map { "v\($0)" } ?? "v0.1"
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(versionText)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .overlay(Capsule().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 6)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13.5, weight: .heavy))
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }
}

struct SettingsRow<Right: View>: View {
    let title: String
    @ViewBuilder var right: Right

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            right
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

struct SettingsPathText: View {
    let path: String
    var body: some View {
        Text(path)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: 360, alignment: .trailing)
    }
}
