# Recon estático — `XuperTv-N0F4C3-v6.72.1.apk`

> Estudio de ingeniería inversa de **un APK de terceros**, con fines de entender su
> protocolo de red y su UX. **No es código nuestro, no copiar sus recursos, clases ni
> assets.** Todo lo que sigue son *observaciones* de un artefacto ajeno.

- **Ruta**: `E:\APKS\TV\XuperTv-N0F4C3-v6.72.1.apk`
- **SHA-256**: `3bd9423f4c9efafa6821bf356b04c8ab5c8f0e5602aeb2e3f498fbae202038bc`
- **Tamaño**: 36.169.670 bytes · 2.277 entradas ZIP
- **Método**: minado de strings sobre `classes*.dex`, `resources.arsc`, `lib/*.so` y `assets/*`
  (sin descompilar). Cobertura: **cadenas literales visibles**, no flujo de control ni payloads.

---

## 1. Qué es (observado)

| Dato | Evidencia |
|---|---|
| App **Android nativa** (Java/Kotlin), **no Flutter** | `classes.dex`, `classes2.dex`, `classes3.dex`; ausencia total de `libapp.so` / `assets/flutter_assets` |
| **Reempaquetada / modded** | `org.repackage.com`, `META-INF/NOFACE.RSA`, `assets/bangcle_classes.jar`, `assets/dexprotect.dat`, `libDexHelper.so`, `libboost_multidex.so`, `libnfguard.so`, `libnfx.so` |
| Huella del modder | `https://t.me/N0F4C3Mods`, `https://yumao.puata.info/cc_info`, `https://yumao.puata.info/anti_logs` |
| Player propio | ijkplayer + ffmpeg propio: `libijkffmpeg.so`, `libijkplayer.so`, `libijksdl.so` |
| Navegación modular (Alibaba Therouter) | rutas `http://module_main/HomeActivity`, `http://module_vod/VodDetailsActivity`, `module_mine/UserCenterActivity`, `module_login/ForcePasswordChangeActivity`, `download/DownloadActivity` |
| Analytics / ads / crash | Umeng (UPush, APM), Google Ads, Firebase Crashlytics, GMS |
| Soporte de email/contacto | `escuchamos-tv@outlook.com`, dominios de email válidos para login (`gmail`, `hotmail`, `outlook`, `uol.com.br`, `bol.com.br`…) |
| Pantalla anti-piratería | `assets/test1.html` → *"Illegal users"* |

**Inferencia (no observada)**: el binario real probablemente se desempaca en runtime
(protector Bangcle/DexHelper), por lo que parte del código puede no estar legible en el DEX estático.

---

## 2. Superficie de API (observado)

93 plantillas con la forma **`{agreement}://{ip}/…`** (host e inyección en runtime).
Dominio raíz: **`api/portalCore/*`** (88 rutas), más `adserver`, `subs` y `epg`.

### 2.1 Home / contenido / catálogo
```
GET /api/portalCore/getHome
GET /api/portalCore/config/get
GET /api/portalCore/v3/getProgram
GET /api/portalCore/v3/getColumnContents
GET /api/portalCore/v3/getColumnRecommendResource
GET /api/portalCore/getRecommendColumnContents
GET /api/portalCore/getNextColumns
GET /api/portalCore/v3/getRecommends
GET /api/portalCore/v3/getShelveData
GET /api/portalCore/v4/getItemData
GET /api/portalCore/v6/getLiveData
GET /api/portalCore/v3/filterGenre
GET /api/portalCore/v3/filterByContent
GET /api/portalCore/v2/getFree
```

### 2.2 Búsqueda
```
GET /api/portalCore/v3/searchByName
GET /api/portalCore/v3/searchByContent
GET /api/portalCore/blSearchByName
GET /api/portalCore/blSearchByContent
GET /api/portalCore/liveSearchByName
GET /api/portalCore/searchResourceOrPerson
```

