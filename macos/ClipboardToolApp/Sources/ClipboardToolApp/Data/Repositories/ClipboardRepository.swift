import Foundation

/// Repository abstraction over clipboard data & maintenance.
///
/// UI/ViewModels should prefer this over talking to CoreClient directly.
protocol ClipboardRepository {
    func open(dataDir: String) throws
    func reopen(dataDir: String) throws

    func list(limit: Int32, offset: Int32) throws -> [Item]
    func search(_ query: String, limit: Int32, offset: Int32) throws -> [Item]

    func getText(id: String) throws -> String
    func getBlobPath(id: String) throws -> String

    func addText(_ text: String, sourceApp: String?) throws
    func addImage(mime: String, data: Data, sourceApp: String?) throws

    func touchLastCopied(id: String) throws

    // OCR helpers
    func setOCRText(id: String, text: String, status: Int32) throws
    func listImagesNeedingOCR(limit: Int32) throws -> [Item]

    // Settings (core)
    func getPrivacyMode() throws -> Bool
    func setPrivacyMode(_ enabled: Bool) throws
    func getRetentionMax() throws -> Int
    func setRetentionMax(_ v: Int) throws

    // Maintenance
    func stats() throws -> Stats
    func optimize() throws
    func vacuum() throws
    func integrityCheck() throws -> IntegrityResult

    func removeHistory(keepPinned: Bool) throws
    func deleteItem(id: String) throws

    // Transfer
    func exportToDir(_ path: String) throws
    func importFromDir(_ path: String, keepBackup: Bool) throws
    
    // Tags
    func getTags(itemID: String) throws -> [ItemTag]
    func addTag(itemID: String, tagName: String) throws
    func removeTag(itemID: String, tagID: String) throws
    func listTags() throws -> [TagWithCount]
    func renameTag(tagID: String, newName: String) throws
    func deleteTag(tagID: String) throws
}
