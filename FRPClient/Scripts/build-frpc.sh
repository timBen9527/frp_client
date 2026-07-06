#!/bin/zsh
#
# build-frpc.sh
# FRPClient Xcode Build Phase Script
#
# This script runs before Swift compilation and handles:
# 1. Clone or update the fatedier/frp source code
# 2. Apply traffic monitoring patches to the source
# 3. Build the frpc binary with Go
#
# The resulting binary is placed inside the App Bundle at:
#   $BUILT_PRODUCTS_DIR/$EXECUTABLE_FOLDER_PATH/Resources/frpc
#
# Xcode will copy it into the final .app bundle automatically.
#
# Usage:
#   SRCROOT=/path/to/project \
#   BUILT_PRODUCTS_DIR=/path/to/DerivedData/.../Products \
#   EXECUTABLE_FOLDER_PATH=FRPClient.app/Contents/MacOS \
#   ./build-frpc.sh

set -euo pipefail

# Xcode's shell environment has a minimal PATH; ensure Homebrew binaries are available
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

GIT_URL="https://github.com/fatedier/frp.git"
SRC_DIR="${SRCROOT}/frp-src"

# Output to App Bundle Resources — this path is inside BUILT_PRODUCTS_DIR
# so Xcode will include it in the final .app
BUNDLE_RESOURCES="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}"
OUTPUT="${BUNDLE_RESOURCES}/frpc"

PATCH_MARKER="$SRC_DIR/.frpclient-patched"
PATCH_VERSION="1.0.0"
TEMP_DIR=$(mktemp -d)

# ─────────────────────────────────────────────────
# Utility functions
# ─────────────────────────────────────────────────

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

log() {
    echo "[FRP Build] $*"
}

fail() {
    echo "[FRP Build] ERROR: $*" >&2
    # Don't block the Xcode build — just warn
}

# ─────────────────────────────────────────────────
# Step 1: Clone or update frp source
# ─────────────────────────────────────────────────

log "Step 1/4: Checking frp source..."

mkdir -p "$(dirname "$SRC_DIR")"

if [ -d "$SRC_DIR/.git" ]; then
    log "Updating existing frp source..."
    if git -C "$SRC_DIR" fetch --depth 1 origin 2>&1; then
        git -C "$SRC_DIR" reset --hard origin/HEAD 2>&1 || log "WARNING: reset failed, using current source"
        # Reset patch marker since source was overwritten by git reset
        rm -f "$PATCH_MARKER"
        log "Source updated, patches will be reapplied"
    else
        log "WARNING: fetch failed, using existing source (may be offline)"
    fi
else
    log "Cloning frp source (shallow clone)..."
    if ! git clone --depth 1 "$GIT_URL" "$SRC_DIR" 2>&1; then
        fail "Git clone failed — frp source unavailable"
        exit 0
    fi
fi

log "Source ready at: $SRC_DIR"

# ─────────────────────────────────────────────────
# Step 2: Apply traffic monitoring patches
# ─────────────────────────────────────────────────

log "Step 2/4: Checking patches..."

CURRENT_MARKER=""
if [ -f "$PATCH_MARKER" ]; then
    CURRENT_MARKER=$(cat "$PATCH_MARKER")
fi

if [ "$CURRENT_MARKER" = "$PATCH_VERSION" ]; then
    log "Patches already applied (version $PATCH_VERSION), skipping"
else
    log "Applying traffic monitoring patches (version $PATCH_VERSION)..."

    # Patch 2a: traffic_tracker.go — global traffic counters + stdout push
    TRACKER_DIR="$SRC_DIR/pkg/util/net"
    mkdir -p "$TRACKER_DIR"
    cat > "$TRACKER_DIR/traffic_tracker.go" << 'GOEOF'
// Code injected by FRPClient for traffic monitoring
// Provides global atomic traffic counters per proxy name

package net

import (
    "encoding/json"
    "fmt"
    "os"
    "sync"
    "sync/atomic"
    "time"
)

type ProxyTraffic struct {
    Name           string
    Type           string
    BytesIn        atomic.Int64
    BytesOut       atomic.Int64
    TotalConns     atomic.Int64
    ActiveConns    atomic.Int64
    LastUpdateTime atomic.Int64 // unix nano
}

type TrafficTracker struct {
    mu      sync.RWMutex
    proxies map[string]*ProxyTraffic
}

var GlobalTrafficTracker = &TrafficTracker{
    proxies: make(map[string]*ProxyTraffic),
}

