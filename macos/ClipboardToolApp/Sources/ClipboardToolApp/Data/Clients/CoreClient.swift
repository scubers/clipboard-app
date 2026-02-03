import Foundation

/// Errors returned by the Go core dylib.
enum CoreError: Error, CustomStringConvertible {
    case rc(Int32, String)

    var description: String {
        switch self {
        case let .rc(code, msg):
            return "core rc=\(code): \(msg)"
        }
    }
}

/// Thin Swift wrapper around the Go core C ABI.
///
/// Rule: UI must not call C symbols directly. Only this client (or a Repository)
/// should bridge to the core.
final class CoreClient {
    fileprivate var core: UnsafeMutableRawPointer?

    deinit {
        close()
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

    func close() {
        if core != nil {
            _ = ct_core_close(core)
            core = nil
        }
    }

    /// Close and reopen core with a new shared data directory.
    func reopen(dataDir: String) throws {
        close()
        try open(dataDir: dataDir)
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

    func touchLastCopied(id: String) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let rc = id.withCString { cid in
            ct_items_touch_last_copied(core, cid, nowMs)
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func setOCRText(id: String, text: String, status: Int32) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let rc = id.withCString { cid in
            text.withCString { ctext in
                ct_items_set_ocr_text(core, cid, status == 1 ? ctext : nil, status, nowMs)
            }
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func listImagesNeedingOCR(limit: Int32 = 6) throws -> [Item] {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = ct_items_list_images_needing_ocr_json(core, limit, &out)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        defer { if let out { ct_free(out) } }
        let json = String(cString: out!)
        return try JSONDecoder().decode([Item].self, from: Data(json.utf8))
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

    func removeHistory(keepPinned: Bool) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = ct_items_remove_history(core, keepPinned ? 1 : 0)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func deleteItem(id: String) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = id.withCString { cid in
            ct_items_delete_physical(core, cid)
        }
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

    // MARK: - Tags

    func addTag(itemID: String, tagName: String, colorHex: String? = nil) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = itemID.withCString { cid in
            tagName.withCString { cname in
                colorHex?.withCString { ccolor in
                    ct_items_add_tag(core, cid, cname, ccolor)
                } ?? ct_items_add_tag(core, cid, cname, nil)
            }
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func removeTag(itemID: String, tagID: String) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = itemID.withCString { cid in
            tagID.withCString { ctid in
                ct_items_remove_tag(core, cid, ctid)
            }
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func getTags(itemID: String) throws -> [ItemTag] {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = itemID.withCString { cid in
            ct_items_get_tags(core, cid, &out)
        }
        if rc != 0 {
            let errMsg = Self.lastError()
            print("[CoreClient] getTags failed: rc=\(rc), error=\(errMsg)")
            throw CoreError.rc(rc, errMsg)
        }
        guard let out else {
            print("[CoreClient] getTags: out is nil despite rc=0")
            throw CoreError.rc(-1, "getTags returned nil")
        }
        defer { ct_free(out) }
        let json = String(cString: out)
        print("[CoreClient] getTags JSON: \(json)")
        return try JSONDecoder().decode([ItemTag].self, from: Data(json.utf8))
    }

    func listTags() throws -> [TagWithCount] {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        var out: UnsafeMutablePointer<CChar>? = nil
        let rc = ct_tags_list(core, &out)
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
        defer { if let out { ct_free(out) } }
        let json = String(cString: out!)
        return try JSONDecoder().decode([TagWithCount].self, from: Data(json.utf8))
    }

    func renameTag(tagID: String, newName: String) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = tagID.withCString { ctid in
            newName.withCString { cname in
                ct_tags_rename(core, ctid, cname)
            }
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }

    func deleteTag(tagID: String) throws {
        guard let core else { throw CoreError.rc(-1, "core not opened") }
        let rc = tagID.withCString { ctid in
            ct_tags_delete(core, ctid)
        }
        if rc != 0 {
            throw CoreError.rc(rc, Self.lastError())
        }
    }
}
