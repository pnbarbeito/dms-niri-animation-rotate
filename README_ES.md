# dms-niri-animation-rotate

Control de rotación de animaciones de ventanas de Niri para [Dank Material Shell](https://danklinux.com). Cambiá animaciones, alterná entre modo automático/manual y filtrá eventos — todo desde el Centro de Control. **Daemon incluido — sin configuración manual.**

## Cómo funciona

```
┌────────────────────┐     Unix socket     ┌───────────────────────────┐
│  Plugin DMS (QML)  │ ◄──────────────────► │  niri-animation-rotate    │
│                    │    nc -U control.sock│  (daemon bundled, musl)   │
└────────────────────┘                      └───────────────────────────┘
```

1. **Instalá** desde el Marketplace de Plugins de DMS (1 clic).
2. **Activá** el plugin — inicia automáticamente el daemon incluido.
3. **Controlá** tus animaciones de Niri desde el Centro de Control, la DankBar o el panel flotante.

Todo es auto-contenido: el daemon Rust (`niri-animation-rotate`) está compilado estáticamente con musl y se incluye en `bin/`. No necesitás Rust, ni compilar, ni instalar el daemon manualmente.

## Funcionalidades

- **Botones Prev/Next** para rotar entre animaciones de ventanas de Niri
- **Selector de animación** — dropdown con todas las animaciones detectadas
- **Modo Auto/Manual** — rotar automáticamente con eventos de ventana, o manualmente
- **Filtros de eventos** — ignorar eventos de ventana abierta o cerrada
- **Pastilla en DankBar** — muestra el nombre de la animación actual en la barra de estado
- **Ventana flotante** (380×600) — todos los controles en un panel dedicado
- **Ruta del socket e intervalo de refresco configurables**

## Requisitos

- Compositor [Niri](https://github.com/YaLTeR/niri) (v0.1.5+)
- Dank Material Shell >= 1.4.0

El daemon (`niri-animation-rotate`) viene incluido — no necesitás instalar nada más.

## Instalación

### Marketplace de Plugins de DMS (recomendado)

1. Abrí DMS → Configuración → Plugins → Explorar
2. Buscá "Animation Rotate"
3. Clic en Instalar
4. Activá el plugin — ya está listo

El plugin inicia automáticamente el daemon y configura todos los archivos necesarios en la primera activación.

### Manual

```bash
git clone https://github.com/pnbarbeito/dms-niri-animation-rotate.git \
  ~/.config/DankMaterialShell/plugins/animationRotate/
```

Luego activá el plugin desde DMS → Configuración → Plugins → Local.

## Configuración

Configurá la ruta del socket y el intervalo de refresco desde la página de configuración del plugin (clic derecho en el widget → Configuración). El resto de los ajustes del daemon se manejan desde la UI del widget.

### Atajos de teclado

Para asignar teclas a next/prev, agregá comandos personalizados en DMS → Configuración → Atajos:

| Acción | Comando |
|---|---|
| Siguiente animación | `echo 'next' \| nc -U <pluginDir>/control.sock` |
| Animación anterior | `echo 'prev' \| nc -U <pluginDir>/control.sock` |

La ruta exacta del socket se muestra en la página de configuración del plugin.

## Capturas de pantalla

<!-- TODO: agregar capturas -->
<!-- ![Centro de Control](./screenshots/control-center.png) -->
<!-- ![Panel flotante](./screenshots/popout.png) -->

## Licencia

MIT — ver [LICENSE](./LICENSE).

## Agradecimientos

Las 49 animaciones incluidas en este plugin **no son de mi autoría**. Fueron creadas por talentosos autores y recopiladas de la comunidad.

### Autores y fuentes

- **[chaoscatsofficial@gmail.com](mailto:chaoscatsofficial@gmail.com)** — 16 animaciones (bloom, burn-ashes, burn, burn-multicolor, explode, fold-window, glitch_00, glitch-cyberpunk, glitch, halftone, pixelate, pop-drop, ribbons, roll-drop, swipe-window, unravel)  
  Fuente: [XansiVA/nirimation](https://github.com/XansiVA/nirimation)

- **[Justin Garza](mailto:JGarza9788@gmail.com)** — 7 animaciones (blur, chromatic_edge, energize_b_niri, glide, incinerate, prism_fold, tv_crt)  
  Fuente: [jgarza9788/niri-animation-collection](https://github.com/jgarza9788/niri-animation-collection)

- **[Joe Hsu](mailto:jhsu.x1@gmail.com)** — 2 animaciones (dither-glitch, pixel-sort)  
  Fuente: [jgarza9788/niri-animation-collection](https://github.com/jgarza9788/niri-animation-collection)

- **liixini** ([github.com/liixini](https://github.com/liixini)) — 24 animaciones (circle, crosshatch, crosswarp, directiona-wipe, directional, disolve, fade, flyeye, glass-warp, glitch_01, heat-melt, ink-splash, inkwell-drop, morph, perlin, pixelfade-wave, plasma-flow, polar-function, polka-dots-curtain, randomsquares, smoke, snap, voronoi-shatter, wave-warp)  
  Fuentes: [liixini/shaders](https://github.com/liixini/shaders)

¡Gracias a todos por compartir su increíble trabajo con la comunidad de Niri!

## Relacionado

- [niri-animation-rotate](https://github.com/pnbarbeito/niri-animation-rotate) — código fuente del daemon Rust y releases independientes.
