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

- Entorno Android listo (2026-11-02, comprobado): jdk17-openjdk 17.0.20 por
  defecto, Android Studio 2026.2.2.8 (Flathub), SDK en `~/Android/Sdk` con
  build-tools 35.0.1 y platform android-35, plantillas Android 4.7.2,
  debug.keystore creada, rutas puestas en el editor.
- **APK de depuración exportado por terminal y verificado**: 29,7 MB,
  firmado con la clave de depuración, solo arm64-v8a, incluye `catalog.json`.

### Falta para cerrar la Fase 0
1. [Dueño] Activar depuración USB en el teléfono y conectarlo (o pasar el APK
   con LocalSend).
2. [Dueño] Probar en el teléfono: arrastrar, pellizcar, girar, Centrar,
   cerrar y reabrir (la cámara debe quedar donde estaba). Anotar los FPS.
3. [Claude] Corregir lo que salga de la prueba; commit "Fase 0 cerrada".

### Próximo paso exacto
Con el teléfono conectado: `~/Android/Sdk/platform-tools/adb devices`,
exportar con `godot --headless --path . --export-debug "Android" build/neighborhood.apk`
e instalar con `~/Android/Sdk/platform-tools/adb install -r build/neighborhood.apk`.

### Preguntas abiertas para el dueño
- ¿Horizontal te parece bien? (ver DECISIONES.md, "Orientación").
- ¿Tu pareja usa Android o iPhone? (VISION.md)

## Fases siguientes
- Fase 1 — Constructor de casas (conviene Sonnet). Si no cabe en una sesión:
  1A cuadrícula + cimientos/pisos/paredes, 1B puertas/ventanas/techo/segundo
  piso, 1C muebles + pintar + deshacer + guardar.
