# Guía de Release (AurisTV Platform)

Repositorio: `https://github.com/Botsdiscordv1/AurisTV-Platform.git`
Plataformas: `Movil` (Android/iOS), `TV` (Google TV), `Web_Desktop` (Web/Windows).
La app tiene **actualizador in-app**: descarga el APK de la última release de GitHub y lo instala.

---

## REGLA DE ORO: el `versionCode` NUNCA baja

Flutter deriva el `versionCode` de Android del **build number** del `pubspec.yaml` (todo lo que va después del `+`).
Los `build.gradle.kts` usan `versionCode = flutter.versionCode`.

Si el `versionCode` nuevo es **menor** que el instalado, Android rechaza la instalación con
`INSTALL_FAILED_VERSION_DOWNGRADE`, que en pantalla se ve como **"conflicto con el paquete / App not installed"**.
Ese fue el error de la `v1.0.3` original: se publicó `1.0.3+1` (código **1**) cuando `v1.0.2` ya era `1.0.2+2` (código **2**).

> **Antes de cada release, mira el `versionCode` de la release anterior y usa uno MAYOR.**
> Ante la duda, el build number = el anterior + 1 (o más).

| Release | versionName | versionCode |
|---------|-------------|-------------|
| v1.0.2  | 1.0.2       | 2           |
| v1.0.3  | 1.0.3       | **3** (correcto: `1.0.3+3`) |

El **`versionName`** (lo que ve el usuario, ej. `1.0.3`) es lo que compara el actualizador in-app para ofrecer la actualización.

---

## Cómo se publica (flujo correcto)

1. Asegúrate de que las **3** plataformas tengan el mismo `version` en su `pubspec.yaml`, con el build number correcto:
   - `Movil/pubspec.yaml`
   - `TV/pubspec.yaml`
   - `Web_Desktop/pubspec.yaml`
   ```yaml
   version: 1.0.3+3
   ```
2. Commit en `main` (sin `git add -A` a lo loco: revisa `git status` antes).
3. Crea un tag `v*` **anotado** en el commit del release y súbelo:
   ```powershell
   git tag -a v1.0.3 -m "AurisTV v1.0.3"
   git push origin main
   git push origin v1.0.3
   ```
4. El workflow `.github/workflows/release_all.yml` se dispara con el push del tag (`on: push: tags: v*`) y:
   - construye los APKs. En **Movil** debe incluir `--dart-define=NATIVE_VIDEO_SURFACE=true` para activar `SurfaceView` + `vo=mediacodec_embed`; en **TV** y **Web_Desktop** NO se pasa ese define (el flag queda apagado por defecto),
   - firma con el keystore de los secrets,
   - empaqueta Windows,
   - publica la release con `softprops/action-gh-release` (`body_path: RELEASE_NOTES.md`).
5. Espera a que el run termine en verde y verifica los assets (ver checklist).

---

## Assets esperados (NO cambiar los nombres)

El workflow renombra los APKs para que el actualizador los encuentre. El updater
(`Core/packages/auris_core/lib/data/services/app_update_service.dart`, `pickAsset`) selecciona por:
- prefijo `app-<flavor>-app-` (flavor = `mobile` o `tv`), y
- ABI del dispositivo (`arm64-v8a`, `armeabi-v7a`, `x86_64`).

Nombres correctos (7 assets por release):
```
app-mobile-app-arm64-v8a-release.apk
app-mobile-app-armeabi-v7a-release.apk
app-mobile-app-x86_64-release.apk
app-tv-app-arm64-v8a-release.apk
app-tv-app-armeabi-v7a-release.apk
app-tv-app-x86_64-release.apk
auristv-windows-x64.zip
```

### NO agregar un APK "universal"
El APK universal:
- **no lo usa el updater in-app** (su nombre `app-tv-universal-release.apk` no cumple el prefijo `app-tv-app-`),
- no arregla ningún problema de instalación, y
- solo agrega peso y confusión a la release.

Mantén el workflow en `--split-per-abi` únicamente (como v1.0.1/v1.0.2).

---

## NO tocar

