import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.Common
import qs.Modules.Plugins

// ─────────────────────────────────────────────────────────────────────────────
// AnimationRotateDaemon — QML port of the Rust niri-animation-rotate daemon.
//
// This replaces the vendored prebuilt binary. It runs in-process under DMS's
// plugin daemon surface: created when the plugin is enabled, destroyed when it
// is disabled (no orphaned processes, no PID tracking needed).
//
// Rust parity notes (src/main.rs, src/animation.rs, src/duration.rs):
//   - bloqueo_hasta (debounce block-until) is `blockUntilMs` below. Rust's
//     Option<Instant> None maps to 0, which preserves the `now >= block` logic
//     (any epoch time is >= 0 → rotate, same as None).
//   - EXPECTED_INITIAL_EVENTS = 5: niri replays state on EventStream connect;
//     the first 5 events are skipped so startup doesn't spin rotations.
//   - Manual-mode gate is lastRotationMs + cooldownMs (Rust `last_rotation`);
//     auto-mode gate is blockUntilMs (Rust `bloqueo_hasta`).
//   - update_kdl_value (KDL persistence in Rust) is replaced by
//     SettingsData.setPluginSetting — DMS persists plugin settings as JSON.
//   - The notify-crate fs watcher is replaced by FolderListModel (which watches
//     the folder) plus a modest periodic rescan for same-count content changes.
//   - try_resume_from_target (content comparison) is replaced by persisting
//     the last applied stem in SettingsData — same outcome, less IO.
// ─────────────────────────────────────────────────────────────────────────────
PluginComponent {
    id: root

    // ── Runtime settings (mirrors Rust RuntimeSettings; kebab keys) ────────
    property int cooldownMs: 0
    property bool noWindowOpened: false
    property bool noWindowClosed: false
    property bool randomOrder: false
    property string mode: "auto" // "auto" | "manual" — persisted
    readonly property int durationFallbackMs: 500

    // ── Paths ───────────────────────────────────────────────────────────────
    readonly property string pluginDir: pluginService ? pluginService.getPluginPath(pluginId) : ""
    readonly property string animationDir: pluginDir + "/animations"
    // niri honours XDG_CONFIG_HOME; default matches the old plugin layout.
    readonly property string _xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string animationTarget: _xdgConfig + "/niri/dms/animation.kdl"
    readonly property string niriConfigPath: _xdgConfig + "/niri/config.kdl"
    readonly property string controlSocketPath: {
        const override = SettingsData.getPluginSetting(pluginId, "socketPath", "");
        return override || (pluginDir + "/control.sock");
    }

    // ── Public state (the widget binds to these — Sub-Task 3) ──────────────
    property string currentAnimation: ""
    property var animationList: [] // stems in rotation order
    property int currentIndex: -1

    // ── niri include consent state (Sub-Task 4) ─────────────────────────────
    // The include line is written ONLY after explicit consent (accept button).
    property bool niriIncludePresent: false
    property bool niriIncludeActionNeeded: false
    // Suppresses the card until the first async detection finishes (no flash
    // for users whose include already exists) and blocks double-submits.
    property bool _includeDetectionDone: false
    property bool _includeWritePending: false

    // ── Debounce state ──────────────────────────────────────────────────────
    property double blockUntilMs: 0 // Rust bloqueo_hasta
    property double lastRotationMs: 0 // Rust last_rotation (manual mode)
    property int initialEventsSeen: 0 // Rust initial_events_seen
    readonly property int expectedInitialEvents: 5

    // Internal: [{ path, stem, durationMs }]
    property var _entries: []
    property bool _pendingReload: false
    property bool _settingsLoaded: false
    property int _pendingDurationReads: 0
    property var _pendingScan: null

    // ── One-shot file reader (Rust std::fs::read_to_string equivalent) ─────
    Component {
        id: fileReadComponent

        FileView {
            id: fv

            property var callback: null
            property var errback: null

            blockLoading: true
            preload: true
            printErrors: false

            onLoaded: {
                if (callback)
                    callback(text());
                destroy();
            }
            onLoadFailed: {
                if (errback)
                    errback(error);
                destroy();
            }
        }
    }

    function _readFile(path, callback, errback) {
        fileReadComponent.createObject(root, {
            "path": path,
            "callback": callback,
            "errback": errback
        });
    }

    // Atomic writes (tmp+rename) are handled by FileView.atomicWrites.
    FileView {
        id: targetFile

        path: root.animationTarget
        blockWrites: false
        atomicWrites: true
        printErrors: false

        onSaved: {
            if (root._pendingReload) {
                root._pendingReload = false;
                root._reloadNiri();
            }
        }
        onSaveFailed: error => {
            // Never leave _pendingReload stuck true (would fire a stray reload
            // on the next successful save).
            root._pendingReload = false;
            console.warn("AnimationRotateDaemon: failed to write target:", root.animationTarget, error);
        }
    }

    // Consent-based writer for ~/.config/niri/config.kdl (Sub-Task 4): the
    // include line is appended atomically only via acceptNiriInclude().
    FileView {
        id: niriConfigFile

        path: root.niriConfigPath
        blockWrites: false
        atomicWrites: true
        printErrors: false

        onSaved: {
            root.niriIncludePresent = true;
            root._includeWritePending = false;
            SettingsData.setPluginSetting(root.pluginId, "niri-include-consent", true);
            root._refreshIncludeState();
            console.info("AnimationRotateDaemon: include added to", root.niriConfigPath);
        }
        onSaveFailed: error => {
            root._includeWritePending = false;
            console.warn("AnimationRotateDaemon: failed to write niri config:", error);
        }
    }

    // One-shot: the target lives in ~/.config/niri/dms/, which may not exist
    // on a fresh system (the old binary's launch script did this mkdir).
    Process {
        id: mkdirProc

        command: ["mkdir", "-p", root._xdgConfig + "/niri/dms"]
        running: false
    }

    // ── Animation directory watcher + listing ──────────────────────────────
    FolderListModel {
        id: animFolderModel

        folder: "file://" + root.animationDir
        showDirs: false
        showFiles: true
        showHidden: false
        showDotAndDotDot: false
        nameFilters: ["*.kdl"]
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root._onFolderScanned();
        }
        onCountChanged: root._onFolderScanned()
    }

    // Periodic rescan catches content edits that don't change the file count.
    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root._onFolderScanned()
    }

    // ── niri EventStream connection (auto-reconnecting; Rust UnixStream) ───
    // Self-contained reconnect: quickshell's raw Socket cannot redial after a
    // failed attempt (dead QLocalSocket is only cleared when a *successful*
    // connection closes), so each attempt gets a fresh Socket via a Loader —
    // same workaround DMS's DSocket uses, but without importing qs.DCommon/
    // qs.DankCommon (the module was renamed across DMS versions and plugins
    // must load on installed releases).
    property bool _niriConnected: false
    property int _niriRetryMs: 400

    Loader {
        id: niriSocketLoader

        active: false

        // Dial only once `item` is assigned: a unix connect can complete
        // synchronously, and handlers fired mid-creation would see null.
        onLoaded: item.connected = true

        sourceComponent: Socket {
            path: Quickshell.env("NIRI_SOCKET")
            parser: SplitParser {
                onRead: line => root._handleNiriEvent(line)
            }

            onConnectionStateChanged: {
                root._niriConnected = connected;
                if (connected) {
                    root._niriRetryMs = 400;
                    // Same subscription bytes as the Rust daemon.
                    write('"EventStream"\n');
                    flush();
                } else if (root._niriDialEnabled) {
                    root._scheduleNiriRetry();
                }
            }

            // A failed dial emits only the error signal, never a state change.
            onError: {
                if (root._niriDialEnabled && !root._niriConnected)
                    root._scheduleNiriRetry();
            }
        }
    }

    // Only retry when we know we're inside a niri session.
    property bool _niriDialEnabled: Quickshell.env("NIRI_SOCKET") !== ""

    on_NiriDialEnabledChanged: {
        if (_niriDialEnabled)
            niriSocketLoader.active = true;
        else
            niriSocketLoader.active = false;
    }

    Timer {
        id: niriRetryTimer

        repeat: false
        onTriggered: niriSocketLoader.active = true
    }

    function _scheduleNiriRetry() {
        if (niriRetryTimer.running)
            return;
        niriRetryTimer.interval = _niriRetryMs;
        niriRetryTimer.restart();
        _niriRetryMs = Math.min(_niriRetryMs * 2, 15000);
    }

    // ── Control socket (Rust UnixListener; nrctl/keybind compatible) ───────
    // The handler MUST be a Socket and must not set path/connected — the
    // SocketServer injects the incoming connection itself.
    Component {
        id: controlConnectionComponent

        Socket {
            id: controlConn

            parser: SplitParser {
                onRead: line => {
                    const reply = root.handleControlCommand(line.trim());
                    // Rust writes zero bytes for an empty `list`; a bare "\n"
                    // would look like a one-line empty reply to nc clients.
                    if (reply !== "")
                        controlConn.write(reply + "\n");
                    controlConn.flush();
                    controlConn.connected = false; // Rust drops the stream per command
                }
            }
        }
    }

    SocketServer {
        id: controlServer

        active: root.pluginDir !== ""
        path: root.controlSocketPath
        handler: controlConnectionComponent
    }

    // ── niri reload (Rust spawns `niri msg action reload`, fire-and-forget) ─
    Process {
        id: reloadProc

        // Upstream Rust uses `action reload`; current niri (26.04) renamed it
        // to `load-config-file` (verified: reload is now an unrecognized
        // subcommand). Use the current name.
        command: ["niri", "msg", "action", "load-config-file"]
    }

    function _reloadNiri() {
        reloadProc.running = true;
    }

    // ── Settings load / persist ─────────────────────────────────────────────
    function _loadSettings() {
        cooldownMs = parseInt(SettingsData.getPluginSetting(pluginId, "cooldown-ms", 0)) || 0;
        noWindowOpened = SettingsData.getPluginSetting(pluginId, "no-window-opened", false) === true;
        noWindowClosed = SettingsData.getPluginSetting(pluginId, "no-window-closed", false) === true;
        randomOrder = SettingsData.getPluginSetting(pluginId, "random-order", false) === true;

        const newMode = SettingsData.getPluginSetting(pluginId, "mode", "auto");
        const resolvedMode = (newMode === "manual") ? "manual" : "auto";
        if (!_settingsLoaded) {
            mode = resolvedMode;
        } else if (resolvedMode !== mode) {
            mode = resolvedMode;
            _onModeSwitched();
        }
        _settingsLoaded = true;
        // Consent changes live in the same map — recompute the card state.
        _refreshIncludeState();
    }

    // React to settings-page edits (SettingsData is a global map; re-read ours).
    Connections {
        target: SettingsData

        function onPluginSettingsChanged() {
            root._loadSettings();
        }
    }

    // Rust `mode auto` side effects: re-init debounce from the applied target,
    // reset manual cooldown, reset the initial-event skip counter.
    function _onModeSwitched() {
        lastRotationMs = 0;
        initialEventsSeen = 0;
        if (mode === "auto") {
            _readFile(animationTarget, text => {
                const dur = parseAnimationDurationText(text);
                blockUntilMs = dur !== null ? (Date.now() + dur + cooldownMs) : 0;
            }, () => {
                blockUntilMs = 0;
            });
        } else {
            blockUntilMs = 0;
        }
    }

    // ── Duration parser (direct port of src/duration.rs) ───────────────────
    // Returns max(duration-ms) * slowdown rounded, or null when no duration-ms.
    function parseAnimationDurationText(text) {
        let durations = [];
        let slowdown = 1.0;
        let inBlockComment = false;

        const rawLines = text.split("\n");
        for (let i = 0; i < rawLines.length; i++) {
            // Strip block comments, tracking state across lines.
            let line = "";
            let rest = rawLines[i];
            while (rest.length > 0) {
                if (inBlockComment) {
                    const end = rest.indexOf("*/");
                    if (end === -1)
                        break;
                    rest = rest.slice(end + 2);
                    inBlockComment = false;
                } else {
                    const start = rest.indexOf("/*");
                    if (start === -1) {
                        line += rest;
                        break;
                    }
                    line += rest.slice(0, start);
                    rest = rest.slice(start + 2);
                    inBlockComment = true;
                }
            }

            // Strip inline // comments.
            const inline = line.indexOf("//");
            if (inline !== -1)
                line = line.slice(0, inline);

            // .trim() covers the Rust trim_start() emptiness/comment checks
            // (QML JS lacks trimStart in some engines).
            const trimmed = line.trim();
            if (trimmed.length === 0 || trimmed.startsWith("//"))
                continue;

            // duration-ms <int>
            const durPos = line.indexOf("duration-ms");
            if (durPos !== -1) {
                const after = line.slice(durPos + "duration-ms".length);
                const token = after.split(/\s+/).filter(t => t.length > 0)[0];
                if (token !== undefined) {
                    const val = parseInt(token, 10);
                    if (!isNaN(val) && val >= 0)
                        durations.push(val);
                }
            }

            // slowdown <float> (note the trailing space, as in Rust).
            const slowPos = line.indexOf("slowdown ");
            if (slowPos !== -1) {
                const after = line.slice(slowPos + "slowdown ".length);
                const token = after.split(/\s+/).filter(t => t.length > 0)[0];
                if (token !== undefined) {
                    const val = parseFloat(token);
                    if (!isNaN(val))
                        slowdown = val;
                }
            }
        }

        if (durations.length === 0)
            return null;
        const maxMs = Math.max.apply(null, durations);
        return Math.round(maxMs * slowdown);
    }

    function _currentDurationMs() {
        if (_entries.length === 0 || currentIndex < 0 || currentIndex >= _entries.length)
            return durationFallbackMs;
        return _entries[currentIndex].durationMs;
    }

    // ── Scan / rotator state (Rust AnimationRotator) ───────────────────────
    function _onFolderScanned() {
        const paths = [];
        const stems = [];
        for (let i = 0; i < animFolderModel.count; i++) {
            paths.push(animFolderModel.get(i, "filePath"));
            stems.push(animFolderModel.get(i, "fileBaseName"));
        }
        if (paths.length === 0) {
            _entries = [];
            animationList = [];
            currentAnimation = "";
            currentIndex = -1;
            return;
        }

        // Parse durations asynchronously; finalize when all reads are done.
        _pendingScan = {
            "paths": paths,
            "stems": stems,
            "durations": new Array(paths.length).fill(durationFallbackMs)
        };
        _pendingDurationReads = paths.length;
        for (let j = 0; j < paths.length; j++) {
            (function (idx, p) {
                _readFile(p, text => {
                    const dur = parseAnimationDurationText(text);
                    _finishDurationRead(idx, dur !== null ? dur : durationFallbackMs);
                }, () => _finishDurationRead(idx, durationFallbackMs));
            })(j, paths[j]);
        }
    }

    function _finishDurationRead(idx, durationMs) {
        if (!_pendingScan)
            return;
        _pendingScan.durations[idx] = durationMs;
        _pendingDurationReads--;
        if (_pendingDurationReads > 0)
            return;

        const scan = _pendingScan;
        _pendingScan = null;
        _finalizeEntries(scan.paths, scan.stems, scan.durations);
    }

    function _finalizeEntries(paths, stems, durations) {
        const oldStem = currentAnimation;
        let entries = [];
        for (let i = 0; i < paths.length; i++) {
            entries.push({
                "path": paths[i],
                "stem": stems[i],
                "durationMs": durations[i]
            });
        }
        if (randomOrder)
            entries = _shuffle(entries);

        // Preserve the previously active animation across rescans.
        let idx = entries.findIndex(e => e.stem === oldStem);
        if (idx === -1) {
            // Startup resume: prefer the stem we last applied (persisted).
            const last = SettingsData.getPluginSetting(pluginId, "last-animation", "");
            idx = last ? entries.findIndex(e => e.stem === last) : -1;
        }
        if (idx === -1)
            idx = 0;

        _entries = entries;
        currentIndex = idx;
        animationList = entries.map(e => e.stem);
        currentAnimation = entries[idx].stem;
    }

    function _shuffle(arr) {
        const a = arr.slice();
        for (let i = a.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const tmp = a[i];
            a[i] = a[j];
            a[j] = tmp;
        }
        return a;
    }

    // Write the current preset to the target and reload niri (Rust apply_current).
    function _applyCurrent(reload) {
        if (currentIndex < 0 || currentIndex >= _entries.length)
            return;
        const entry = _entries[currentIndex];
        _readFile(entry.path, text => {
            // Sync the reported stem only on successful read: _advance and
            // _selectByName move currentIndex, and status/current must show
            // the new animation immediately (not after the next rescan).
            currentAnimation = entry.stem;
            _pendingReload = reload;
            SettingsData.setPluginSetting(pluginId, "last-animation", entry.stem);
            targetFile.setText(text); // triggers save → onSaved → reload
        }, () => {
            // File vanished since the last scan — rebuild the list.
            console.warn("AnimationRotateDaemon: preset vanished, rescanning:", entry.path);
            _onFolderScanned();
        });
    }

    // Rust rotate()/rotate_prev(): advance with wrap, apply + reload.
    function _advance(dir) {
        if (_entries.length === 0)
            return;
        const len = _entries.length;
        currentIndex = ((currentIndex + dir) % len + len) % len;
        _applyCurrent(true);
    }

    // ── niri events + debounce (Rust run_unified_event_loop) ───────────────
    function _handleNiriEvent(line) {
        if (mode !== "auto")
            return;

        let evType = null;
        try {
            const ev = JSON.parse(line);
            const keys = Object.keys(ev);
            if (keys.length > 0)
                evType = keys[0];
        } catch (e) {
            return;
        }
        if (evType === null)
            return;

        // Skip niri's initial state replay.
        if (initialEventsSeen < expectedInitialEvents) {
            initialEventsSeen++;
            return;
        }

        let shouldRotate = false;
        if (evType === "WindowOpenedOrChanged")
            shouldRotate = !noWindowOpened;
        else if (evType === "WindowClosed")
            shouldRotate = !noWindowClosed;
        if (!shouldRotate)
            return;

        _debouncedRotate();
    }

    // Rust compute_block(): rotate if unblocked or expired; either way the
    // block extends from *now* by current duration + cooldown.
    function _debouncedRotate() {
        const ahora = Date.now();
        const debeRotar = ahora >= blockUntilMs;
        if (debeRotar)
            _advance(1);
        blockUntilMs = ahora + _currentDurationMs() + cooldownMs;
    }

    // ── Control socket commands (byte-compatible with the Rust daemon) ─────
    // Returns the reply WITHOUT the trailing newline; the connection handler
    // appends it (Rust replies all end in exactly one \n).
    function handleControlCommand(command) {
        // Mode switches — available in any mode.
        if (command === "mode auto") {
            mode = "auto";
            SettingsData.setPluginSetting(pluginId, "mode", "auto");
            _onModeSwitched();
            return "ok";
        }
        if (command === "mode manual") {
            mode = "manual";
            SettingsData.setPluginSetting(pluginId, "mode", "manual");
            lastRotationMs = 0;
            blockUntilMs = 0;
            return "ok";
        }

        // status / status --json — available in any mode.
        if (command === "status" || command.startsWith("status ")) {
            const useJson = command.split(/\s+/).indexOf("--json") !== -1;
            if (useJson) {
                return JSON.stringify({
                    "mode": mode,
                    "current": currentAnimation !== "" ? currentAnimation : null,
                    "animation_count": _entries.length,
                    "animations": animationList,
                    "random_order": randomOrder,
                    "cooldown_ms": cooldownMs,
                    "no_window_opened": noWindowOpened,
                    "no_window_closed": noWindowClosed
                });
            }
            const lines = [
                "mode: " + mode,
                "current: " + (currentAnimation !== "" ? currentAnimation : "(none)"),
                "animation-count: " + _entries.length,
                "random-order: " + randomOrder,
                "cooldown-ms: " + cooldownMs,
                "no-window-opened: " + noWindowOpened,
                "no-window-closed: " + noWindowClosed
            ];
            return lines.join("\n");
        }

        // set <key> <value> — persists via SettingsData (Rust: update_kdl_value).
        if (command === "set")
            return "error: missing key and value";
        if (command.startsWith("set ")) {
            const rest = command.slice(4).trim();
            const sp = rest.indexOf(" ");
            if (sp === -1)
                return "error: missing value";
            const key = rest.slice(0, sp);
            const val = rest.slice(sp + 1).trim();
            if (key === "cooldown-ms") {
                const parsed = parseInt(val, 10);
                if (isNaN(parsed) || parsed < 0 || String(parsed) !== val)
                    return "error: invalid value for cooldown-ms: " + val;
                cooldownMs = parsed;
                SettingsData.setPluginSetting(pluginId, "cooldown-ms", parsed);
                return "ok";
            }
            if (key === "no-window-opened" || key === "no-window-closed" || key === "random-order") {
                let parsedBool = null;
                if (val === "true" || val === "1" || val === "yes")
                    parsedBool = true;
                else if (val === "false" || val === "0" || val === "no")
                    parsedBool = false;
                if (parsedBool === null)
                    return "error: invalid boolean for " + key + ": " + val;
                if (key === "no-window-opened")
                    noWindowOpened = parsedBool;
                else if (key === "no-window-closed")
                    noWindowClosed = parsedBool;
                else {
                    const wasDisabled = !randomOrder && parsedBool;
                    randomOrder = parsedBool;
                    if (wasDisabled) {
                        // Rust shuffle(): new order, index reset to 0. The
                        // target file on disk is untouched until next rotate.
                        _entries = _shuffle(_entries);
                        currentIndex = 0;
                        animationList = _entries.map(e => e.stem);
                        currentAnimation = _entries.length > 0 ? _entries[0].stem : "";
                    }
                }
                SettingsData.setPluginSetting(pluginId, key, parsedBool);
                return "ok";
            }
            return "error: unknown key: " + key;
        }

        if (mode === "auto") {
            if (command === "current") {
                if (currentAnimation !== "")
                    return currentAnimation;
                return "error: no animations available";
            }
            if (command === "list" || command.startsWith("list ")) {
                if (command.split(/\s+/).indexOf("--json") !== -1)
                    return JSON.stringify(animationList);
                return animationList.join("\n");
            }
            if (command === "next" || command === "rotate" || command === "prev") {
                const ahora = Date.now();
                if (ahora >= blockUntilMs) {
                    _advance(command === "prev" ? -1 : 1);
                    blockUntilMs = ahora + _currentDurationMs() + cooldownMs;
                    return "ok";
                }
                return "error: rotation blocked by debounce";
            }
            if (command === "select")
                return "error: missing name";
            if (command.startsWith("select ")) {
                const name = command.slice(7).trim();
                if (name === "")
                    return "error: missing name";
                const ahora = Date.now();
                if (_selectByName(name)) {
                    blockUntilMs = ahora + _currentDurationMs() + cooldownMs;
                    return "ok";
                }
                return "error: not found";
            }
            return "error: unknown command";
        }

        // Manual mode: cooldown gate on rotation commands.
        const isRotationCmd = command === "next" || command === "rotate" || command === "prev";
        if (isRotationCmd && lastRotationMs > 0) {
            const elapsed = Date.now() - lastRotationMs;
            if (elapsed < cooldownMs)
                return "error: rotation blocked by cooldown";
        }

        if (command === "next" || command === "rotate") {
            _advance(1);
            lastRotationMs = Date.now();
            return "ok";
        }
        if (command === "prev") {
            _advance(-1);
            lastRotationMs = Date.now();
            return "ok";
        }
        if (command === "current") {
            if (currentAnimation !== "")
                return currentAnimation;
            return "error: no animations available";
        }
        if (command === "list" || command.startsWith("list ")) {
            if (command.split(/\s+/).indexOf("--json") !== -1)
                return JSON.stringify(animationList);
            return animationList.join("\n");
        }
        if (command === "select")
            return "error: missing name";
        if (command.startsWith("select ")) {
            const name = command.slice(7).trim();
            if (name === "")
                return "error: missing name";
            if (_selectByName(name)) {
                lastRotationMs = Date.now();
                return "ok";
            }
            return "error: not found";
        }
        return "error: unknown command: " + command;
    }

    // Rust select_by_name(): case-insensitive stem match + apply.
    function _selectByName(name) {
        const lower = name.toLowerCase();
        const pos = _entries.findIndex(e => e.stem.toLowerCase() === lower);
        if (pos === -1)
            return false;
        currentIndex = pos;
        _applyCurrent(true);
        return true;
    }

    // ── Public API for the widget (Sub-Task 3 binds to these) ──────────────
    function rotateNext() {
        handleControlCommand("next");
    }

    function rotatePrev() {
        handleControlCommand("prev");
    }

    function selectAnimation(name) {
        return handleControlCommand("select " + name);
    }

    function setMode(newMode) {
        return handleControlCommand("mode " + newMode);
    }

    // Passthrough so widget buttons can reuse the exact socket semantics.
    function command(cmd) {
        return handleControlCommand(cmd);
    }

    // "Restart" from the widget: re-read settings and rescan presets.
    // DMS owns the daemon surface lifecycle (created on plugin enable,
    // destroyed on disable) — there is no process to restart.
    function restart() {
        console.info("AnimationRotateDaemon: restart requested (rescan + settings reload)");
        _loadSettings();
        _onFolderScanned();
        // Re-detect the include so the consent card reappears correctly if
        // the user edited config.kdl before ever answering (no consent yet).
        _readFile(niriConfigPath, text => {
            niriIncludePresent = _includeInText(text);
            _includeDetected();
        }, () => _includeDetected());
    }

    // ── niri include consent flow (Sub-Task 4) ──────────────────────────────
    // True when config.kdl carries an ACTIVE (uncommented) include line.
    // Tolerates indentation, extra spaces, an optional "./" prefix and
    // single/double quotes; "//"-commented lines don't count.
    function _includeInText(text) {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const t = lines[i].trim();
            if (t.startsWith("//"))
                continue;
            if (/^include\s+['"](\.\/)?dms\/animation\.kdl['"]/.test(t))
                return true;
        }
        return false;
    }

    // The card shows only when the include is missing AND the user has not
    // answered yet (true = added by us, "manual" = chose instructions).
    function _refreshIncludeState() {
        const consent = SettingsData.getPluginSetting(pluginId, "niri-include-consent", false);
        niriIncludeActionNeeded = _includeDetectionDone && !niriIncludePresent && consent !== true && consent !== "manual";
    }

    // Run after every startup/restart detection read (success or failure).
    function _includeDetected() {
        _includeDetectionDone = true;
        _refreshIncludeState();
    }

    // Consent granted: append the include (idempotent) and persist consent
    // only after the write succeeds — a failed write keeps the card visible.
    function acceptNiriInclude() {
        if (_includeWritePending)
            return;
        if (niriIncludePresent) {
            _refreshIncludeState();
            return;
        }
        _includeWritePending = true;
        _readFile(niriConfigPath, text => {
            if (_includeInText(text)) {
                // Added manually while the card was open — just record it.
                niriIncludePresent = true;
                _includeWritePending = false;
                SettingsData.setPluginSetting(pluginId, "niri-include-consent", true);
                _refreshIncludeState();
                return;
            }
            const line = 'include "dms/animation.kdl"';
            const base = text.length === 0 ? "" : (text.endsWith("\n") ? text : text + "\n");
            niriConfigFile.setText(base + line + "\n");
        }, error => {
            const notFound = (typeof FileViewError !== "undefined") && error === FileViewError.FileNotFound;
            if (notFound) {
                // No config.kdl at all: create it with just the include.
                niriConfigFile.setText('include "dms/animation.kdl"\n');
            } else {
                // Unreadable existing config — never overwrite it blindly.
                _includeWritePending = false;
                console.warn("AnimationRotateDaemon: cannot read niri config to add include:", error);
            }
        });
    }

    // "Show instructions" path: the user will add the line by hand; stop
    // asking (one prompt only) and let the widget reveal the manual steps.
    function dismissNiriInclude() {
        SettingsData.setPluginSetting(pluginId, "niri-include-consent", "manual");
        _refreshIncludeState();
    }

    // ── Lifecycle ──────────────────────────────────────────────────────────
    Component.onCompleted: {
        console.info("AnimationRotateDaemon: instantiated (pluginId:", pluginId + ")");
        _loadSettings();
        // Ensure the target's parent dir exists before any rotation can write.
        mkdirProc.running = true;
        // Consent-card detection: is the include active in niri's config?
        _readFile(niriConfigPath, text => {
            niriIncludePresent = _includeInText(text);
            _includeDetected();
        }, () => _includeDetected());
        // Initial niri dial (the property-change handler only fires later).
        if (_niriDialEnabled)
            niriSocketLoader.active = true;
        // Rust startup: block rotations while the applied animation plays.
        _readFile(animationTarget, text => {
            const dur = parseAnimationDurationText(text);
            if (dur !== null)
                blockUntilMs = Date.now() + dur + cooldownMs;
        }, () => {});
    }

    Component.onDestruction: {
        niriRetryTimer.stop();
        niriSocketLoader.active = false;
        // Deactivating removes the socket file and closes all connections
        // (SocketServer contract), mirroring the Rust daemon's SIGTERM cleanup.
        controlServer.active = false;
        console.info("AnimationRotateDaemon: destroyed (pluginId:", pluginId + ")");
    }
}
