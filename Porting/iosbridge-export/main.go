package main

/*
#include <stdint.h>
#include <stdlib.h>
*/
import "C"

import (
	"sync"
	"unsafe"

	core "github.com/alist-org/alist/v3/iosbridge"
)

var (
	handlesMu sync.Mutex
	handles   = map[uintptr]*core.Engine{}
	nextID    uintptr = 1
)

func engineFor(handle C.uintptr_t) *core.Engine {
	handlesMu.Lock()
	defer handlesMu.Unlock()
	return handles[uintptr(handle)]
}

func cString(value *C.char) string {
	if value == nil {
		return ""
	}
	return C.GoString(value)
}

func copyString(value string) *C.char {
	return C.CString(value)
}

//export AListEngineNew
func AListEngineNew(dataDir *C.char, password *C.char) C.uintptr_t {
	engine := core.NewEngine(cString(dataDir), cString(password))
	handlesMu.Lock()
	id := nextID
	nextID++
	handles[id] = engine
	handlesMu.Unlock()
	return C.uintptr_t(id)
}

//export AListEngineSetAdminPassword
func AListEngineSetAdminPassword(handle C.uintptr_t, password *C.char) C.int32_t {
	engine := engineFor(handle)
	if engine == nil {
		return -1
	}
	if err := engine.SetAdminPassword(cString(password)); err != nil {
		return -1
	}
	return 0
}

//export AListEngineSetListenPort
func AListEngineSetListenPort(handle C.uintptr_t, port C.int32_t) {
	if engine := engineFor(handle); engine != nil {
		engine.SetListenPort(int(port))
	}
}

//export AListEngineStart
func AListEngineStart(handle C.uintptr_t) C.int32_t {
	engine := engineFor(handle)
	if engine == nil {
		return -1
	}
	if err := engine.Start(); err != nil {
		return -1
	}
	return 0
}

//export AListEngineStop
func AListEngineStop(handle C.uintptr_t) C.int32_t {
	engine := engineFor(handle)
	if engine == nil {
		return -1
	}
	if err := engine.Stop(); err != nil {
		return -1
	}
	return 0
}

//export AListEngineURL
func AListEngineURL(handle C.uintptr_t) *C.char {
	if engine := engineFor(handle); engine != nil {
		return copyString(engine.URL())
	}
	return copyString("")
}

//export AListEngineStatusJSON
func AListEngineStatusJSON(handle C.uintptr_t) *C.char {
	if engine := engineFor(handle); engine != nil {
		return copyString(engine.StatusJSON())
	}
	return copyString(`{"status":"invalid"}`)
}

//export AListEngineLogsJSON
func AListEngineLogsJSON(handle C.uintptr_t, limit C.int32_t) *C.char {
	if engine := engineFor(handle); engine != nil {
		return copyString(engine.LogsJSON(int(limit)))
	}
	return copyString("[]")
}

//export AListEngineFree
func AListEngineFree(handle C.uintptr_t) {
	handlesMu.Lock()
	delete(handles, uintptr(handle))
	handlesMu.Unlock()
}

//export AListFreeString
func AListFreeString(value *C.char) {
	if value != nil {
		C.free(unsafe.Pointer(value))
	}
}

func main() {}