- El **keystore** de firma (secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_UPDATE_ANDROID`/`KEY_ALIAS`).
  Una firma distinta provoca `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
- La firma local persistente está en `C:\Users\ALEX\AppData\Local\Temp\opencode\auristv-keystore\upload-keystore.jks` (alias `upload`). No la reemplaces.
- El paso "Decode release keystore" del workflow.
- No bumpees la versión "a probar" y luego la bajes: eso fue lo que rompió el `versionCode`.

---

## Procedimiento para rehacer una release mala

1. `git status` y revisa el `versionCode` que necesitas (mayor que el anterior).
2. Corrige `pubspec.yaml` en las 3 plataformas.
3. Commit en `main` y push.
4. Borra la release y el tag viejos (requiere token con scope `repo`):
   ```powershell
   # release (id via API):
   curl.exe -s -X DELETE -H "Authorization: token <TOKEN>" "https://api.github.com/repos/Botsdiscordv1/AurisTV-Platform/releases/<ID>"
   # tag remoto:
   git push origin :refs/tags/vX.Y.Z
   git tag -d vX.Y.Z
   ```
5. Recrea el tag en el nuevo commit y súbelo (ver flujo correcto).
6. Verifica que el CI quede verde y los assets sean los 7 de arriba.

---

## Player nativo en Móvil (`NATIVE_VIDEO_SURFACE`)

- El flag queda **apagado por defecto** en `Movil/lib/main.dart`.
- Para la release de **Móvil**, compilar siempre con:
  ```powershell
  flutter build apk --release --split-per-abi --dart-define=NATIVE_VIDEO_SURFACE=true
  ```
  o:
  ```powershell
  flutter build appbundle --release --dart-define=NATIVE_VIDEO_SURFACE=true
  ```
- El workflow `.github/workflows/release_all.yml` ya aplica ese define en `build-mobile`.
- **TV** y **Web_Desktop** no deben recibir ese define.
- HCPP (`hcpp=true`) queda sin validar por falta de dispositivo compatible; la app tiene fallback automático a modo textura (`hcpp=false`).

## Checklist antes de dar una release por buena

- [ ] `version` igual en `Movil`, `TV` y `Web_Desktop`.
- [ ] `versionCode` (build number) **mayor** que la release anterior.
- [ ] `versionName` **mayor** que la anterior (para que el usuario vea la actualización).
- [ ] Workflow en `--split-per-abi` (sin universal).
- [ ] Build de **Movil** con `--dart-define=NATIVE_VIDEO_SURFACE=true`.
- [ ] Builds de **TV** y **Web_Desktop** sin `--dart-define=NATIVE_VIDEO_SURFACE=true`.
- [ ] HCPP documentado como no validado por falta de dispositivo compatible; fallback a textura activo.
- [ ] Commit en `main` + tag `vX.Y.Z` anotado subidos.
- [ ] Run de CI en verde.
- [ ] Release con exactamente 7 assets y nombres correctos (sin universales).
- [ ] Probar instalación/actualización real sobre la versión anterior instalada.

---

## Errores comunes y su causa

| Síntoma al instalar | Causa | Solución |
|---|---|---|
| "Conflicto con el paquete" / App not installed | `versionCode` nuevo <= instalado (downgrade) | Subir el build number (`+N`) |
| Conflicto de paquete con firma | APK firmado con otra key / debug | Usar el keystore de los secrets |
| El updater no encuentra APK | Nombres de asset no cumplen `app-<flavor>-app-<abi>-release.apk` | Corregir el paso "Rename" del workflow |
| La app no ofrece actualización | `tag_name` igual o `versionName` no subió | Subir `versionName` y crear tag nuevo |

---

## Utilidades

- Actualizador: `Core/packages/auris_core/lib/data/services/app_update_service.dart` (`checkForUpdate`, `pickAsset`).
- Diálogo: `AppUpdateDialog(info, flavor: 'tv'|'mobile')`.
- Workflow: `.github/workflows/release_all.yml`.
- `gh` no está instalado en esta máquina; usar `curl.exe` contra la API de GitHub.
