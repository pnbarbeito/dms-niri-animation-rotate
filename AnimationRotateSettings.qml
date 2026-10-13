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
        text: "Configure the rotation debounce, event filters and control socket. Changes apply immediately — the daemon re-reads them."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Item { height: Theme.spacingM; width: 1 }

    // ── Debounce cooldown ─────────────────────────────────────
    // Same SettingsData key the daemon reads (cooldown-ms).
    SliderSetting {
        settingKey: "cooldown-ms"
        label: "Rotation Cooldown"
        description: "Minimum time between rotations, on top of the animation's own duration. 0 disables the extra cooldown."
        defaultValue: 0
        minimum: 0
        maximum: 5000
        unit: "ms"
        startIcon: "timer"
    }

    Item { height: Theme.spacingM; width: 1 }

    // ── Event filters (Auto mode) ─────────────────────────────
    ToggleSetting {
        settingKey: "no-window-opened"
        label: "Ignore Window Opened"
        description: "In Auto mode, don't rotate when a window opens."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "no-window-closed"
        label: "Ignore Window Closed"
        description: "In Auto mode, don't rotate when a window closes."
        defaultValue: false
    }

    Item { height: Theme.spacingM; width: 1 }

    // ── Rotation order ────────────────────────────────────────
    ToggleSetting {
        settingKey: "random-order"
        label: "Random Order"
        description: "Pick the next animation at random instead of going through the list in order."
        defaultValue: false
    }

    Item { height: Theme.spacingM; width: 1 }

    // ── Control socket ────────────────────────────────────────
    StringSetting {
        id: socketSetting
        settingKey: "socketPath"
        label: "Control Socket Path"
        description: "Override for the daemon's Unix control socket. Leave empty to use <pluginDir>/control.sock (resolved via the DMS plugin directory). A new path takes effect the next time the daemon restarts (re-enable the plugin or use Restart in the widget detail view)."
        placeholder: "<pluginDir>/control.sock"
        defaultValue: ""
    }

    // ── Keybind Info ──────────────────────────────────────────
    StyledText {
        width: parent.width
        text: "Keybinds"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "To bind keys for next/prev animation, add custom commands in DMS Keybinds settings (optional: requires netcat with Unix-socket support, e.g. netcat-openbsd):\n\n" +
              "Next: echo 'next' | nc -U " + root.socketPath() + "\n" +
              "Prev: echo 'prev' | nc -U " + root.socketPath()
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // Display helper for the keybind examples: override if set, otherwise the
    // real plugin directory resolved by DMS (XDG-aware, never hardcoded).
    function socketPath() {
        if (socketSetting.value)
            return socketSetting.value;
        if (root.pluginService)
            return root.pluginService.getPluginPath(root.pluginId) + "/control.sock";
        return "<pluginDir>/control.sock";
    }
}
