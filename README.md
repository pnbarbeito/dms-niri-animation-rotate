# dms-niri-animation-rotate

Niri window animation rotation control for [Dank Material Shell](https://danklinux.com). Switch animations, toggle auto/manual modes, and filter events — all from the Control Center. **Daemon included — no manual setup required.**

## How It Works

```
┌────────────────────┐     Unix socket     ┌───────────────────────────┐
│  DMS Plugin (QML)  │ ◄──────────────────► │  niri-animation-rotate    │
│                    │    nc -U control.sock│  (bundled daemon, musl)   │
└────────────────────┘                      └───────────────────────────┘
```

1. **Install** from the DMS Plugin Marketplace (1 click).
2. **Activate** the plugin — it auto-starts the bundled daemon.
3. **Control** your Niri animations from the Control Center, DankBar, or popout widget.

Everything is self-contained: the Rust daemon (`niri-animation-rotate`) is statically compiled with musl and included in `bin/`. No Rust toolchain, no building, no manual daemon installation.

## Features

- **Prev/Next buttons** to cycle through Niri window animations
- **Animation picker** — dropdown with all detected animations
- **Auto/Manual mode** — rotate automatically on window events, or manually
- **Event filters** — ignore window-opened or window-closed events
- **DankBar pill** — shows the current animation name right in the status bar
- **Popout window** (380×600) — all controls in a dedicated floating panel
- **Configurable socket path and refresh interval**

## Requirements

- [Niri](https://github.com/YaLTeR/niri) compositor (v0.1.5+)
- Dank Material Shell >= 1.4.0

The daemon (`niri-animation-rotate`) is bundled — nothing else to install.

## Installation

### DMS Plugin Marketplace (recommended)

1. Open DMS → Settings → Plugins → Browse
2. Search for "Animation Rotate"
3. Click Install
4. Activate the plugin — it's ready

The plugin auto-starts the daemon and sets up all required config files on first activation.

### Manual

```bash
git clone https://github.com/pnbarbeito/dms-niri-animation-rotate.git \
  ~/.config/DankMaterialShell/plugins/animationRotate/
```

Then activate the plugin from DMS Settings → Plugins → Local.

## Configuration

Configure socket path and refresh interval from the plugin settings page (right-click the widget → Settings). All other daemon settings are managed through the widget's UI.

### Keybind Setup

To bind keys for next/prev animation, add custom commands in DMS Settings → Keybinds:

| Action | Command |
|---|---|
| Next animation | `echo 'next' \| nc -U <pluginDir>/control.sock` |
| Prev animation | `echo 'prev' \| nc -U <pluginDir>/control.sock` |

The exact socket path is shown in the plugin settings page.

## Screenshots

<!-- TODO: add screenshots -->
<!-- ![Control Center](./screenshots/control-center.png) -->
<!-- ![Popout Widget](./screenshots/popout.png) -->

## License

MIT — see [LICENSE](./LICENSE).

## Acknowledgments

The 49 animation presets bundled with this plugin are **not my own work**. They were created by talented authors and collected from the community.

### Authors and sources

- **[chaoscatsofficial@gmail.com](mailto:chaoscatsofficial@gmail.com)** — 16 animations (bloom, burn-ashes, burn, burn-multicolor, explode, fold-window, glitch_00, glitch-cyberpunk, glitch, halftone, pixelate, pop-drop, ribbons, roll-drop, swipe-window, unravel)  
  Source: [XansiVA/nirimation](https://github.com/XansiVA/nirimation)

- **[Justin Garza](mailto:JGarza9788@gmail.com)** — 7 animations (blur, chromatic_edge, energize_b_niri, glide, incinerate, prism_fold, tv_crt)  
  Source: [jgarza9788/niri-animation-collection](https://github.com/jgarza9788/niri-animation-collection)

- **[Joe Hsu](mailto:jhsu.x1@gmail.com)** — 2 animations (dither-glitch, pixel-sort)  
  Source: [jgarza9788/niri-animation-collection](https://github.com/jgarza9788/niri-animation-collection)

- **liixini** ([github.com/liixini](https://github.com/liixini)) — 24 animations (circle, crosshatch, crosswarp, directiona-wipe, directional, disolve, fade, flyeye, glass-warp, glitch_01, heat-melt, ink-splash, inkwell-drop, morph, perlin, pixelfade-wave, plasma-flow, polar-function, polka-dots-curtain, randomsquares, smoke, snap, voronoi-shatter, wave-warp)  
  Sources: [liixini/shaders](https://github.com/liixini/shaders)

Thank you all for sharing your incredible work with the Niri community!

## Related

- [niri-animation-rotate](https://github.com/pnbarbeito/niri-animation-rotate) — the Rust daemon source code and standalone releases.