func (tt *TrafficTracker) GetOrCreate(name string) *ProxyTraffic {
    tt.mu.RLock()
    pt, ok := tt.proxies[name]
    tt.mu.RUnlock()
    if ok {
        return pt
    }
    tt.mu.Lock()
    defer tt.mu.Unlock()
    if pt, ok = tt.proxies[name]; ok {
        return pt
    }
    pt = &ProxyTraffic{Name: name}
    tt.proxies[name] = pt
    return pt
}

func (tt *TrafficTracker) AddTraffic(name string, bytesIn, bytesOut int64) {
    pt := tt.GetOrCreate(name)
    pt.BytesIn.Add(bytesIn)
    pt.BytesOut.Add(bytesOut)
    pt.LastUpdateTime.Store(time.Now().UnixNano())
}

func (tt *TrafficTracker) ConnOpened(name string) {
    pt := tt.GetOrCreate(name)
    pt.ActiveConns.Add(1)
    pt.TotalConns.Add(1)
}

func (tt *TrafficTracker) ConnClosed(name string) {
    pt := tt.GetOrCreate(name)
    pt.ActiveConns.Add(-1)
}

func (tt *TrafficTracker) GetAllSnapshot() []ProxyTrafficSnapshot {
    tt.mu.RLock()
    defer tt.mu.RUnlock()
    result := make([]ProxyTrafficSnapshot, 0, len(tt.proxies))
    for _, pt := range tt.proxies {
        result = append(result, ProxyTrafficSnapshot{
            Name:        pt.Name,
            Type:        pt.Type,
            BytesIn:     pt.BytesIn.Load(),
            BytesOut:    pt.BytesOut.Load(),
            TotalConns:  pt.TotalConns.Load(),
            ActiveConns: pt.ActiveConns.Load(),
        })
    }
    return result
}

type ProxyTrafficSnapshot struct {
    Name        string `json:"name"`
    Type        string `json:"type"`
    BytesIn     int64  `json:"bytes_in"`
    BytesOut    int64  `json:"bytes_out"`
    TotalConns  int64  `json:"total_conns"`
    ActiveConns int64  `json:"active_conns"`
}

// ────────────────────────────────────────────────────────────
// FRPClient: stdout traffic push
// Periodically writes a JSON line to stdout so the Swift client
// can parse traffic updates without polling /api/traffic.
// ────────────────────────────────────────────────────────────

type TrafficPushMessage struct {
    Type      string                 `json:"type"`
    Proxies   []ProxyTrafficSnapshot `json:"proxies"`
    Timestamp int64                  `json:"timestamp"`
}

var pushOnce sync.Once
var pushStop chan struct{}

// StartTrafficPusher starts a background goroutine that pushes traffic
// snapshots to stdout as JSON lines every second. Safe to call multiple times.
func StartTrafficPusher() {
    pushOnce.Do(func() {
        pushStop = make(chan struct{})
        go func() {
            ticker := time.NewTicker(1 * time.Second)
            defer ticker.Stop()
            for {
                select {
                case <-ticker.C:
                    snapshots := GlobalTrafficTracker.GetAllSnapshot()
                    if len(snapshots) == 0 {
                        continue // don't push empty data
                    }
                    msg := TrafficPushMessage{
                        Type:      "traffic",
                        Proxies:   snapshots,
                        Timestamp: time.Now().UnixMilli(),
                    }
                    // Use json.Marshal + fmt.Fprintf to write directly to stdout.
                    // Avoid json.Encoder which may buffer internally.
                    data, err := json.Marshal(msg)
                    if err != nil {
                        fmt.Fprintf(os.Stderr, "[traffic-pusher] marshal error: %v\n", err)
                        continue
                    }
                    // Print as a single line to stdout for the Swift pipe reader.
                    // fmt.Fprintf writes directly to the underlying fd without extra buffering
                    // when stdout is a pipe (default on Unix).
                    fmt.Fprintf(os.Stdout, "%s\n", data)
                case <-pushStop:
                    return
                }
            }
        }()
    })
}

// StopTrafficPusher stops the traffic push goroutine.
func StopTrafficPusher() {
    if pushStop != nil {
        close(pushStop)
    }
}
GOEOF
    log "  ✓ traffic_tracker.go"

    # Patch 2b: conn.go — StatsConn reports to TrafficTracker
    CONN_GO="$SRC_DIR/pkg/util/net/conn.go"
    if [ -f "$CONN_GO" ]; then
        # Only patch if not already done
        if ! grep -q "FRPClient: TrafficTracker integration" "$CONN_GO"; then
            cp "$CONN_GO" "$CONN_GO.bak"

            python3 - "$CONN_GO" << 'PYEOF'
import sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

# 1. Add proxyName and proxyType fields to StatsConn struct
old_struct = '''type StatsConn struct {
\tnet.Conn

\tclosed     atomic.Int64 // 1 means closed
\ttotalRead  int64
\ttotalWrite int64
\tstatsFunc  func(totalRead, totalWrite int64)
}'''

new_struct = '''type StatsConn struct {
\tnet.Conn

\tclosed     atomic.Int64 // 1 means closed
\ttotalRead  int64
\ttotalWrite int64
\tstatsFunc  func(totalRead, totalWrite int64)

\t// FRPClient: TrafficTracker integration
\tproxyName string
\tproxyType string
}'''

# 2. Add WrapStatsConnWithProxy after WrapStatsConn
old_wrap = '''func WrapStatsConn(conn net.Conn, statsFunc func(total, totalWrite int64)) *StatsConn {
\treturn &StatsConn{
\t\tConn:      conn,
\t\tstatsFunc: statsFunc,
\t}
}'''

new_wrap = '''func WrapStatsConn(conn net.Conn, statsFunc func(total, totalWrite int64)) *StatsConn {
\treturn &StatsConn{
\t\tConn:      conn,
\t\tstatsFunc: statsFunc,
\t}
}

// FRPClient: TrafficTracker integration — WrapStatsConnWithProxy
func WrapStatsConnWithProxy(conn net.Conn, proxyName, proxyType string, statsFunc func(total, totalWrite int64)) *StatsConn {
\t// Start the stdout traffic pusher on first proxy connection
\tStartTrafficPusher()

\t// Set the proxy type for display
\tpt := GlobalTrafficTracker.GetOrCreate(proxyName)
\tpt.Type = proxyType

\t// Track connection open
\tGlobalTrafficTracker.ConnOpened(proxyName)

\treturn &StatsConn{
\t\tConn:      conn,
\t\tproxyName: proxyName,
\t\tproxyType: proxyType,
\t\tstatsFunc: statsFunc,
\t}
}'''

# 3. Patch Read method to report traffic
old_read = '''func (statsConn *StatsConn) Read(p []byte) (n int, err error) {
\tn, err = statsConn.Conn.Read(p)
\tstatsConn.totalRead += int64(n)
\treturn
}'''

new_read = '''func (statsConn *StatsConn) Read(p []byte) (n int, err error) {
\tn, err = statsConn.Conn.Read(p)
\tstatsConn.totalRead += int64(n)
\t// FRPClient: Report to global TrafficTracker
\t// Read from localConn = data from local service → sent to frps = bytes_out (upload)
\tif statsConn.proxyName != "" {
\t\tGlobalTrafficTracker.AddTraffic(statsConn.proxyName, 0, int64(n))
\t}
\treturn
}'''

# 4. Patch Write method to report traffic
old_write = '''func (statsConn *StatsConn) Write(p []byte) (n int, err error) {
\tn, err = statsConn.Conn.Write(p)
\tstatsConn.totalWrite += int64(n)
\treturn
}'''

new_write = '''func (statsConn *StatsConn) Write(p []byte) (n int, err error) {
\tn, err = statsConn.Conn.Write(p)
\tstatsConn.totalWrite += int64(n)
\t// FRPClient: Report to global TrafficTracker
\t// Write to localConn = data received from frps → forwarded to local service = bytes_in (download)
\tif statsConn.proxyName != "" {
\t\tGlobalTrafficTracker.AddTraffic(statsConn.proxyName, int64(n), 0)
\t}
\treturn
}'''

# 5. Patch Close method to track connection close
old_close = '''func (statsConn *StatsConn) Close() (err error) {
\told := statsConn.closed.Swap(1)
\tif old != 1 {
\t\terr = statsConn.Conn.Close()
\t\tif statsConn.statsFunc != nil {
\t\t\tstatsConn.statsFunc(statsConn.totalRead, statsConn.totalWrite)
\t\t}
\t}
\treturn
}'''

new_close = '''func (statsConn *StatsConn) Close() (err error) {
\told := statsConn.closed.Swap(1)
\tif old != 1 {
\t\terr = statsConn.Conn.Close()
\t\t// FRPClient: Track connection close
\t\tif statsConn.proxyName != "" {
\t\t\tGlobalTrafficTracker.ConnClosed(statsConn.proxyName)
\t\t}
\t\tif statsConn.statsFunc != nil {
\t\t\tstatsConn.statsFunc(statsConn.totalRead, statsConn.totalWrite)
\t\t}
\t}
\treturn
}'''

