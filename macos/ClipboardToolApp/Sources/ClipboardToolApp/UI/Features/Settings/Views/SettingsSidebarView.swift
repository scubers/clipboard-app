import AppKit
import SwiftUI

struct SettingsSidebarView: View {
    @Binding var selection: SettingsPage

    var body: some View {
        List(SettingsPage.allCases, selection: $selection) { page in
            Label(page.rawValue, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }
}
