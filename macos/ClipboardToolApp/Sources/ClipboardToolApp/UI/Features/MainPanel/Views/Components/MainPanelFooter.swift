import SwiftUI

struct MainPanelFooter: View {
    let count: Int

    var body: some View {
        HStack {
            Text("↑↓ select · ⌘↵ paste · ⌘C copy")
            Spacer()
            Text("\(count) items")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }
}