### 2.3 Autenticación / sesión / dispositivos
```
POST /api/portalCore/v8/login
POST /api/portalCore/v8/active
POST /api/portalCore/register
POST /api/portalCore/v5/loginOut
POST /api/portalCore/v5/heartbeat
POST /api/portalCore/v3/snToken
POST /api/portalCore/terminalAuth
POST /api/portalCore/getVerifiCode
POST /api/portalCore/checkVerifiCode
POST /api/portalCore/v2/sendEmailVerifyCode
POST /api/portalCore/v2/validateVerifyCode
POST /api/portalCore/pwdCheck
POST /api/portalCore/setPassword
POST /api/portalCore/v4/resetPwd
POST /api/portalCore/checkForceBind
POST /api/portalCore/bindPhone / changeBindPhone / unBind
POST /api/portalCore/bindEmailGiftDays
POST /api/portalCore/v2/bindEmail / v2/changeBindEmail / unBindEmail
POST /api/portalCore/updateBindEmailOrPwd
POST /api/portalCore/emailResetPassNotice
POST /api/portalCore/getEmailSuffix
POST /api/portalCore/device/updateOrInsert
POST /api/portalCore/device-management/getDevice / deleteDevice
POST /api/portalCore/v9/getAuthInfo
POST /api/portalCore/getAreaCode
POST /api/portalCore/getBaseTime
POST /api/portalCore/getPerson / getItemByPerson
POST /api/portalCore/v2/getInviteCode
POST /api/PreInstall/auth
```

### 2.4 QR login (típico TV ↔ móvil)
```
/api/portalCore/qr/token
/api/portalCore/qr/allowLogin
/api/portalCore/v5/qr/getResult
```

### 2.5 Playback (marcado de inicio de reproducción)
```
/api/portalCore/v10/startPlayVOD
/api/portalCore/v4/startPlayLive
/api/portalCore/v6/startPlayBTV
```

### 2.6 Favoritos / suscripción / paquetes / cupones
```
/api/portalCore/v2/addFavorite · delFavorite · getFavorite
/api/portalCore/addSubscribe · delSubscribe · getSubscribe
/api/portalCore/v5/exchange · getExchangeOrderInfo
/api/portalCore/package/getOrderInfo · getPackageCustomization
/api/portalCore/apkQueryCoupon · apkReceiveCoupon
/api/subs/terminal/metadata
```

### 2.7 EPG / directo / deportes
```
{protocol}://{ip}/epg/v2/live/app/utc{timezone}/{liveType}
/api/portalCore/epg/v2/getLineUps · getAllMatch · getMatchDetail
/api/portalCore/epg/v2/getShelveMatch · getTeamEvent · getScoreboard
/api/portalCore/epg/v3/getFootballMatch
/api/portalCore/epg/v4/getNearestMatch · /epg/v5/getNearestMatch
/api/portalCore/getAllbackProgram
/api/portalCore/v6/getLiveData · v4/startPlayLive
```

### 2.8 Descubrimiento de infra (SLB / dominios)
```
/api/portalCore/v14/getSlbInfo
/api/portalCore/v15/getSlbInfo      → GetSlbInfoBean(userToken=…, …)
```

### 2.9 Anuncios / avisos / feedback
```
/api/adserver/v2/get_content · /api/adserver/report
/api/portalCore/feedback/userFeedBack · getCustomerService
http://%s/notice/api/get_notice?pkg=%s&v=%s[&sn=%s][&userId=%s][&language=…]
http://%s/#/feedback?appId=%s&userId=%s&lang=%s&appVersion=%s&…&tvType=1
```

---

## 3. Resolución de dominios (observado)

`assets/domain_test.json` declara el esquema de dominios con **placeholders `xx`**:

```json
{ "upgrade_main": "xx", "upgrade_backup": "xx", "portal_main": "xx",
  "epg_main": "xx", "market_main": "xx", "epg4b_sn_main": "xx",
  "epg4b_data_main": "xx", "diamond_main": "xx", "notice_main": "xx",
  "dccore_main": "xx", "datacollect_main": "xx", "ad_main": "xx", … }
```

Tipos de dominio vistos en código: `PORTAL_MAIN`, `EPG_MAIN`, `UPGRADE_MAIN`,
`MARKET_MAIN`, `DIAMOND_MAIN`, `DCCORE_MAIN`, `NOTICE_MAIN`, `NOTICE_SERVER`,
`AD_MAIN`, `AD_STORAGE`, `datacollect_*` (cada uno con `_main` / `_backup`).

Otros indicios de resolución dinámica: `getDefaultGateway`, `gatewayAddress`,
`gatewayMac`, `domainType`, `getDomainHashIndex`, `HTTPS, PORTAL_MAIN, json`.

### Hosts sí hardcodeados (no son la API de contenido)
```
https://www.tvmagis.net/download
https://yumao.puata.info/cc_info
https://yumao.puata.info/anti_logs
```

