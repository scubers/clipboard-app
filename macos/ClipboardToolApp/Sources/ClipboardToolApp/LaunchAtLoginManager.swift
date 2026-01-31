import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var enabled: Bool = false

    private init() {
        refresh()
    }

    func refresh() {
        enabled = (SMAppService.mainApp.status == .enabled)
    }

    func setEnabled(_ newValue: Bool) throws {
        if newValue {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        refresh()
    }
}