if old_struct in content:
    content = content.replace(old_struct, new_struct)
    print("  ✓ StatsConn struct patched")
else:
    print("  WARNING: StatsConn struct pattern not found")

if old_wrap in content:
    content = content.replace(old_wrap, new_wrap)
    print("  ✓ WrapStatsConnWithProxy added")
else:
    print("  WARNING: WrapStatsConn pattern not found")

if old_read in content:
    content = content.replace(old_read, new_read)
    print("  ✓ Read method patched")
else:
    print("  WARNING: Read method pattern not found")

if old_write in content:
    content = content.replace(old_write, new_write)
    print("  ✓ Write method patched")
else:
    print("  WARNING: Write method pattern not found")

if old_close in content:
    content = content.replace(old_close, new_close)
    print("  ✓ Close method patched")
else:
    print("  WARNING: Close method pattern not found")

with open(sys.argv[1], 'w') as f:
    f.write(content)
PYEOF
            log "  ✓ conn.go patched"
        else
            log "  - conn.go already patched"
        fi
    else
        log "  WARNING: conn.go not found, skipping StatsConn patch"
    fi

    # Patch 2c: traffic_api.go — HTTP handler
    API_DIR="$SRC_DIR/client"
    mkdir -p "$API_DIR"
    cat > "$API_DIR/traffic_api.go" << 'GOEOF'
// Code injected by FRPClient — HTTP handler for /api/traffic

package client

import (
    "encoding/json"
    "net/http"

    frpnet "github.com/fatedier/frp/pkg/util/net"
)

func TrafficAPIHandler(w http.ResponseWriter, r *http.Request) {
    snapshots := frpnet.GlobalTrafficTracker.GetAllSnapshot()

    w.Header().Set("Content-Type", "application/json")
    w.Header().Set("Access-Control-Allow-Origin", "*")

    if err := json.NewEncoder(w).Encode(snapshots); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
}
GOEOF
    log "  ✓ traffic_api.go"

    # Patch 2d: api_router.go — register /api/traffic route
    API_ROUTER_GO="$SRC_DIR/client/api_router.go"
    if [ -f "$API_ROUTER_GO" ]; then
        if ! grep -q "TrafficAPIHandler" "$API_ROUTER_GO"; then
            python3 - "$API_ROUTER_GO" << 'PYEOF'
import sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

# Replace the exact pattern: /healthz line + blank line + API routes comment
old_block = '''\t// Healthz endpoint without auth
\thelper.Router.HandleFunc("/healthz", healthz)

\t// API routes and static files with auth'''

new_block = '''\t// Healthz endpoint without auth
\thelper.Router.HandleFunc("/healthz", healthz)

\t// FRPClient injected — traffic monitoring endpoint (no auth, like healthz)
\thelper.Router.HandleFunc("/api/traffic", TrafficAPIHandler)

\t// API routes and static files with auth'''

if old_block in content:
    content = content.replace(old_block, new_block)
    print("  ✓ api_router.go patched")
else:
    # Fallback: try different whitespace (tabs vs spaces)
    import re
    # Match the healthz HandleFunc line and insert after it
    pattern = r'(helper\.Router\.HandleFunc\("/healthz", healthz\)\n)'
    if re.search(pattern, content):
        content = re.sub(
            pattern,
            r'\1\n\t// FRPClient injected — traffic monitoring endpoint\n\thelper.Router.HandleFunc("/api/traffic", TrafficAPIHandler)\n',
            content
        )
        print("  ✓ api_router.go patched (fallback)")
    else:
        print("  WARNING: api_router.go pattern not found, route NOT registered")

with open(sys.argv[1], 'w') as f:
    f.write(content)
PYEOF
            log "  ✓ api_router.go patched"
        else
            log "  - api_router.go already patched"
        fi
    else
        log "  WARNING: api_router.go not found, skipping route registration"
    fi

    # Patch 2e: proxy.go — wrap localConn with StatsConn for traffic monitoring
    PROXY_GO="$SRC_DIR/client/proxy/proxy.go"
    if [ -f "$PROXY_GO" ]; then
        if ! grep -q "FRPClient: Wrap localConn with StatsConn" "$PROXY_GO"; then
            python3 - "$PROXY_GO" << 'PYEOF'
import sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