### ❓ Desconocido (requiere JADX o captura de tráfico)
- El **host real** de `portalCore` y `epg` (el valor de `{ip}`).
- Métodos HTTP, headers de auth (`userToken`, `snToken`), firma y payloads de cada endpoint.
- Formato de respuesta (beans `GetSlbInfoBean`, `Epg4bRequestBean`, `GetItemData…`).

---

## 4. Conclusión para AurisTV

1. **No hace falta tocar el APK** para aprovechar esto: la superficie de API está
   mapeada y es HTTP/JSON corriente → se puede implementar en Dart dentro de `Core/`
   (servicios `Dio`) manteniendo el 100 % de nuestra UI Flutter.
2. **No parchear su UI en su APK**: viene protegido (Bangcle + NOFACE), es código
   ajeno ya moddeado por un tercero, y nuestro cliente es Flutter (otro runtime).
3. Siguiente paso para cerrar los huecos: decompilar con **JADX** (REA necesita
   `REA_JADX_MCP_JAR` apuntando a un JAR `jadx-headless-mcp 0.7.1` que provee el usuario)
   y leer `request/bean/*` + `NetClient` para extraer host, headers y payloads.

---

## 5. Resultado de la descompilación (JADX) — hosts y crypto RESUELTOS ✅

> Descompilación guiada con `jadx-headless-mcp 0.7.1` (REA). Contexto completo y reanudable en
> `E:\APKS\TV\REA XUPERTV\` (leer `01_contexto_reanudacion.md`).

### 5.1 Hosts reales (descifrados de resources)

Los dominios de `assets/domain_test.json` son placeholders `xx`; los reales viven en resources
strings **cifrados** (hex → base64 → 3DES/ECB con clave `*&@!6d5d-c483-4720-bb29-785b8f321c^%`):

| resource | host |
|---|---|
| `portal_main` | `fuxok.nguvmqhpk.com` |
| `portal_backup` | `mptec.dhkrxuzcy.com` |
| `epg_main` | `vgwbm.uwfyobivh.com` |
| `epg_backup` | `rokbd.ysrkwctjg.com` |
| `upgrade_main` | `jetsb.hgwtqrpmo.com` |
| `notice_main` | `zxiws.tcgwhnvym.com` |
| `ad_main` | `yvhcn.hxjebagrv.com` |
| `bigbee_main` | `eskna.ucpjdhivl.com` |

Todos Cloudflare y vivos (GET `/` → 403/404).

### 5.2 Pipeline de petición

- Retrofit con base URL dummy `http://www.baidu.com`; host real = `@Path("ip")`, esquema = `@Path("agreement")`.
  Plantilla `{agreement}://{ip}/api/portalCore/...`, **POST** `application/json; charset=utf-8`.
- Interceptor `zb.c` (+ `zb.b`) parsea el body, añade **16 parámetros comunes** (`loginType`,
  `appLanguage`, `apkVersion`, `sysVersion`, `appId`, `hardwareInfo`, `model`, `product`, `cpu`,
  `B29`, `reserve1`, `portalCode`, `deviceToken`, `sn`, `drmId`, `sdkVer`) y **cifra** por defecto
  (`zb.b.c()==true`), salvo los métodos anotados `needEncrypt:false`.

**Cifrado request (VALIDADO contra el server):**
```
clave  = base64("2b494e53756c664c2f44465245733572")        # 24 bytes
body   = hex( base64( 3DES/ECB/PKCS5(json_utf8, clave) ) )  # hex por char del base64
```

**Respuesta:** éxito = `returnCode:"0"`; si viene cifrada, `data` es 3DES-base64 a descifrar con la
misma clave. Errores vistos: `portal200001` (versión fuera de servicio), `500` (params), `999` (falta
`moduleName`).

### 5.3 Validación viva (resumen)

- `config/get` con body en claro → `500`; **con body cifrado → `999`/`{moduleName}`** ⇒ el server
  descifra y procesa correctamente. Crypto confirmado.
- `getBaseTime` → siempre `portal200001` (endpoint retirado/gated, no depende del body).

### 5.4 Pendiente para la integración

- Flujo de sesión: `v8/login`, `v3/snToken`, `terminalAuth`, `v14/v15/getSlbInfo`, `v9/getAuthInfo`.
- Payloads de contenido: `getHome`, `v3/getProgram`, `v3/getColumnContents`, `v4/getItemData`,
  `v6/getLiveData`, `startPlay*` (`GetPlayUrlResult`).
- Reimplementar en Dart dentro de `Core/packages/auris_core` (servicios `Dio`).
