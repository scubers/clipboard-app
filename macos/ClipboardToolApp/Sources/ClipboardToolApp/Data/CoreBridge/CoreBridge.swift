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

@_silgen_name("ct_items_touch_last_copied")
func ct_items_touch_last_copied(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ copiedAtMs: Int64) -> Int32

@_silgen_name("ct_items_set_ocr_text")
func ct_items_set_ocr_text(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ ocrText: UnsafePointer<CChar>?, _ status: Int32, _ updatedAtMs: Int64) -> Int32

@_silgen_name("ct_items_list_images_needing_ocr_json")
func ct_items_list_images_needing_ocr_json(_ core: UnsafeMutableRawPointer?, _ limit: Int32, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_clear_all")
func ct_items_clear_all(_ core: UnsafeMutableRawPointer?, _ keepPinned: Int32, _ deletedAtMs: Int64) -> Int32

@_silgen_name("ct_items_remove_history")
func ct_items_remove_history(_ core: UnsafeMutableRawPointer?, _ keepPinned: Int32) -> Int32

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
