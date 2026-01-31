package main

/*
#include <stdlib.h>
#include <pthread.h>

static uintptr_t ct_thread_id() {
    // pthread_t is opaque; casting is OK for use as a map key within a process.
    return (uintptr_t)pthread_self();
}
*/
import "C"

import (
	"database/sql"
	"fmt"
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
	hasFTS5   bool
	settings  settings
	settingsP string
}

var (
	mu sync.Mutex

	// Per-thread last error messages (C strings). Keyed by pthread_self().
	lastErrByThread = map[uintptr]*C.char{}

	coreHandles = map[uintptr]*core{}
)

func getCore(corePtr *C.void) (*core, bool) {
	if corePtr == nil {
		return nil, false
	}
	h := uintptr(unsafe.Pointer(corePtr))
	mu.Lock()
	c := coreHandles[h]
	mu.Unlock()
	return c, c != nil
}

func setErr(msg string) {
	tid := uintptr(C.ct_thread_id())
	mu.Lock()
	defer mu.Unlock()
	if p := lastErrByThread[tid]; p != nil {
		C.free(unsafe.Pointer(p))
		delete(lastErrByThread, tid)
	}
	lastErrByThread[tid] = C.CString(msg)
}

//export ct_last_error_message
func ct_last_error_message() *C.char {
	tid := uintptr(C.ct_thread_id())
	mu.Lock()
	defer mu.Unlock()
	return lastErrByThread[tid]
}

//export ct_free
func ct_free(p unsafe.Pointer) {
	C.free(p)
}

// We use a real C pointer as an opaque handle so Swift can round-trip it safely.
// The pointer value is used as the map key.
func newHandle() (*C.void, error) {
	p := C.malloc(1)
	if p == nil {
		return nil, fmt.Errorf("malloc handle failed")
	}
	return (*C.void)(p), nil
}

func freeHandle(p *C.void) {
	if p != nil {
		C.free(unsafe.Pointer(p))
	}
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

	hasFTS, _ := detectFTS5(db)

	s, err := loadSettings(dir)
	if err != nil {
		setErr(err.Error())
		_ = db.Close()
		return 20 // CT_ERR_SETTINGS
	}
	// Ensure settings file exists on disk (so single-dir persistence is explicit)
	_ = saveSettings(dir, s)

	h, herr := newHandle()
	if herr != nil {
		setErr(herr.Error())
		_ = db.Close()
		return 3
	}

	mu.Lock()
	coreHandles[uintptr(unsafe.Pointer(h))] = &core{dataDir: dir, db: db, hasFTS5: hasFTS, settings: s, settingsP: settingsPath(dir)}
	mu.Unlock()

	*outCore = h
	return 0
}

//export ct_core_close
func ct_core_close(cptr *C.void) C.int {
	mu.Lock()
	c := coreHandles[uintptr(unsafe.Pointer(cptr))]
	delete(coreHandles, uintptr(unsafe.Pointer(cptr)))
	mu.Unlock()

	if c != nil && c.db != nil {
		_ = c.db.Close()
	}
	freeHandle(cptr)
	return 0
}

func main() {}
