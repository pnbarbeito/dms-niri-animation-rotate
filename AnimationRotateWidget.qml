import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import QtQuick.Layouts

PluginComponent {
    id: root

    // ── State (reactive bindings to the daemon surface; no polling) ────────
    // DMS creates the daemon surface when the plugin is enabled and destroys
    // it on disable — daemonSurface is null only for a tick during startup.
    // `|| null` normalizes a missing map key (undefined) so daemonRunning
    // never reports false-green while the surface doesn't exist yet.
    readonly property var daemonSurface: ((pluginService && pluginService.pluginDaemonInstances) ? pluginService.pluginDaemonInstances[pluginId] : null) || null
    readonly property bool daemonRunning: daemonSurface !== null
    readonly property string currentAnim: daemonSurface ? (daemonSurface.currentAnimation || "—") : "—"
    readonly property var animationList: daemonSurface ? daemonSurface.animationList : []
    readonly property string currentMode: daemonSurface ? daemonSurface.mode : "auto"
    readonly property bool ignoreWindowOpened: daemonSurface ? daemonSurface.noWindowOpened : false
    readonly property bool ignoreWindowClosed: daemonSurface ? daemonSurface.noWindowClosed : false
    property bool showInBar: pluginData.showInBar !== "false"
    // Local UI state for the niri-include card's "Show instructions" path.
    property bool showIncludeInstructions: false
    onDaemonSurfaceChanged: console.info("AnimationRotateWidget: daemon surface", daemonSurface ? "attached" : "detached")

    function doNext() {
        if (daemonSurface)
            daemonSurface.rotateNext();
    }

    function doPrev() {
        if (daemonSurface)
            daemonSurface.rotatePrev();
    }

    function doSelect(name) {
        if (daemonSurface)
            daemonSurface.selectAnimation(name);
    }

    function doSetMode(mode) {
        if (daemonSurface)
            daemonSurface.setMode(mode);
    }

    function toggleWindowOpened() {
        if (daemonSurface)
            daemonSurface.command("set no-window-opened " + (!ignoreWindowOpened ? "true" : "false"));
    }

    function toggleWindowClosed() {
        if (daemonSurface)
            daemonSurface.command("set no-window-closed " + (!ignoreWindowClosed ? "true" : "false"));
    }

    function restartDaemon() {
        // Rescans presets and re-reads settings; the daemon surface itself is
        // owned by DMS (no process to restart).
        if (daemonSurface)
            daemonSurface.restart();
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
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        StyledText {
                            text: "Animation Rotate"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.daemonRunning ? Theme.success : Theme.error
                        }
                        StyledText {
                            text: root.daemonRunning ? "active" : "offline"
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.daemonRunning ? Theme.success : Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // ── Niri include consent card ────────────
                    // Shown only while the include is missing AND unanswered.
                    // After "Show instructions" the card stays for this session
                    // (consent persisted → never asked again on next start).
                    StyledRect {
                        // Hide once the include exists (even if instructions
                        // are open for the session).
                        visible: root.daemonSurface && (root.daemonSurface.niriIncludeActionNeeded || (root.showIncludeInstructions && !root.daemonSurface.niriIncludePresent))
                        width: parent.width
                        height: includeCardCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        Column {
                            id: includeCardCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Niri config include"
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                            StyledText {
                                width: parent.width
                                text: "Animations are applied through \"dms/animation.kdl\" in your niri config. It isn't included yet."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                wrapMode: Text.Wrap
                                visible: !root.showIncludeInstructions
                            }
                            StyledText {
                                width: parent.width
                                text: root.daemonSurface ? "Add this line to " + root.daemonSurface.niriConfigPath + " and save — niri reloads it automatically:\n\ninclude \"dms/animation.kdl\"" : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                wrapMode: Text.Wrap
                                visible: root.showIncludeInstructions
                            }

                            Row {
                                spacing: Theme.spacingS

                                DankButton {
                                    text: "Add include"
                                    height: 32
                                    enabled: root.daemonSurface && !root.daemonSurface._includeWritePending
                                    onClicked: {
                                        if (root.daemonSurface)
                                            root.daemonSurface.acceptNiriInclude();
                                    }
                                }
                                DankButton {
                                    text: "Show instructions"
                                    height: 32
                                    visible: !root.showIncludeInstructions
                                    onClicked: {
                                        root.showIncludeInstructions = true;
                                        if (root.daemonSurface)
                                            root.daemonSurface.dismissNiriInclude();
                                    }
                                }
                            }
                        }
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
                                enabled: root.daemonRunning
                                onClicked: root.doPrev()
                            }

                            StyledText {
                                text: root.currentAnim
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
                                enabled: root.daemonRunning
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
                                onValueChanged: function (value) {
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
                                        onClicked: {
                                            if (root.currentMode !== "auto")
                                                root.doSetMode("auto");
                                        }
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
                                        onClicked: {
                                            if (root.currentMode !== "manual")
                                                root.doSetMode("manual");
                                        }
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
                                    root.pluginService.savePluginData(root.pluginId, "showInBar", root.showInBar ? "true" : "false");
                            }
                        }
                    }

                    // ── Restart (rescan presets / reload settings) ──
                    DankButton {
                        text: "Restart Daemon"
                        width: parent.width
                        height: 36
                        iconName: "restart_alt"
                        enabled: root.daemonRunning
                        onClicked: root.restartDaemon()
                    }
                }
            }
        }
    }

    // ── Popout ─────────────────────────────────────────────────
        popoutWidth: 380
        popoutHeight: 640

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
                                        enabled: root.daemonRunning
                                        onClicked: root.doPrev()
                                    }

                                    StyledText {
                                        text: root.currentAnim
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
                                        enabled: root.daemonRunning
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
                                        onValueChanged: function (value) {
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
                                                onClicked: {
                                                    if (root.currentMode !== "auto")
                                                        root.doSetMode("auto");
                                                }
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
                                                onClicked: {
                                                    if (root.currentMode !== "manual")
                                                        root.doSetMode("manual");
                                                }
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
                                            root.pluginService.savePluginData(root.pluginId, "showInBar", root.showInBar ? "true" : "false");
                                    }
                                }
                            }

                            // Restart (rescan presets / reload settings) —
                            // no Refresh button: all state is reactive now.
                            DankButton {
                                text: "Restart Daemon"
                                width: parent.width
                                height: 36
                                iconName: "restart_alt"
                                enabled: root.daemonRunning
                                onClicked: root.restartDaemon()
                            }
                        }
                    }
                }
            }
        }
    
}

