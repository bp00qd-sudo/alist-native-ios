// Package alistnative exposes the AList server lifecycle to the native iOS shell.
// This file is copied into the pinned AList source tree by the macOS build.
package alistnative

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
	"github.com/alist-org/alist/v3/cmd/flags"
	"github.com/alist-org/alist/v3/internal/bootstrap"
	"github.com/alist-org/alist/v3/internal/bootstrap/data"
	_ "github.com/alist-org/alist/v3/internal/archive"
	"github.com/alist-org/alist/v3/internal/conf"
	"github.com/alist-org/alist/v3/internal/db"
	"github.com/alist-org/alist/v3/internal/frp"
	"github.com/alist-org/alist/v3/internal/fs"
	_ "github.com/alist-org/alist/v3/internal/offline_download"
	"github.com/alist-org/alist/v3/internal/stream"
	alistserver "github.com/alist-org/alist/v3/server"
	"github.com/gin-gonic/gin"
	log "github.com/sirupsen/logrus"
)

// Engine owns one embedded AList server. It deliberately exposes only simple
// types so gomobile can generate a small and stable Objective-C bridge.
type Engine struct {
	mu       sync.Mutex
	server   *http.Server
	listener net.Listener
	done     chan struct{}
	dataDir  string
	password string
	address  string
	port     int
	baseURL  string
	status   string
	message  string
}

// NewEngine creates an engine. No database, driver or network client is
// initialized until Start is called.
func NewEngine(dataDir, adminPassword string) *Engine {
	return &Engine{
		dataDir:  filepath.Clean(dataDir),
		password: adminPassword,
		address:  "0.0.0.0",
		port:     5244,
		status:   "stopped",
	}
}

// SetListenPort changes the HTTP/WebDAV port before Start. The address remains
// LAN-accessible by design; there is no loopback-only mode in this product.
func (e *Engine) SetListenPort(port int) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.status == "running" || e.status == "starting" {
		return
	}
	if port > 0 && port <= 65535 {
		e.port = port
	}
}

// Start initializes AList once and starts its main HTTP/WebDAV listener.
func (e *Engine) Start() error {
	e.mu.Lock()
	if e.status == "running" || e.status == "starting" {
		e.mu.Unlock()
		return nil
	}
	e.status = "starting"
	e.message = "initializing AList"
	dataDir, password, address, port := e.dataDir, e.password, e.address, e.port
	e.mu.Unlock()

	if dataDir == "" {
		return e.fail(errors.New("AList data directory is empty"))
	}
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		return e.fail(fmt.Errorf("create data directory: %w", err))
	}

	// AList's first-user bootstrap reads this variable. It is set only before
	// initialization and is never written to logs by the iOS patch set.
	if password != "" {
		if err := os.Setenv("ALIST_ADMIN_PASSWORD", password); err != nil {
			return e.fail(fmt.Errorf("set initial admin password: %w", err))
		}
	}

	flags.DataDir = dataDir
	flags.Debug = false
	flags.Dev = false
	flags.NoPrefix = true
	flags.ForceBinDir = false
	flags.LogStd = false

	bootstrap.InitConfig()
	bootstrap.Log()
	bootstrap.InitDB()
	data.InitData()
	bootstrap.InitStreamLimit()
	bootstrap.InitIndex()
	bootstrap.InitUpgradePatch()
	bootstrap.InitTaskManager()

	// The config file remains the persistence source, while these values are
	// enforced for the embedded iOS service instance.
	conf.Conf.Scheme.Address = address
	conf.Conf.Scheme.HttpPort = port
	conf.Conf.Scheme.HttpsPort = -1
	conf.Conf.Scheme.UnixFile = ""
	conf.Conf.Scheme.ForceHttps = false
	conf.URL.Path = ""
	bootstrap.LoadStorages()
	bootstrap.InitFRP()

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.LoggerWithWriter(log.StandardLogger().Out), gin.RecoveryWithWriter(log.StandardLogger().Out))
	alistserver.Init(r)

	listener, err := net.Listen("tcp", fmt.Sprintf("%s:%d", address, port))
	if err != nil {
		_ = db.Close()
		return e.fail(fmt.Errorf("listen on %s:%d: %w", address, port, err))
	}

	srv := &http.Server{
		Handler:           r,
		ReadHeaderTimeout: 15 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}

	e.mu.Lock()
	e.server = srv
	e.listener = listener
	e.done = make(chan struct{})
	e.baseURL = fmt.Sprintf("http://%s:%d", lanAddress(listener, address), port)
	e.status = "running"
	e.message = "HTTP and WebDAV are ready"
	e.mu.Unlock()

	go func() {
		err := srv.Serve(listener)
		e.mu.Lock()
		defer e.mu.Unlock()
		if err != nil && !errors.Is(err, http.ErrServerClosed) && e.status != "stopping" {
			e.status = "error"
			e.message = err.Error()
		}
		if e.done != nil {
			close(e.done)
			e.done = nil
		}
	}()
	return nil
}

func (e *Engine) fail(err error) error {
	e.mu.Lock()
	e.status = "error"
	e.message = err.Error()
	e.mu.Unlock()
	return err
}

func lanAddress(listener net.Listener, configured string) string {
	if configured != "0.0.0.0" && configured != "" {
		return configured
	}
	host, _, err := net.SplitHostPort(listener.Addr().String())
	if err == nil && host != "0.0.0.0" && host != "::" {
		return host
	}
	return "局域网地址"
}

// Stop gracefully stops HTTP/WebDAV and closes AList's database.
func (e *Engine) Stop() error {
	e.mu.Lock()
	if e.server == nil {
		e.status = "stopped"
		e.message = "service is stopped"
		e.mu.Unlock()
		return nil
	}
	e.status = "stopping"
	srv := e.server
	done := e.done
	e.server = nil
	e.listener = nil
	e.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	err := srv.Shutdown(ctx)
	if done != nil {
		select {
		case <-done:
		case <-ctx.Done():
		}
	}
	frp.Instance.Stop()
	fs.ArchiveContentUploadTaskManager.RemoveAll()
	_ = db.Close()

	e.mu.Lock()
	e.status = "stopped"
	e.message = "service is stopped"
	e.mu.Unlock()
	return err
}

// URL returns the LAN HTTP base URL after Start.
func (e *Engine) URL() string {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.baseURL
}

// StatusJSON returns a compact status snapshot for the SwiftUI dashboard.
func (e *Engine) StatusJSON() string {
	e.mu.Lock()
	defer e.mu.Unlock()
	b, _ := json.Marshal(map[string]string{
		"status":  e.status,
		"message": e.message,
		"url":     e.baseURL,
	})
	return string(b)
}

// LogsJSON is intentionally bounded. The native shell can later be connected
// to the fixed-size iOS log sink without retaining an unbounded log history.
func (e *Engine) LogsJSON(limit int) string {
	if limit < 1 {
		limit = 1
	}
	if limit > 256 {
		limit = 256
	}
	return "[]"
}

var _ = stream.ClientDownloadLimit
