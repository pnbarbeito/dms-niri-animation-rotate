import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "animationRotate"

    // ── Header ────────────────────────────────────────────────
    StyledText {
        width: parent.width
        text: "Animation Rotate Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure how the plugin connects to niri-animation-rotate."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Item { height: Theme.spacingM; width: 1 }

    // ── Socket Path ────────────────────────────────────────────
    StringSetting {
        settingKey: "socketPath"
        label: "Control Socket Path"
        description: "Path to niri-animation-rotate Unix control socket."
        placeholder: "~/.config/niri/niri-animation-rotate/control.sock"
        defaultValue: "~/.config/niri/niri-animation-rotate/control.sock"
    }

    // ── Refresh interval ────────────────────────────────────────
    SliderSetting {
        settingKey: "refreshIntervalMs"
        label: "Refresh Interval (ms)"
        description: "How often to poll the daemon for the current animation."
        defaultValue: 2000
        minimum: 500
        maximum: 10000
        unit: "ms"
    }

    // ── Bar display ─────────────────────────────────────────────
    ToggleSetting {
        settingKey: "showInBar"
        label: "Show Name in Bar"
        description: "Show the current animation name in the DankBar pill. Disable to show only the icon."
        defaultValue: true
    }
}
