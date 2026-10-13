# dms-niri-animation-rotate

Control de rotación de animaciones de ventanas de Niri para [Dank Material Shell](https://danklinux.com). Cambiá animaciones, alterná entre modo automático/manual y filtrá eventos — todo desde el Centro de Control. **Daemon nativo de DMS — sin binarios incluidos.**

## Cómo funciona

```
┌──────────────────────────────┐     en proceso      ┌──────────────────────────┐
│  Plugin DMS (QML)            │ ◄─────────────────► │  Daemon AnimationRotate  │
│  widget + UI del Centro de   │   referencias QML   │  (superficie daemon, QML)│
│  Control                     │      directas       │                          │
└──────────────────────────────┘                     └────────────┬─────────────┘
                                                                  │ escribe
                                   control.sock (opcional,         ▼  animation.kdl
                                   para nrctl / atajos)   ~/.config/niri/dms/
```

1. **Instalá** desde el Marketplace de Plugins de DMS (1 clic).
2. **Activá** el plugin — DMS crea la superficie daemon junto con el widget.
3. **Controlá** tus animaciones de Niri desde el Centro de Control, la DankBar o el panel flotante.
4. **Aceptá el include** — la primera vez que el plugin pide permiso para agregar `include "dms/animation.kdl"` a tu config de niri (o agregalo a mano).

Todo corre dentro de DMS como QML: el daemon es una *superficie daemon* del plugin, así su ciclo de vida queda atado al propio plugin (activado → corriendo, desactivado → detenido). No hay procesos externos, ni binarios empaquetados, ni sondeos entre widget y daemon — la UI se enlaza directamente al estado del daemon.

## Funcionalidades

- **Botones Prev/Next** para rotar entre animaciones de ventanas de Niri
- **Selector de animación** — dropdown con todas las animaciones detectadas
- **Modo Auto/Manual** — rotar automáticamente con eventos de ventana, o manualmente
- **Filtros de eventos** — ignorar eventos de ventana abierta o cerrada
- **Cooldown de rotación** — tiempo mínimo entre rotaciones automáticas
- **Orden aleatorio** — mezclar los presets en lugar de rotarlos alfabéticamente
- **Pastilla en DankBar** — muestra el nombre de la animación actual en la barra de estado
- **Panel flotante** — todos los controles en una ventana dedicada

## Requisitos

- Compositor [Niri](https://github.com/YaLTeR/niri)
- Dank Material Shell >= 1.5.0 (plugin `composite` nativo con superficie daemon)

No necesitás toolchain de Rust, descargas de binarios ni `netcat` (opcional — ver Atajos de teclado).

## Instalación

### Marketplace de Plugins de DMS (recomendado)

1. Abrí DMS → Configuración → Plugins → Explorar
2. Buscá "Animation Rotate"
3. Clic en Instalar
4. Activá el plugin — ya está listo

### Manual

```bash
git clone https://github.com/pnbarbeito/dms-niri-animation-rotate.git \
  ~/.config/DankMaterialShell/plugins/animationRotate/
```

Luego activá el plugin desde DMS → Configuración → Plugins → Local.

### El include de niri (una vez, con tu consentimiento)

Niri solo aplica animaciones a través de un include en su archivo de configuración:

```kdl
include "dms/animation.kdl"
```

El plugin **nunca edita tu config en silencio**. En la primera activación aparece una
tarjeta en la vista de detalle del Centro de Control:

- **Add include** — el plugin agrega exactamente una línea a `~/.config/niri/config.kdl`
  (respetando `XDG_CONFIG_HOME`) y recuerda tu respuesta. Niri toma el cambio
  automáticamente.
- **Show instructions** — el plugin se mantiene fuera de tu config y te muestra la línea
  para agregarla vos mismo. No vuelve a preguntar.

Si el include ya está, no se muestra ninguna tarjeta.

## Configuración

Abrí la página de configuración del plugin (clic derecho en el widget → Configuración) para ajustar:

- **Cooldown de rotación** (`cooldown-ms`) — debounce extra sobre la duración de cada animación
- **Ignorar ventana abierta / cerrada** — filtros de eventos para el modo Auto
- **Orden aleatorio** — mezclar la lista de rotación
- **Ruta del socket de control** — override; por defecto `<pluginDir>/control.sock`,
  resuelto a través del directorio de plugins de DMS (respeta `XDG_CONFIG_HOME`)

El resto de los controles viven en la UI del widget y se aplican al instante.

### Atajos de teclado (opcional)

El daemon sirve un socket Unix de control compatible con `nrctl` y con comandos de
shell simples. Para asignar teclas a next/prev, agregá comandos personalizados en
DMS → Configuración → Atajos (requiere netcat con soporte de sockets Unix, p. ej.
`netcat-openbsd`):

| Acción | Comando |
|---|---|
| Siguiente animación | `echo 'next' \| nc -U <pluginDir>/control.sock` |
| Animación anterior | `echo 'prev' \| nc -U <pluginDir>/control.sock` |

La ruta exacta del socket se muestra en la página de configuración del plugin.

## Nota de arquitectura: el daemon Rust upstream sigue existiendo

Este plugin antes lanzaba una build empaquetada de
[niri-animation-rotate](https://github.com/pnbarbeito/niri-animation-rotate) (Rust).
Ese binario se eliminó: la lógica del daemon ahora está portada a QML y corre dentro de
DMS. El daemon Rust upstream sigue siendo una buena **alternativa standalone** si querés
rotación fuera de DMS — trae su propio `nrctl` y sus releases, y el socket de control de
este plugin habla la misma gramática de comandos.

## Capturas de pantalla

![Animation Rotate](./screenshots/widget.png)

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

- [niri-animation-rotate](https://github.com/pnbarbeito/niri-animation-rotate) — el daemon Rust upstream (alternativa standalone) y su código fuente.
