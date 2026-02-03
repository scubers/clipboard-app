import Foundation

final class CoreClipboardRepository: ClipboardRepository {
    private let core: CoreClient

    init(core: CoreClient) {
        self.core = core
    }

    func open(dataDir: String) throws { try core.open(dataDir: dataDir) }
    func reopen(dataDir: String) throws { try core.reopen(dataDir: dataDir) }

    func list(limit: Int32 = 200, offset: Int32 = 0) throws -> [Item] { try core.list(limit: limit, offset: offset) }
    func search(_ query: String, limit: Int32 = 200, offset: Int32 = 0) throws -> [Item] { try core.search(query, limit: limit, offset: offset) }

    func getText(id: String) throws -> String { try core.getText(id: id) }
    func getBlobPath(id: String) throws -> String { try core.getBlobPath(id: id) }

    func addText(_ text: String, sourceApp: String? = nil) throws { try core.addText(text, sourceApp: sourceApp) }
    func addImage(mime: String, data: Data, sourceApp: String? = nil) throws { try core.addImage(mime: mime, data: data, sourceApp: sourceApp) }

    func touchLastCopied(id: String) throws { try core.touchLastCopied(id: id) }

    func setOCRText(id: String, text: String, status: Int32) throws { try core.setOCRText(id: id, text: text, status: status) }
    func listImagesNeedingOCR(limit: Int32) throws -> [Item] { try core.listImagesNeedingOCR(limit: limit) }

    func getPrivacyMode() throws -> Bool { try core.getPrivacyMode() }
    func setPrivacyMode(_ enabled: Bool) throws { try core.setPrivacyMode(enabled) }
    func getRetentionMax() throws -> Int { try core.getRetentionMax() }
    func setRetentionMax(_ v: Int) throws { try core.setRetentionMax(v) }

    func stats() throws -> Stats { try core.stats() }
    func optimize() throws { try core.optimize() }
    func vacuum() throws { try core.vacuum() }
    func integrityCheck() throws -> IntegrityResult { try core.integrityCheck() }

    func removeHistory(keepPinned: Bool) throws { try core.removeHistory(keepPinned: keepPinned) }
    func deleteItem(id: String) throws { try core.deleteItem(id: id) }

    func exportToDir(_ path: String) throws { try core.exportToDir(path) }
    func importFromDir(_ path: String, keepBackup: Bool) throws { try core.importFromDir(path, keepBackup: keepBackup) }
}
