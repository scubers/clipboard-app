import Foundation

// We avoid a bridging header by declaring the needed C symbols directly.
// The dylib is produced from Go core and linked via Package.swift.

@_silgen_name("ct_last_error_message")
func ct_last_error_message() -> UnsafePointer<CChar>?

@_silgen_name("ct_core_open")
func ct_core_open(_ dataDir: UnsafePointer<CChar>?, _ outCore: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32

@_silgen_name("ct_core_close")
func ct_core_close(_ core: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("ct_items_list_json")
func ct_items_list_json(_ core: UnsafeMutableRawPointer?, _ limit: Int32, _ offset: Int32, _ includeDeleted: Int32, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_search_json")
func ct_items_search_json(_ core: UnsafeMutableRawPointer?, _ query: UnsafePointer<CChar>?, _ limit: Int32, _ offset: Int32, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_search_json_ex")
func ct_items_search_json_ex(_ core: UnsafeMutableRawPointer?, _ query: UnsafePointer<CChar>?, _ limit: Int32, _ offset: Int32, _ includeDeleted: Int32, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_get_text")
func ct_items_get_text(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ outText: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_add_text")
func ct_items_add_text(_ core: UnsafeMutableRawPointer?, _ text: UnsafePointer<CChar>?, _ sourceApp: UnsafePointer<CChar>?, _ createdAtMs: Int64, _ outID: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_add_image")
func ct_items_add_image(_ core: UnsafeMutableRawPointer?, _ mime: UnsafePointer<CChar>?, _ dataPtr: UnsafeRawPointer?, _ dataLen: Int32, _ sourceApp: UnsafePointer<CChar>?, _ createdAtMs: Int64, _ outID: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_get_blob_path")
func ct_items_get_blob_path(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ outPath: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_set_pinned")
func ct_items_set_pinned(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ pinned: Int32) -> Int32

@_silgen_name("ct_items_soft_delete")
func ct_items_soft_delete(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ deletedAtMs: Int64) -> Int32

@_silgen_name("ct_items_clear_all")
func ct_items_clear_all(_ core: UnsafeMutableRawPointer?, _ keepPinned: Int32, _ deletedAtMs: Int64) -> Int32

@_silgen_name("ct_db_optimize")
func ct_db_optimize(_ core: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("ct_db_vacuum")
func ct_db_vacuum(_ core: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("ct_db_integrity_check_json")
func ct_db_integrity_check_json(_ core: UnsafeMutableRawPointer?, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_stats_json")
func ct_items_stats_json(_ core: UnsafeMutableRawPointer?, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_export_to_dir")
func ct_export_to_dir(_ core: UnsafeMutableRawPointer?, _ destDir: UnsafePointer<CChar>?) -> Int32

@_silgen_name("ct_import_from_dir")
func ct_import_from_dir(_ core: UnsafeMutableRawPointer?, _ srcDir: UnsafePointer<CChar>?, _ keepBackup: Int32) -> Int32

@_silgen_name("ct_settings_get_privacy_mode")
func ct_settings_get_privacy_mode(_ core: UnsafeMutableRawPointer?, _ outEnabled: UnsafeMutablePointer<Int32>?) -> Int32

@_silgen_name("ct_settings_set_privacy_mode")
func ct_settings_set_privacy_mode(_ core: UnsafeMutableRawPointer?, _ enabled: Int32) -> Int32

@_silgen_name("ct_settings_get_retention_max")
func ct_settings_get_retention_max(_ core: UnsafeMutableRawPointer?, _ outMax: UnsafeMutablePointer<Int32>?) -> Int32

@_silgen_name("ct_settings_set_retention_max")
func ct_settings_set_retention_max(_ core: UnsafeMutableRawPointer?, _ maxItems: Int32) -> Int32

@_silgen_name("ct_free")
func ct_free(_ p: UnsafeMutableRawPointer?)

enum CoreError: Error, CustomStringConvertible {
    case rc(Int32, String)

    var description: String {
        switch self {
        case let .rc(code, msg):
            return "core rc=\(code): \(msg)"
        }
    }
}

final class CoreClient {
    fileprivate var core: UnsafeMutableRawPointer?

    deinit {
        if core != nil {
            _ = ct_core_close(core)
            core = nil
        }
    }

    func open(dataDir: String) throws {
        guard core == nil else { return }
        var ptr: UnsafeMutableRawPointer? = nil
        let rc = dataDir.withCString { cstr in
            ct_core_open(cstr, &ptr)
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        core = ptr
    }

    func list(limit: Int32 = 200, offset: Int32 = 0) throws -> [Item] {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = ct_items_list_json(core, limit, offset, 0, &out)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        defer { if let out { ct_free(out) } }
        let json = String(cString: out!)
        return try JSONDecoder().decode([Item].self, from: Data(json.utf8))
    }

    func search(_ query: String, limit: Int32 = 200, offset: Int32 = 0) throws -> [Item] {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = query.withCString { q in
            ct_items_search_json(core, q, limit, offset, &out)
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        defer { if let out { ct_free(out) } }
        let json = String(cString: out!)
        return try JSONDecoder().decode([Item].self, from: Data(json.utf8))
    }

    func getText(id: String) throws -> String {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = id.withCString { cid in
            ct_items_get_text(core, cid, &out)
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        defer { if let out { ct_free(out) } }
        return String(cString: out!)
    }

    func addText(_ text: String, sourceApp: String? = nil) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var outID: UnsafeMutablePointer<CChar>? = nil
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let rc: Int32
        if let sourceApp {
            rc = sourceApp.withCString { capp in
                text.withCString { ctext in
                    ct_items_add_text(core, ctext, capp, nowMs, &outID)
                }
            }
        } else {
            rc = text.withCString { ctext in
                ct_items_add_text(core, ctext, nil, nowMs, &outID)
            }
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        if let outID { ct_free(outID) }
    }

    func addImage(mime: String, data: Data, sourceApp: String? = nil) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var outID: UnsafeMutablePointer<CChar>? = nil
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        let rc: Int32 = mime.withCString { cmime in
            data.withUnsafeBytes { buf in
                let ptr = buf.baseAddress
                let len = Int32(buf.count)
                if let sourceApp {
                    return sourceApp.withCString { capp in
                        ct_items_add_image(core, cmime, ptr, len, capp, nowMs, &outID)
                    }
                }
                return ct_items_add_image(core, cmime, ptr, len, nil, nowMs, &outID)
            }
        }

        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        if let outID { ct_free(outID) }
    }

    func getBlobPath(id: String) throws -> String {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = id.withCString { cid in
            ct_items_get_blob_path(core, cid, &out)
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        defer { if let out { ct_free(out) } }
        return String(cString: out!)
    }

    func getPrivacyMode() throws -> Bool {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var enabled: Int32 = 0
        let rc = ct_settings_get_privacy_mode(core, &enabled)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        return enabled != 0
    }

    func setPrivacyMode(_ enabled: Bool) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = ct_settings_set_privacy_mode(core, enabled ? 1 : 0)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func getRetentionMax() throws -> Int {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var v: Int32 = 0
        let rc = ct_settings_get_retention_max(core, &v)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        return Int(v)
    }

    func setRetentionMax(_ v: Int) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let vv = Int32(max(1, min(100000, v)))
        let rc = ct_settings_set_retention_max(core, vv)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func stats() throws -> Stats {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = ct_items_stats_json(core, &out)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        defer { if let out { ct_free(out) } }
        let json = String(cString: out!)
        return try JSONDecoder().decode(Stats.self, from: Data(json.utf8))
    }

    func optimize() throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = ct_db_optimize(core)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func vacuum() throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = ct_db_vacuum(core)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func integrityCheck() throws -> IntegrityResult {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = ct_db_integrity_check_json(core, &out)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        defer { if let out { ct_free(out) } }
        let json = String(cString: out!)
        return try JSONDecoder().decode(IntegrityResult.self, from: Data(json.utf8))
    }

    func clearAll(keepPinned: Bool) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = ct_items_clear_all(core, keepPinned ? 1 : 0, 0)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func exportToDir(_ path: String) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = path.withCString { cpath in
            ct_export_to_dir(core, cpath)
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func importFromDir(_ path: String, keepBackup: Bool = true) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = path.withCString { cpath in
            ct_import_from_dir(core, cpath, keepBackup ? 1 : 0)
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    static func lastError() -> String {
        ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    }
}

struct Item: Codable, Identifiable {
    let id: String
    let createdAtMs: Int64
    let type: String
    let summary: String
    let sourceApp: String?
    let pinned: Bool
}

struct Stats: Codable {
    let totalItems: Int64
    let activeItems: Int64
    let deletedItems: Int64
    let pinnedActiveItems: Int64
}

struct IntegrityResult: Codable {
    let ok: Bool
    let message: String
}
