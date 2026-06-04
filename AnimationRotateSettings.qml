import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets
import Quickshell

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
        text: "Configure the daemon connection and refresh interval."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Item { height: Theme.spacingM; width: 1 }

    // ── Socket Path ────────────────────────────────────────────
    StringSetting {
        settingKey: "socketPath"
        label: "Control Socket Path"
        description: "Path to the daemon's Unix control socket. By default, lives inside the plugin directory."
        placeholder: "<pluginDir>/control.sock"
        defaultValue: ""
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

    // ── Keybind Info ─────────────────────────────────────────────
    StyledText {
        width: parent.width
        text: "Keybinds"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "To bind keys for next/prev animation, add custom commands in DMS Keybinds settings:\n\n" +
              "Next: echo 'next' | nc -U " + pluginHome() + "/control.sock\n" +
              "Prev: echo 'prev' | nc -U " + pluginHome() + "/control.sock"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    function pluginHome() {
        var home = Quickshell.env("HOME") || "/home/" + Quickshell.env("USER");
        return home + "/.config/DankMaterialShell/plugins/animationRotate";
    }
}
