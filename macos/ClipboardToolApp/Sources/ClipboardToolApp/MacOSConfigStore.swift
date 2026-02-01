import Foundation

/// MacOSConfigStore persists *macOS-only* settings into the shared directory
/// so they can sync across machines.
///
/// This file is owned by the macOS Swift app. Go core should not write it.
enum MacOSConfigStore {
    struct Config: Codable {
        var version: Int = 1

        // General (macOS)
        var monitoringEnabled: Bool = true
        var pollIntervalMs: Double = 500

        // Layout (macOS UI)
        var previewLayout: PreviewLayout = .previewRight

        // Appearance (macOS UI)
        var backgroundTint: Double = 0.35
        var hideTrafficLights: Bool = true

        // Preview (macOS UI)
        var previewWrap: Bool = true
        var previewMonospace: Bool = true
    }

    static func configPath(sharedDir: String) -> URL {
        let base = URL(fileURLWithPath: sharedDir, isDirectory: true)
        return base.appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("macos.json", isDirectory: false)
    }

    static func load(sharedDir: String) -> Config? {
        let p = configPath(sharedDir: sharedDir)
        guard let data = try? Data(contentsOf: p) else { return nil }
        return try? JSONDecoder().decode(Config.self, from: data)
    }

    static func save(_ cfg: Config, sharedDir: String) throws {
        let p = configPath(sharedDir: sharedDir)
        let dir = p.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(cfg)

        let tmp = p.appendingPathExtension("tmp")
        try data.write(to: tmp, options: [.atomic])
        _ = try? FileManager.default.removeItem(at: p)
        try FileManager.default.moveItem(at: tmp, to: p)
    }
}
