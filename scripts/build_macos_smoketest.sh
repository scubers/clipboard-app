#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_BUILD="$ROOT_DIR/core/build"
MACOS_DIR="$ROOT_DIR/macos"
OUT_DIR="$MACOS_DIR/build"

mkdir -p "$OUT_DIR"

if [ ! -f "$CORE_BUILD/libclipboardtool.dylib" ]; then
  echo "[smoketest] core dylib not found; building core first"
  "$ROOT_DIR/scripts/build_core.sh"
fi

if [ ! -f "$CORE_BUILD/clipboardtool.h" ]; then
  echo "[smoketest] header not found at $CORE_BUILD/clipboardtool.h"
  exit 1
fi

cat > "$OUT_DIR/smoke.swift" <<'SWIFT'
import Foundation

// C symbols from clipboardtool.h
@_silgen_name("ct_last_error_message")
func ct_last_error_message() -> UnsafePointer<CChar>?

@_silgen_name("ct_core_open")
func ct_core_open(_ dataDir: UnsafePointer<CChar>?, _ outCore: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32

@_silgen_name("ct_core_close")
func ct_core_close(_ core: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("ct_items_add_text")
func ct_items_add_text(_ core: UnsafeMutableRawPointer?, _ text: UnsafePointer<CChar>?, _ sourceApp: UnsafePointer<CChar>?, _ createdAtMs: Int64, _ outID: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_list_json")
func ct_items_list_json(_ core: UnsafeMutableRawPointer?, _ limit: Int32, _ offset: Int32, _ includeDeleted: Int32, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_get_text")
func ct_items_get_text(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ outText: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_search_json")
func ct_items_search_json(_ core: UnsafeMutableRawPointer?, _ query: UnsafePointer<CChar>?, _ limit: Int32, _ offset: Int32, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_search_json_ex")
func ct_items_search_json_ex(_ core: UnsafeMutableRawPointer?, _ query: UnsafePointer<CChar>?, _ limit: Int32, _ offset: Int32, _ includeDeleted: Int32, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_items_set_pinned")
func ct_items_set_pinned(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ pinned: Int32) -> Int32

@_silgen_name("ct_items_soft_delete")
func ct_items_soft_delete(_ core: UnsafeMutableRawPointer?, _ id: UnsafePointer<CChar>?, _ deletedAtMs: Int64) -> Int32

@_silgen_name("ct_items_clear_all")
func ct_items_clear_all(_ core: UnsafeMutableRawPointer?, _ keepPinned: Int32, _ deletedAtMs: Int64) -> Int32

@_silgen_name("ct_db_optimize")
func ct_db_optimize(_ core: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("ct_items_stats_json")
func ct_items_stats_json(_ core: UnsafeMutableRawPointer?, _ outJSON: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32

@_silgen_name("ct_free")
func ct_free(_ p: UnsafeMutableRawPointer?)

let dir = (FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library/Application Support/ClipboardTool", isDirectory: true)
  .path as NSString).utf8String

var corePtr: UnsafeMutableRawPointer? = nil
let rc = ct_core_open(dir, &corePtr)
if rc != 0 {
  let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
  print("ct_core_open failed rc=\(rc): \(msg)")
  exit(1)
}

defer { _ = ct_core_close(corePtr) }
print("OK: core opened")

// Add one item
var outID: UnsafeMutablePointer<CChar>? = nil
let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
let rc2 = ct_items_add_text(corePtr, "hello from smoke" , nil, nowMs, &outID)
if rc2 != 0 {
  let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
  print("ct_items_add_text failed rc=\(rc2): \(msg)")
  exit(1)
}
let idStr = outID.map { String(cString: $0) }
if let outID { ct_free(outID) }
print("added id=\(idStr ?? "(nil)")")

// List json
var outJSON: UnsafeMutablePointer<CChar>? = nil
let rc3 = ct_items_list_json(corePtr, 10, 0, 0, &outJSON)
if rc3 != 0 {
  let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
  print("ct_items_list_json failed rc=\(rc3): \(msg)")
  exit(1)
}
if let outJSON {
  let json = String(cString: outJSON)
  print("list json=\(json)")
  ct_free(outJSON)
}

// Search json
var outSearch: UnsafeMutablePointer<CChar>? = nil
let rcS = ct_items_search_json(corePtr, "hello", 10, 0, &outSearch)
if rcS != 0 {
  let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
  print("ct_items_search_json failed rc=\(rcS): \(msg)")
  exit(1)
}
if let outSearch {
  let json = String(cString: outSearch)
  print("search json=\(json)")
  ct_free(outSearch)
}

// Search json (include deleted)
var outSearch2: UnsafeMutablePointer<CChar>? = nil
let rcS2 = ct_items_search_json_ex(corePtr, "hello", 10, 0, 1, &outSearch2)
if rcS2 != 0 {
  let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
  print("ct_items_search_json_ex failed rc=\(rcS2): \(msg)")
  exit(1)
}
if let outSearch2 {
  let json = String(cString: outSearch2)
  print("search (includeDeleted) json=\(json)")
  ct_free(outSearch2)
}

// Get text if id exists
if let idStr {
  var outText: UnsafeMutablePointer<CChar>? = nil
  let rc4 = ct_items_get_text(corePtr, idStr, &outText)
  if rc4 != 0 {
    let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    print("ct_items_get_text failed rc=\(rc4): \(msg)")
    exit(1)
  }
  if let outText {
    print("get_text=\(String(cString: outText))")
    ct_free(outText)
  }

  // Pin it
  let rcP = ct_items_set_pinned(corePtr, idStr, 1)
  if rcP != 0 {
    let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    print("ct_items_set_pinned failed rc=\(rcP): \(msg)")
    exit(1)
  }
  print("pinned ok")

  // Delete it
  let rcD = ct_items_soft_delete(corePtr, idStr, 0)
  if rcD != 0 {
    let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    print("ct_items_soft_delete failed rc=\(rcD): \(msg)")
    exit(1)
  }
  print("deleted ok")

  // List after delete
  var outJSON2: UnsafeMutablePointer<CChar>? = nil
  let rc5 = ct_items_list_json(corePtr, 10, 0, 0, &outJSON2)
  if rc5 != 0 {
    let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    print("ct_items_list_json after delete failed rc=\(rc5): \(msg)")
    exit(1)
  }
  if let outJSON2 {
    print("list after delete=\(String(cString: outJSON2))")
    ct_free(outJSON2)
  }

  // Clear all non-pinned items (keep pinned)
  let rcC = ct_items_clear_all(corePtr, 1, 0)
  if rcC != 0 {
    let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    print("ct_items_clear_all failed rc=\(rcC): \(msg)")
    exit(1)
  }
  print("clear_all(keepPinned=1) ok")

  let rcO = ct_db_optimize(corePtr)
  if rcO != 0 {
    let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    print("ct_db_optimize failed rc=\(rcO): \(msg)")
    exit(1)
  }
  print("db optimize ok")

  var outStats: UnsafeMutablePointer<CChar>? = nil
  let rcSt = ct_items_stats_json(corePtr, &outStats)
  if rcSt != 0 {
    let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    print("ct_items_stats_json failed rc=\(rcSt): \(msg)")
    exit(1)
  }
  if let outStats {
    print("stats json=\(String(cString: outStats))")
    ct_free(outStats)
  }

  var outJSON3: UnsafeMutablePointer<CChar>? = nil
  let rc6 = ct_items_list_json(corePtr, 50, 0, 1, &outJSON3)
  if rc6 != 0 {
    let msg = ct_last_error_message().map { String(cString: $0) } ?? "(no error message)"
    print("ct_items_list_json(includeDeleted) failed rc=\(rc6): \(msg)")
    exit(1)
  }
  if let outJSON3 {
    print("list includeDeleted after clear_all=\(String(cString: outJSON3))")
    ct_free(outJSON3)
  }
}
SWIFT

# Compile. We don't need to include the header because we declare symbols via @_silgen_name.
# Link against the dylib.

swiftc \
  -o "$OUT_DIR/smoke" \
  "$OUT_DIR/smoke.swift" \
  -L"$CORE_BUILD" -lclipboardtool \
  -Xlinker -rpath -Xlinker "$CORE_BUILD"

"$OUT_DIR/smoke"

echo "[smoketest] ok"
