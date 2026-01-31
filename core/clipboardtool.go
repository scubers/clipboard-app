package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"database/sql"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"unsafe"
)

// Minimal skeleton implementation.
// We only implement ct_core_open/close + ct_last_error_message + ct_free
// so the project is buildable. Full API will follow SPEC_CORE_ABI.md.

type core struct {
	dataDir   string
	db        *sql.DB
	settings  settings
	settingsP string
}

var (
	mu          sync.Mutex
	lastErrCStr *C.char
	coreNextID  uintptr = 1
	coreHandles         = map[uintptr]*core{}
)

func getCore(corePtr *C.void) (*core, bool) {
	h := ptrToHandle(corePtr)
	mu.Lock()
	c := coreHandles[h]
	mu.Unlock()
	return c, c != nil
}

func setErr(msg string) {
	mu.Lock()
	defer mu.Unlock()
	if lastErrCStr != nil {
		C.free(unsafe.Pointer(lastErrCStr))
		lastErrCStr = nil
	}
	lastErrCStr = C.CString(msg)
}

//export ct_last_error_message
func ct_last_error_message() *C.char {
	mu.Lock()
	defer mu.Unlock()
	return lastErrCStr
}

//export ct_free
func ct_free(p unsafe.Pointer) {
	C.free(p)
}

func handleToPtr(h uintptr) *C.void {
	return (*C.void)(unsafe.Pointer(h))
}

func ptrToHandle(p *C.void) uintptr {
	return uintptr(unsafe.Pointer(p))
}

//export ct_core_open
func ct_core_open(dataDir *C.char, outCore **C.void) C.int {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	if dataDir == nil || outCore == nil {
		setErr("invalid arg")
		return 2 // CT_ERR_INVALID_ARG
	}

	dir := C.GoString(dataDir)
	if !filepath.IsAbs(dir) {
		setErr("data_dir must be absolute")
		return 2
	}

	// Ensure directory structure exists.
	if err := os.MkdirAll(filepath.Join(dir, "config"), 0o755); err != nil {
		setErr("mkdir config: " + err.Error())
		return 3 // CT_ERR_IO
	}
	if err := os.MkdirAll(filepath.Join(dir, "data"), 0o755); err != nil {
		setErr("mkdir data: " + err.Error())
		return 3
	}

	db, err := openDB(dir)
	if err != nil {
		setErr(err.Error())
		return 4 // CT_ERR_DB
	}

	s, err := loadSettings(dir)
	if err != nil {
		setErr(err.Error())
		_ = db.Close()
		return 20 // CT_ERR_SETTINGS
	}
	// Ensure settings file exists on disk (so single-dir persistence is explicit)
	_ = saveSettings(dir, s)

	mu.Lock()
	id := coreNextID
	coreNextID++
	coreHandles[id] = &core{dataDir: dir, db: db, settings: s, settingsP: settingsPath(dir)}
	mu.Unlock()

	*outCore = handleToPtr(id)
	return 0
}

//export ct_core_close
func ct_core_close(cptr *C.void) C.int {
	h := ptrToHandle(cptr)
	mu.Lock()
	c := coreHandles[h]
	delete(coreHandles, h)
	mu.Unlock()

	if c != nil && c.db != nil {
		_ = c.db.Close()
	}
	return 0
}

func main() {}
