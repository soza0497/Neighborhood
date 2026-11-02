# Progreso

## Fase actual: 0 — Base del proyecto (código listo; falta probar en el teléfono)

### Hecho (2026-11-02)
- Repositorio Git (rama `main`) y carpetas `scenes/ scripts/ data/ assets/ ui/ docs/`.
- Autoloads: `EventBus`, `Catalog`, `GameState`, `SaveSystem`.
- Escena principal: terreno, lote, cubo de referencia, árboles, sol, cielo.
- Cámara táctil + mouse (`scenes/camera_rig.tscn`, `scripts/camera/camera_rig.gd`).
- HUD provisional: FPS, versión, objetos del catálogo, estado del guardado, botón Centrar.
- Guardado de la cámara al cerrar / pasar a segundo plano. Probado en PC
  (guardar → cargar devuelve los mismos datos).
- Catálogo de ejemplo en `data/catalog.json` (4 objetos), validado al arrancar.
- Preset de exportación "Android" (`export_presets.cfg`), probado: Godot lo lee
  bien y solo se queja de lo que falta instalar.
- `README.md`, `docs/android.md`, `DECISIONES.md`.

### Falta para cerrar la Fase 0
1. [Dueño] Instalar JDK 17, Android Studio (Flathub) y los componentes del SDK,
   plantillas de exportación 4.7.2 (ver `docs/android.md`).
2. [Dueño] Activar depuración USB en el teléfono y conectarlo.
3. [Claude] Poner la ruta de Java en la configuración del editor, exportar el
   APK por terminal, instalarlo con `adb` y comprobar que arranca.
4. [Dueño] Probar en el teléfono: arrastrar, pellizcar, girar, Centrar,
   cerrar y reabrir (la cámara debe quedar donde estaba). Anotar los FPS.
5. [Claude] Anotar en la bitácora lo instalado; commit "Fase 0 cerrada".

### Próximo paso exacto
Cuando el dueño diga que instaló todo (puntos 1 y 2): correr
`adb devices`, exportar con
`godot --headless --path . --export-debug "Android" build/neighborhood.apk`
e instalar con `adb install -r build/neighborhood.apk`.

### Preguntas abiertas para el dueño
- ¿Horizontal te parece bien? (ver DECISIONES.md, "Orientación").
- ¿Tu pareja usa Android o iPhone? (VISION.md)

## Fases siguientes
- Fase 1 — Constructor de casas (conviene Sonnet). Si no cabe en una sesión:
  1A cuadrícula + cimientos/pisos/paredes, 1B puertas/ventanas/techo/segundo
  piso, 1C muebles + pintar + deshacer + guardar.
