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
    mu sync.Mutex
    engines = map[uintptr]*core.Engine{}
    next uintptr = 1
)

func get(h C.uintptr_t) *core.Engine { mu.Lock(); defer mu.Unlock(); return engines[uintptr(h)] }
func str(p *C.char) string { if p == nil { return "" }; return C.GoString(p) }
func out(v string) *C.char { return C.CString(v) }

//export AListEngineNew
func AListEngineNew(dataDir *C.char, password *C.char) C.uintptr_t {
    e := core.NewEngine(str(dataDir), str(password)); mu.Lock(); id := next; next++; engines[id] = e; mu.Unlock(); return C.uintptr_t(id)
}

//export AListEngineSetAdminPassword
func AListEngineSetAdminPassword(h C.uintptr_t, password *C.char) C.int32_t { e:=get(h); if e==nil{return -1}; if e.UpdateAdminPassword(str(password))!=nil{return -1}; return 0 }
//export AListEngineSetListenPort
func AListEngineSetListenPort(h C.uintptr_t, port C.int32_t) { if e:=get(h);e!=nil{e.SetListenPort(int(port))} }
//export AListEngineStart
func AListEngineStart(h C.uintptr_t) C.int32_t { e:=get(h);if e==nil{return -1};if e.Start()!=nil{return -1};return 0 }
//export AListEngineStop
func AListEngineStop(h C.uintptr_t) C.int32_t { e:=get(h);if e==nil{return -1};if e.Stop()!=nil{return -1};return 0 }
//export AListEngineURL
func AListEngineURL(h C.uintptr_t) *C.char {if e:=get(h);e!=nil{return out(e.URL())};return out("")}
//export AListEngineStatusJSON
func AListEngineStatusJSON(h C.uintptr_t) *C.char {if e:=get(h);e!=nil{return out(e.StatusJSON())};return out(`{"status":"invalid"}`)}
//export AListEngineLogsJSON
func AListEngineLogsJSON(h C.uintptr_t, limit C.int32_t) *C.char {if e:=get(h);e!=nil{return out(e.LogsJSON(int(limit)))};return out("[]")}
//export AListEngineFree
func AListEngineFree(h C.uintptr_t){mu.Lock();delete(engines,uintptr(h));mu.Unlock()}
//export AListFreeString
func AListFreeString(p *C.char){if p!=nil{C.free(unsafe.Pointer(p))}}
func main(){}
