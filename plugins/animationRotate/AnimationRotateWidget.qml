import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import QtQuick.Layouts

PluginComponent {
    id: root

    // ── Settings ────────────────────────────────────────────────
    property string socketPath: pluginData.socketPath || "~/.config/niri/niri-animation-rotate/control.sock"
    property int refreshIntervalMs: pluginData.refreshIntervalMs || 2000

    // ── State ───────────────────────────────────────────────────
    property string currentAnim: "—"
    property var animationList: []
    property string currentMode: pluginData.currentMode || "auto"
    property bool isLoading: false
    property bool ignoreWindowOpened: pluginData.ignoreWindowOpened === "true"
    property bool ignoreWindowClosed: pluginData.ignoreWindowClosed === "true"
    property bool showInBar: pluginData.showInBar !== "false"

    // ── Process component for sending commands ──────────────────
    Component {
        id: cmdProcComponent
        Process {
            id: cmdProcess
            property var _callback: null
            property string _outputBuffer: ""
            stdout: SplitParser {
                onRead: function(data) {
                    cmdProcess._outputBuffer += data + "\n";
                }
            }
            onExited: {
                var result = cmdProcess._outputBuffer.trim();
                var cb = cmdProcess._callback;
                if (cb) cb(result);
                Qt.callLater(function() { cmdProcess.destroy(); });
            }
        }
    }

    // ── Helpers ─────────────────────────────────────────────────
    function expandPath(path) {
        var home = Quickshell.env("HOME") || "/home/" + Quickshell.env("USER");
        return path.replace(/^~/, home);
    }

    function sendCommand(cmd, callback) {
        var escapedCmd = cmd.replace(/'/g, "'\\''");
        var sockPath = expandPath(root.socketPath);
        cmdProcComponent.createObject(root, {
            "command": ["sh", "-c", "echo '" + escapedCmd + "' | nc -U " + sockPath + " 2>/dev/null || echo 'ERR'"],
            "_callback": callback,
            "running": true
        });
    }

    function fetchCurrent(silent) {
        sendCommand("current", function(resp) {
            if (resp !== "" && resp !== "ERR") root.currentAnim = resp;
            if (!silent) root.isLoading = false;
        });
    }

    function fetchList() {
        sendCommand("list", function(resp) {
            if (resp !== "" && resp !== "ERR")
                root.animationList = resp.split('\n').filter(function(l) { return l.trim() !== ""; });
        });
    }

    function fetchStatus() {
        sendCommand("status", function(resp) {
            if (resp !== "" && resp !== "ERR") {
                var lines = resp.split('\n');
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(': ');
                    if (parts.length === 2) {
                        if (parts[0] === "no-window-opened")
                            root.ignoreWindowOpened = parts[1] === "true";
                        else if (parts[0] === "no-window-closed")
                            root.ignoreWindowClosed = parts[1] === "true";
                    }
                }
            }
        });
    }

    function doNext()    { root.isLoading = true; sendCommand("next",   function(r) { root.fetchCurrent(false); }); }
    function doPrev()    { root.isLoading = true; sendCommand("prev",   function(r) { root.fetchCurrent(false); }); }

    function doSelect(name) {
        sendCommand("select " + name, function(resp) {
            if (resp === "ok") root.currentAnim = name;
        });
    }

    function doSetMode(mode) {
        sendCommand("mode " + mode, function(resp) {
            if (resp === "ok") {
                root.currentMode = mode;
                if (root.pluginService)
                    root.pluginService.savePluginData(root.pluginId, "currentMode", mode);
            }
        });
    }

    function toggleWindowOpened() {
        var newVal = !root.ignoreWindowOpened;
        root.ignoreWindowOpened = newVal;
        sendCommand("set no-window-opened " + (newVal ? "true" : "false"));
        if (root.pluginService)
            root.pluginService.savePluginData(root.pluginId, "ignoreWindowOpened", newVal ? "true" : "false");
    }

    function toggleWindowClosed() {
        var newVal = !root.ignoreWindowClosed;
        root.ignoreWindowClosed = newVal;
        sendCommand("set no-window-closed " + (newVal ? "true" : "false"));
        if (root.pluginService)
            root.pluginService.savePluginData(root.pluginId, "ignoreWindowClosed", newVal ? "true" : "false");
    }

    // ── Periodic refresh ──────────────────────────────────────
    Timer {
        id: refreshTimer
        interval: root.refreshIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchCurrent(true)
    }

    Component.onCompleted: {
        root.fetchCurrent();
        root.fetchList();
        root.fetchStatus();
    }

    // ── Control Center Widget Properties ─────────────────────
    ccWidgetIcon: "animation"
    ccWidgetPrimaryText: "Animations"
    ccWidgetSecondaryText: root.currentAnim
    ccWidgetIsActive: false
    ccWidgetIsToggle: false

    // ── Dankbar pill ──────────────────────────────────────────
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "animation"
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.currentAnim
                color: Theme.widgetTextColor
                font.pixelSize: Theme.barFontSize(root.barThickness, -2)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: root.showInBar
            }
            // Show shorter text when bar space is tight but still informative
            StyledText {
                text: "•"
                color: Theme.widgetIconColor
                font.pixelSize: Theme.barFontSize(root.barThickness, 0)
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.showInBar
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon {
                name: "animation"
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.currentAnim
                color: Theme.widgetTextColor
                font.pixelSize: Theme.barFontSize(root.barThickness, -4)
                anchors.horizontalCenter: parent.horizontalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: root.showInBar
            }
        }
    }

    // ── CC Detail Content ─────────────────────────────────────
    ccDetailContent: Component {
        Rectangle {
            implicitHeight: detailColumn.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            DankFlickable {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                contentHeight: detailColumn.height
                clip: true

                Column {
                    id: detailColumn
                    width: parent.width
                    spacing: Theme.spacingM

                    // ── Header ────────────────────────────────
                    StyledText {
                        text: "Animation Rotate"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    // ── Current + Prev / Next ──────────────────
                    StyledRect {
                        width: parent.width
                        height: 48
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingS

                            DankButton {
                                text: "‹"
                                implicitWidth: 36
                                implicitHeight: 36
                                enabled: !root.isLoading
                                onClicked: root.doPrev()
                            }

                            StyledText {
                                text: root.isLoading ? "…" : root.currentAnim
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            DankButton {
                                text: "›"
                                implicitWidth: 36
                                implicitHeight: 36
                                enabled: !root.isLoading
                                onClicked: root.doNext()
                            }
                        }
                    }

                    // ── Animation Selector ─────────────────────
                    StyledRect {
                        width: parent.width
                        height: selectorCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        Column {
                            id: selectorCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Select Animation"
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            DankDropdown {
                                id: animDropdown
                                width: parent.width
                                compactMode: true
                                dropdownWidth: parent.width
                                openUpwards: false
                                maxPopupHeight: 280
                                options: root.animationList
                                currentValue: root.currentAnim
                                emptyText: "No animations found"
                                onValueChanged: function(value) {
                                    if (value !== root.currentAnim)
                                        root.doSelect(value);
                                }
                            }
                        }
                    }

                    // ── Mode Toggle ────────────────────────────
                    StyledRect {
                        width: parent.width
                        height: modeCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        Column {
                            id: modeCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Mode"
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            RowLayout {
                                width: parent.width
                                spacing: Theme.spacingS

                                Rectangle {
                                    id: autoBtn
                                    Layout.fillWidth: true
                                    height: 35
                                    radius: Theme.cornerRadius
                                    color: root.currentMode === "auto" ? Theme.primary : Theme.surfaceContainer
                                    border.color: root.currentMode === "auto" ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    border.width: 1

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "Auto"
                                        font.weight: root.currentMode === "auto" ? Font.Bold : Font.Normal
                                        color: root.currentMode === "auto" ? Theme.surfaceText : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (root.currentMode !== "auto") root.doSetMode("auto"); }
                                    }
                                }

                                Rectangle {
                                    id: manualBtn
                                    Layout.fillWidth: true
                                    height: 40
                                    radius: Theme.cornerRadius
                                    color: root.currentMode === "manual" ? Theme.primary : Theme.surfaceContainer
                                    border.color: root.currentMode === "manual" ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    border.width: 1

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "Manual"
                                        font.weight: root.currentMode === "manual" ? Font.Bold : Font.Normal
                                        color: root.currentMode === "manual" ? Theme.surfaceText : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (root.currentMode !== "manual") root.doSetMode("manual"); }
                                    }
                                }
                            }
                        }
                    }

                    // ── Event Filters (Auto mode only) ─────────
                    StyledRect {
                        width: parent.width
                        height: eventsCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest
                        opacity: root.currentMode === "auto" ? 1.0 : 0.4

                        Column {
                            id: eventsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Event Filters (Auto Mode)"
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            // Ignore Window Opened
                            Rectangle {
                                width: parent.width
                                height: 36
                                color: "transparent"
                                enabled: root.currentMode === "auto"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: root.ignoreWindowOpened ? "check_box" : "check_box_outline_blank"
                                        color: root.ignoreWindowOpened ? Theme.primary : Theme.surfaceVariantText
                                        size: Theme.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    StyledText {
                                        text: "Ignore Window Opened"
                                        color: Theme.surfaceText
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    enabled: root.currentMode === "auto"
                                    onClicked: {
                                        root.toggleWindowOpened();
                                    }
                                }
                            }

                            // Ignore Window Closed
                            Rectangle {
                                width: parent.width
                                height: 36
                                color: "transparent"
                                enabled: root.currentMode === "auto"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: root.ignoreWindowClosed ? "check_box" : "check_box_outline_blank"
                                        color: root.ignoreWindowClosed ? Theme.primary : Theme.surfaceVariantText
                                        size: Theme.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    StyledText {
                                        text: "Ignore Window Closed"
                                        color: Theme.surfaceText
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    enabled: root.currentMode === "auto"
                                    onClicked: {
                                        root.toggleWindowClosed();
                                    }
                                }
                            }
                        }
                    }

                    // ── Show Name in Bar ────────────────────────
                    StyledRect {
                        width: parent.width
                        height: showInBarRow.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        RowLayout {
                            id: showInBarRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            DankIcon {
                                name: root.showInBar ? "check_box" : "check_box_outline_blank"
                                color: root.showInBar ? Theme.primary : Theme.surfaceVariantText
                                size: Theme.iconSize
                                Layout.alignment: Qt.AlignVCenter
                            }

                            StyledText {
                                text: "Show Name in Bar"
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onClicked: {
                                root.showInBar = !root.showInBar;
                                if (root.pluginService)
                                    root.pluginService.savePluginData(root.pluginId, "showInBar",
                                        root.showInBar ? "true" : "false");
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Popout ─────────────────────────────────────────────────
    popoutWidth: 380
    popoutHeight: 600

    popoutContent: Component {
        PopoutComponent {
            id: mainPopout
            headerText: "Animation Rotate"
            showCloseButton: true

            Item {
                width: parent.width
                height: root.popoutHeight - mainPopout.headerHeight - Theme.spacingM * 2

                DankFlickable {
                    id: popoutFlickable
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    clip: true
                    contentHeight: popoutColumn.implicitHeight

                    Column {
                        id: popoutColumn
                        width: parent.width
                        spacing: Theme.spacingM

                    // Current + Prev/Next
                    StyledRect {
                        width: parent.width
                        height: 48
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingS

                            DankButton {
                                text: "‹"
                                implicitWidth: 50
                                implicitHeight: 36
                                enabled: !root.isLoading
                                onClicked: root.doPrev()
                            }

                            StyledText {
                                text: root.isLoading ? "…" : root.currentAnim
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            DankButton {
                                text: "›"
                                implicitWidth: 50
                                implicitHeight: 36
                                enabled: !root.isLoading
                                onClicked: root.doNext()
                            }
                        }
                    }

                    // Selector
                    StyledRect {
                        width: parent.width
                        height: selectorPopoutCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        Column {
                            id: selectorPopoutCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Select Animation"
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            DankDropdown {
                                id: popoutAnimDropdown
                                width: parent.width
                                compactMode: true
                                dropdownWidth: parent.width
                                openUpwards: false
                                maxPopupHeight: 280
                                options: root.animationList
                                currentValue: root.currentAnim
                                emptyText: "No animations found"
                                onValueChanged: function(value) {
                                    if (value !== root.currentAnim)
                                        root.doSelect(value);
                                }
                            }
                        }
                    }

                    // Mode
                    StyledRect {
                        width: parent.width
                        height: modePopoutCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        Column {
                            id: modePopoutCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Mode"
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            RowLayout {
                                width: parent.width
                                spacing: Theme.spacingS

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 40
                                    radius: Theme.cornerRadius
                                    color: root.currentMode === "auto" ? Theme.primary : Theme.surfaceContainer
                                    border.color: root.currentMode === "auto" ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    border.width: 1

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "Auto"
                                        font.weight: root.currentMode === "auto" ? Font.Bold : Font.Normal
                                        color: root.currentMode === "auto" ? Theme.surfaceText : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (root.currentMode !== "auto") root.doSetMode("auto"); }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 40
                                    radius: Theme.cornerRadius
                                    color: root.currentMode === "manual" ? Theme.primary : Theme.surfaceContainer
                                    border.color: root.currentMode === "manual" ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    border.width: 1

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "Manual"
                                        font.weight: root.currentMode === "manual" ? Font.Bold : Font.Normal
                                        color: root.currentMode === "manual" ? Theme.surfaceText : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (root.currentMode !== "manual") root.doSetMode("manual"); }
                                    }
                                }
                            }
                        }
                    }

                    // Event filters
                    StyledRect {
                        width: parent.width
                        height: eventsPopoutCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest
                        opacity: root.currentMode === "auto" ? 1.0 : 0.4

                        Column {
                            id: eventsPopoutCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Event Filters (Auto Mode)"
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            Rectangle {
                                width: parent.width
                                height: 36
                                color: "transparent"
                                enabled: root.currentMode === "auto"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: root.ignoreWindowOpened ? "check_box" : "check_box_outline_blank"
                                        color: root.ignoreWindowOpened ? Theme.primary : Theme.surfaceVariantText
                                        size: Theme.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    StyledText {
                                        text: "Ignore Window Opened"
                                        color: Theme.surfaceText
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    enabled: root.currentMode === "auto"
                                    onClicked: {
                                        root.toggleWindowOpened();
                                    }
                                }
                            }

                            // Ignore Window Closed
                            Rectangle {
                                width: parent.width
                                height: 36
                                color: "transparent"
                                enabled: root.currentMode === "auto"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: root.ignoreWindowClosed ? "check_box" : "check_box_outline_blank"
                                        color: root.ignoreWindowClosed ? Theme.primary : Theme.surfaceVariantText
                                        size: Theme.iconSize
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    StyledText {
                                        text: "Ignore Window Closed"
                                        color: Theme.surfaceText
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    enabled: root.currentMode === "auto"
                                    onClicked: {
                                        root.toggleWindowClosed();
                                    }
                                }
                            }
                        }
                    }

                    // ── Show Name in Bar ────────────────────────
                    StyledRect {
                        width: parent.width
                        height: showInBarPopoutRow.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        RowLayout {
                            id: showInBarPopoutRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            DankIcon {
                                name: root.showInBar ? "check_box" : "check_box_outline_blank"
                                color: root.showInBar ? Theme.primary : Theme.surfaceVariantText
                                size: Theme.iconSize
                                Layout.alignment: Qt.AlignVCenter
                            }

                            StyledText {
                                text: "Show Name in Bar"
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onClicked: {
                                root.showInBar = !root.showInBar;
                                if (root.pluginService)
                                    root.pluginService.savePluginData(root.pluginId, "showInBar",
                                        root.showInBar ? "true" : "false");
                            }
                        }
                    }

                    // Refresh button
                    DankButton {
                        text: "Refresh"
                        width: parent.width
                        height: 36
                        iconName: "refresh"
                        onClicked: {
                            root.fetchCurrent();
                            root.fetchList();
                        }
                    }
                }
            }
        }
    }
}
}
