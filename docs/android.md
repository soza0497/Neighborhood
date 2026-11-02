# Exportar a Android (CachyOS)

Basado en la documentación oficial de Godot 4.7, "Exporting for Android".
Se hace **una sola vez** por PC. Después, exportar es un clic.

## Qué hace falta y por qué

| Pieza | Para qué sirve | Cómo se instala aquí |
|---|---|---|
| JDK 17 (Java) | Firma el APK (`apksigner`, `keytool`) | pacman: `jdk17-openjdk` |
| Android SDK | Herramientas de Android: `adb` (habla con el teléfono) y `build-tools` | Android Studio desde Flathub (trae un gestor del SDK con ventanas) |
| Plantillas de exportación 4.7.2 | El "motor" ya compilado para Android que Godot mete en el APK | Desde el editor de Godot |
| Clave de depuración | Firma de prueba; sin firma, Android no instala | Godot la crea sola en `~/.local/share/godot/keystores/debug.keystore` |

Godot pide estas versiones del SDK: Platform-Tools 35 o más, Build-Tools
35.0.1, Platform Android 35 y Command-line Tools (latest). CMake y NDK solo
hacen falta para "Gradle build", que este proyecto **no** usa todavía.

## 1. Java 17

```
sudo pacman -S --needed jdk17-openjdk
```
- `-S` instala, `--needed` no reinstala si ya está.
- Queda en `/usr/lib/jvm/java-17-openjdk`.
- Comprobar: `archlinux-java status` debe mostrar `java-17-openjdk (default)`.
- Revertir: `sudo pacman -Rns jdk17-openjdk`.

## 2. Android SDK (con Android Studio de Flathub)

1. Abrí **Discover** → buscá **Android Studio** → Instalar (descarga ~1,6 GB
   de dl.google.com). O en terminal: `flatpak install flathub com.google.AndroidStudio`.
2. Abrilo. En el asistente de bienvenida elegí **Standard** y aceptá las
   licencias. El SDK queda en `~/Android/Sdk` (ruta que Godot ya tiene puesta).
3. En la pantalla de bienvenida: **More Actions → SDK Manager**.
   - Pestaña **SDK Platforms**: marcá **Android 15.0 ("VanillaIceCream") — API 35**.
   - Pestaña **SDK Tools**: marcá **Show Package Details** (abajo a la
     derecha) y dentro de **Android SDK Build-Tools** marcá **35.0.1**.
     Marcá también **Android SDK Command-line Tools (latest)** y
     **Android SDK Platform-Tools**.
   - **Apply** → OK. Esperá a que termine.
4. Android Studio ya se puede cerrar: Godot solo usa los archivos del SDK.

Revertir: desinstalar desde Discover y borrar `~/Android`.

## 3. Configurar Godot (una vez)

1. Abrí Godot → el proyecto Neighborhood.
2. **Editor → Configuración del editor → Exportar → Android**:
   - **Java SDK Path**: `/usr/lib/jvm/java-17-openjdk`
   - **Android SDK Path**: `/home/asoza97/Android/Sdk` (ya viene puesto)
3. **Editor → Administrar plantillas de exportación → Descargar e instalar**
   (descarga oficial de godotengine.org, ~1 GB). Debe decir "4.7.2.stable".

## 4. Preparar el teléfono

1. **Ajustes → Acerca del teléfono** → tocá 7 veces **Número de compilación**
   (activa las Opciones de desarrollador).
2. **Ajustes → Sistema → Opciones de desarrollador** → activá **Depuración por USB**.
3. Conectá el teléfono por USB a un puerto trasero de la PC (no al switch
   KVM). En el teléfono aparece "¿Permitir depuración USB?" → **Permitir**.
4. Comprobá en la terminal: `~/Android/Sdk/platform-tools/adb devices`
   debe mostrar una línea con `device` al final.
   - Si dice `unauthorized`: aceptá el aviso en el teléfono.
   - Si dice `no permissions`: falta la regla udev (paquete `android-udev`);
     avisá a Claude antes de instalarlo.

## 5. Exportar

**Opción A — un clic (con cable):** en Godot, arriba a la derecha, el botón
con el ícono de Android ("Despliegue remoto") instala y abre el juego en el
teléfono.

**Opción B — archivo APK:** **Proyecto → Exportar… → Android → Exportar
proyecto** → guardá en `build/neighborhood.apk`. Pasalo al teléfono con
**LocalSend** y abrilo; Android pedirá permitir "instalar apps desconocidas"
para LocalSend o el gestor de archivos.

**Opción C — terminal** (lo que usa Claude para comprobar):
```
godot --headless --path . --export-debug "Android" build/neighborhood.apk
~/Android/Sdk/platform-tools/adb install -r build/neighborhood.apk
```
`-r` reemplaza la versión instalada sin borrar la partida.