# Patch HandleTCPWorkConnection to wrap localConn with StatsConn
old_localconn = '''\tlocalConn, err := libnet.Dial(
\t\tnet.JoinHostPort(baseCfg.LocalIP, strconv.Itoa(baseCfg.LocalPort)),
\t\tlibnet.WithTimeout(10*time.Second),
\t)
\tif err != nil {
\t\tworkConn.Close()
\t\txl.Errorf("connect to local service [%s:%d] error: %v", baseCfg.LocalIP, baseCfg.LocalPort, err)
\t\treturn
\t}

\txl.Debugf("join connections, localConn(l[%s] r[%s]) workConn(l[%s] r[%s])", localConn.LocalAddr().String(),
\t\tlocalConn.RemoteAddr().String(), workConn.LocalAddr().String(), workConn.RemoteAddr().String())'''

new_localconn = '''\tlocalConn, err := libnet.Dial(
\t\tnet.JoinHostPort(baseCfg.LocalIP, strconv.Itoa(baseCfg.LocalPort)),
\t\tlibnet.WithTimeout(10*time.Second),
\t)
\tif err != nil {
\t\tworkConn.Close()
\t\txl.Errorf("connect to local service [%s:%d] error: %v", baseCfg.LocalIP, baseCfg.LocalPort, err)
\t\treturn
\t}

\t// FRPClient: Wrap localConn with StatsConn for traffic monitoring
\tlocalConn = netpkg.WrapStatsConnWithProxy(localConn, baseCfg.Name, baseCfg.Type, nil)

\txl.Debugf("join connections, localConn(l[%s] r[%s]) workConn(l[%s] r[%s])", localConn.LocalAddr().String(),
\t\tlocalConn.RemoteAddr().String(), workConn.LocalAddr().String(), workConn.RemoteAddr().String())'''

if old_localconn in content:
    content = content.replace(old_localconn, new_localconn)
    print("  ✓ HandleTCPWorkConnection localConn patched")
else:
    print("  WARNING: HandleTCPWorkConnection localConn pattern not found")

with open(sys.argv[1], 'w') as f:
    f.write(content)
PYEOF
            log "  ✓ proxy.go patched"
        else
            log "  - proxy.go already patched"
        fi
    else
        log "  WARNING: proxy.go not found, skipping traffic wrapping"
    fi

    # Write patch marker
    echo "$PATCH_VERSION" > "$PATCH_MARKER"
    log "Patches applied successfully"
fi

# ─────────────────────────────────────────────────
# Step 3: Build frpc with Go
# ─────────────────────────────────────────────────

log "Step 3/4: Building frpc..."
log "Output target: $OUTPUT"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT")"

# Check Go availability
if ! command -v go &> /dev/null; then
    fail "Go is not installed — please install Go (brew install go)"
    exit 0
fi

GO_VERSION=$(go version)
log "Go version: $GO_VERSION"

cd "$SRC_DIR"

# Check if rebuild is needed
NEED_REBUILD=true
if [ -f "$OUTPUT" ]; then
    # Ensure dist directory exists for embed check
    mkdir -p web/frpc/dist
    # Compare source modification times
    LATEST_SRC=$(find cmd/ pkg/ -name "*.go" -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -rn | head -1 || echo "0")
    BIN_TIME=$(stat -f "%m" "$OUTPUT" 2>/dev/null || echo "0")
    if [ "$LATEST_SRC" -le "$BIN_TIME" ]; then
        log "frpc binary is up to date, skipping build"
        NEED_REBUILD=false
    fi
fi

if $NEED_REBUILD; then
    log "Compiling frpc (CGO_ENABLED=0, static build)..."

    # Create empty dist directory (required by web/frpc/embed.go)
    mkdir -p web/frpc/dist

    export CGO_ENABLED=0
    export GO111MODULE=on

    if go build -trimpath -ldflags "-s -w" -tags "frpc,noweb" -o "$OUTPUT" ./cmd/frpc 2>&1; then
        chmod +x "$OUTPUT"
        log "✓ frpc built successfully: $OUTPUT"
    else
        fail "Go build failed"
        exit 0
    fi
fi

# ─────────────────────────────────────────────────
# Step 4: Output version info for Xcode build log
# ─────────────────────────────────────────────────

log "Step 4/4: Version info..."

if [ -f "$OUTPUT" ]; then
    VERSION=$("$OUTPUT" --version 2>/dev/null || echo "unknown")
    log "frpc version: $VERSION"
else
    log "frpc binary not found at: $OUTPUT"
fi

log "Build phase complete ✓"
