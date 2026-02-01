import Foundation

// AppPaths defines the separation between:
// - Local config: fixed to ~/Library/Application Support/${APP_NAME}/local
// - Shared config/data: user-configurable, defaulting to .../shared
//
// Local config stores the chosen shared directory so users can place it in a
// cloud-synced folder for cross-device sync.

enum AppPaths {
    static let appName = "ClipboardTool"

    // ~/Library/Application Support/ClipboardTool
    private static var appSupportBase: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
    }

    // ~/Library/Application Support/ClipboardTool/local
    static var localBaseDir: URL {
        appSupportBase.appendingPathComponent("local", isDirectory: true)
    }

    // ~/Library/Application Support/ClipboardTool/shared
    static var defaultSharedBaseDir: URL {
        appSupportBase.appendingPathComponent("shared", isDirectory: true)
    }

    static var localConfigPath: URL {
        localBaseDir.appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("local.json", isDirectory: false)
    }

    struct LocalConfig: Codable {
        var version: Int = 1
        var sharedDir: String? = nil
    }

    static func loadLocalConfig() -> LocalConfig {
        do {
            let data = try Data(contentsOf: localConfigPath)
            return try JSONDecoder().decode(LocalConfig.self, from: data)
        } catch {
            return LocalConfig()
        }
    }

    static func saveLocalConfig(_ cfg: LocalConfig) throws {
        let dir = localConfigPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(cfg)
        let tmp = localConfigPath.appendingPathExtension("tmp")
        try data.write(to: tmp, options: [.atomic])
        // Atomic rename
        _ = try? FileManager.default.removeItem(at: localConfigPath)
        try FileManager.default.moveItem(at: tmp, to: localConfigPath)
    }

    static func effectiveSharedDir() -> URL {
        let cfg = loadLocalConfig()
        if let s = cfg.sharedDir, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Expand ~
            let expanded = (s as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return defaultSharedBaseDir
    }

    static func setSharedDir(_ url: URL) throws {
        var cfg = loadLocalConfig()
        cfg.sharedDir = url.path
        try saveLocalConfig(cfg)
    }
}
