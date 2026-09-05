// Package iosbridge exposes the AList core lifecycle to a native iOS shell.
// It is intentionally kept as a small JSON/string bridge for gomobile.
package iosbridge

import (
    "context"
    "encoding/json"
    "errors"
    "fmt"
    "net"
    "net/http"
    "os"
    "path/filepath"
    "sync"
    "time"

    _ "github.com/alist-org/alist/v3/drivers"
    _ "github.com/alist-org/alist/v3/internal/archive"
    "github.com/alist-org/alist/v3/cmd/flags"
    "github.com/alist-org/alist/v3/internal/bootstrap"
    "github.com/alist-org/alist/v3/internal/bootstrap/data"
    "github.com/alist-org/alist/v3/internal/conf"
    "github.com/alist-org/alist/v3/internal/db"
    "github.com/alist-org/alist/v3/internal/frp"
    "github.com/alist-org/alist/v3/internal/fs"
    "github.com/alist-org/alist/v3/internal/op"
    _ "github.com/alist-org/alist/v3/internal/offline_download"
    "github.com/alist-org/alist/v3/server"
    "github.com/gin-gonic/gin"
    log "github.com/sirupsen/logrus"
)

type Engine struct {
    mu sync.Mutex
    server *http.Server
    listener net.Listener
    dataDir string
    password string
    address string
    port int
    baseURL string
    status string
    message string
}

func NewEngine(dataDir, adminPassword string) *Engine {
    return &Engine{dataDir: filepath.Clean(dataDir), password: adminPassword, address: "0.0.0.0", port: 5244, status: "stopped"}
}

func (e *Engine) SetAdminPassword(password string) error {
    e.mu.Lock()
    defer e.mu.Unlock()
    if e.status == "running" || e.status == "starting" { return errors.New("cannot change password while service is running") }
    if password == "" { return errors.New("admin password cannot be empty") }
    e.password = password
    return nil
}

// UpdateAdminPassword updates the persisted AList admin user after bootstrap.
func (e *Engine) UpdateAdminPassword(password string) error {
    if password == "" { return errors.New("admin password cannot be empty") }
    admin, err := op.GetAdmin()
    if err != nil { return err }
    admin.SetPassword(password)
    return op.UpdateUser(admin)
}

func (e *Engine) SetListenPort(port int) {
    e.mu.Lock(); defer e.mu.Unlock()
    if e.status == "running" || e.status == "starting" { return }
    if port > 0 && port <= 65535 { e.port = port }
}

func (e *Engine) Start() error {
    e.mu.Lock()
    if e.status == "running" || e.status == "starting" { e.mu.Unlock(); return nil }
    e.status, e.message = "starting", "正在初始化 AList"
    dataDir, password, address, port := e.dataDir, e.password, e.address, e.port
    e.mu.Unlock()
    if dataDir == "" { return e.fail(errors.New("AList data directory is empty")) }
    if err := os.MkdirAll(dataDir, 0700); err != nil { return e.fail(err) }

    // The upstream first-user bootstrap reads this only during initialization.
    if password != "" { _ = os.Setenv("ALIST_ADMIN_PASSWORD", password) }
    flags.DataDir, flags.Debug, flags.Dev, flags.NoPrefix, flags.ForceBinDir, flags.LogStd = dataDir, false, false, true, false, false
    bootstrap.InitConfig(); bootstrap.Log(); bootstrap.InitDB(); data.InitData(); bootstrap.InitStreamLimit(); bootstrap.InitIndex(); bootstrap.InitUpgradePatch(); bootstrap.InitTaskManager()
    conf.Conf.Scheme.Address, conf.Conf.Scheme.HttpPort, conf.Conf.Scheme.HttpsPort = address, port, -1
    conf.Conf.Scheme.UnixFile, conf.Conf.Scheme.ForceHttps = "", false
    bootstrap.LoadStorages(); bootstrap.InitFRP()

    gin.SetMode(gin.ReleaseMode)
    r := gin.New()
    r.Use(gin.LoggerWithWriter(log.StandardLogger().Out), gin.RecoveryWithWriter(log.StandardLogger().Out))
    server.Init(r)
    listener, err := net.Listen("tcp", fmt.Sprintf("%s:%d", address, port))
    if err != nil { db.Close(); return e.fail(err) }
    srv := &http.Server{Handler: r, ReadHeaderTimeout: 15 * time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 1 << 20}
    e.mu.Lock(); e.server, e.listener, e.baseURL, e.status, e.message = srv, listener, fmt.Sprintf("http://%s:%d", address, port), "running", "HTTP 与 WebDAV 已就绪"; e.mu.Unlock()
    go func() {
        err := srv.Serve(listener)
        e.mu.Lock(); defer e.mu.Unlock()
        if err != nil && !errors.Is(err, http.ErrServerClosed) && e.status != "stopping" { e.status, e.message = "error", err.Error() }
    }()
    return nil
}

func (e *Engine) fail(err error) error { e.mu.Lock(); e.status, e.message = "error", err.Error(); e.mu.Unlock(); return err }

func (e *Engine) Stop() error {
    e.mu.Lock(); srv := e.server; if srv == nil { e.status = "stopped"; e.mu.Unlock(); return nil }; e.status = "stopping"; e.server, e.listener = nil, nil; e.mu.Unlock()
    ctx, cancel := context.WithTimeout(context.Background(), time.Second); defer cancel()
    err := srv.Shutdown(ctx)
    if frp.Instance != nil { frp.Instance.Stop() }
    if fs.ArchiveContentUploadTaskManager != nil { fs.ArchiveContentUploadTaskManager.RemoveAll() }
    db.Close()
    e.mu.Lock(); e.status, e.message = "stopped", "服务已停止"; e.mu.Unlock()
    return err
}

func (e *Engine) URL() string { e.mu.Lock(); defer e.mu.Unlock(); return e.baseURL }
func (e *Engine) StatusJSON() string { e.mu.Lock(); defer e.mu.Unlock(); b, _ := json.Marshal(map[string]string{"status": e.status, "message": e.message, "url": e.baseURL}); return string(b) }
func (e *Engine) LogsJSON(limit int) string { if limit < 1 { limit = 1 }; if limit > 256 { limit = 256 }; return "[]" }
