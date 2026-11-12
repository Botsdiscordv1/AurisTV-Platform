package com.auristv.oficial

import android.app.PictureInPictureParams
import android.app.PendingIntent
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.util.Rational
import android.view.KeyEvent
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * AudioServiceFragmentActivity (que hereda de FlutterFragmentActivity):
 * - Google Cast necesita getSupportFragmentManager() de FragmentActivity para MediaRouteChooserDialog.
 * - audio_service necesita su propia base para compartir el FlutterEngine y notificaciones en lock screen.
 * AudioServiceFragmentActivity combina ambos requisitos a la perfección.
 */
class MainActivity: AudioServiceFragmentActivity() {
    private val BRIGHTNESS_CHANNEL = "auristv/brightness"
    private val VOLUME_CHANNEL = "auristv/volume"
    private val PIP_CHANNEL = "auristv/pip"
    private val ORIENTATION_CHANNEL = "auristv/orientation"
    private val INSTALL_CHANNEL = "auristv/install"
    private val NETWORK_CHANNEL = "auristv/network"
    private val WAKELOCK_CHANNEL = "auristv/wakelock"
    private var wakeLock: android.os.PowerManager.WakeLock? = null
    private var interceptVolume = false
    private var volumeMethodChannel: MethodChannel? = null
    private var isPipAllowed = false
    private var currentAspectRatioWidth = 16
    private var currentAspectRatioHeight = 9
    private var isPipPlaying = true
    private var isPipHasPrev = true
    private var isPipHasNext = true
    private var isInPlayer = false
    private var multicastLock: android.net.wifi.WifiManager.MulticastLock? = null

    private val ACTION_PIP_CONTROL = "com.auristv.oficial.PIP_CONTROL"
    private val EXTRA_CONTROL_TYPE = "control_type"
    private val CONTROL_TYPE_PREV = 1
    private val CONTROL_TYPE_PLAY_PAUSE = 2
    private val CONTROL_TYPE_NEXT = 3

    private val pipBroadcastReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: android.content.Intent?) {
            if (intent?.action == ACTION_PIP_CONTROL) {
                val controlType = intent.getIntExtra(EXTRA_CONTROL_TYPE, 0)
                val actionName = when (controlType) {
                    CONTROL_TYPE_PREV -> "prev"
                    CONTROL_TYPE_PLAY_PAUSE -> "playPause"
                    CONTROL_TYPE_NEXT -> "next"
                    else -> ""
                }
                if (actionName.isNotEmpty()) {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, PIP_CHANNEL).invokeMethod("onPipAction", actionName)
                    }
                }
            }
        }
    }

    private fun buildPipParams(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null

        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(currentAspectRatioWidth, currentAspectRatioHeight))

        val actions = java.util.ArrayList<android.app.RemoteAction>()

        // 1. Botón Anterior (⏮️)
        if (isPipHasPrev) {
            val intentPrev = android.content.Intent(ACTION_PIP_CONTROL).putExtra(EXTRA_CONTROL_TYPE, CONTROL_TYPE_PREV)
            val pendingPrev = android.app.PendingIntent.getBroadcast(
                this, CONTROL_TYPE_PREV, intentPrev,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            val iconPrev = android.graphics.drawable.Icon.createWithResource(this, android.R.drawable.ic_media_previous)
            actions.add(android.app.RemoteAction(iconPrev, "Anterior", "Episodio Anterior", pendingPrev))
        }

        // 2. Botón Reproducir / Pausar (⏯️)
        val intentPlay = android.content.Intent(ACTION_PIP_CONTROL).putExtra(EXTRA_CONTROL_TYPE, CONTROL_TYPE_PLAY_PAUSE)
        val pendingPlay = android.app.PendingIntent.getBroadcast(
            this, CONTROL_TYPE_PLAY_PAUSE, intentPlay,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        val iconPlayRes = if (isPipPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val iconPlay = android.graphics.drawable.Icon.createWithResource(this, iconPlayRes)
        val labelPlay = if (isPipPlaying) "Pausar" else "Reproducir"
        actions.add(android.app.RemoteAction(iconPlay, labelPlay, labelPlay, pendingPlay))

        // 3. Botón Siguiente (⏭️)
        if (isPipHasNext) {
            val intentNext = android.content.Intent(ACTION_PIP_CONTROL).putExtra(EXTRA_CONTROL_TYPE, CONTROL_TYPE_NEXT)
            val pendingNext = android.app.PendingIntent.getBroadcast(
                this, CONTROL_TYPE_NEXT, intentNext,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            val iconNext = android.graphics.drawable.Icon.createWithResource(this, android.R.drawable.ic_media_next)
            actions.add(android.app.RemoteAction(iconNext, "Siguiente", "Siguiente Episodio", pendingNext))
        }

        builder.setActions(actions)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(isPipAllowed)
        }

        return builder.build()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val filter = android.content.IntentFilter(ACTION_PIP_CONTROL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipBroadcastReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(pipBroadcastReceiver, filter)
        }

        // Senior Immersive Elite: Forzar el dibujo detrás del Notch y barras de sistema
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        window.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
    }

    override fun onDestroy() {
        try { unregisterReceiver(pipBroadcastReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Prototipo de video nativo (TextureView + vo=mediacodec_embed).
        // Solo se usa si Dart compila con NATIVE_VIDEO_SURFACE=true.
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "auris/mobile-video-surface",
            MobileVideoSurfaceFactory(flutterEngine.dartExecutor.binaryMessenger),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BRIGHTNESS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBrightness" -> {
                    val brightness = call.argument<Double>("value")?.toFloat() ?: -1f
                    val lp = window.attributes
                    lp.screenBrightness = brightness
                    window.attributes = lp
                    result.success(null)
                }
                "getBrightness" -> {
                    val brightness = window.attributes.screenBrightness
                    result.success(brightness.toDouble())
                }
                else -> result.notImplemented()
            }
        }

        volumeMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL)
        volumeMethodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "setIntercept") {
                interceptVolume = call.argument<Boolean>("enabled") ?: false
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val width = call.argument<Double>("aspectRatioWidth")?.toInt() ?: 16
                        val height = call.argument<Double>("aspectRatioHeight")?.toInt() ?: 9
                        currentAspectRatioWidth = width
                        currentAspectRatioHeight = height

                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, PIP_CHANNEL).invokeMethod("prepareForPip", null)
                        }

                        val params = buildPipParams()
                        val success = if (params != null) enterPictureInPictureMode(params) else false
                        result.success(success)
                    } else {
                        result.error("UNSUPPORTED", "PiP requires Android 8.0+", null)
                    }
                }
                "setPipAllowed" -> {
                    isPipAllowed = call.argument<Boolean>("allowed") ?: false
                    val width = call.argument<Double>("aspectRatioWidth")?.toInt() ?: 16
                    val height = call.argument<Double>("aspectRatioHeight")?.toInt() ?: 9
                    currentAspectRatioWidth = width
                    currentAspectRatioHeight = height

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            buildPipParams()?.let { setPictureInPictureParams(it) }
                        } catch (e: Exception) {
                            android.util.Log.d("AurisPip", "setPipAllowed params error: ${e.message}")
                        }
                    }
                    result.success(null)
                }
                "updatePipActions" -> {
                    isPipPlaying = call.argument<Boolean>("isPlaying") ?: true
                    isPipHasPrev = call.argument<Boolean>("hasPrev") ?: true
                    isPipHasNext = call.argument<Boolean>("hasNext") ?: true

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            buildPipParams()?.let { setPictureInPictureParams(it) }
                        } catch (e: Exception) {
                            android.util.Log.d("AurisPip", "updatePipActions error: ${e.message}")
                        }
                    }
                    result.success(null)
                }
                "setPlayerActive" -> {
                    isInPlayer = call.argument<Boolean>("active") ?: false
                    result.success(null)
                }
                "isPipPermitted" -> {
                    result.success(hasPipPermission())
                }
                "openPipSettings" -> {
                    // No existe intent directo a los ajustes PiP: se abre la
                    // ficha de la app, donde vive el interruptor PiP.
                    try {
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            android.net.Uri.parse("package:$packageName"))
                        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.d("AurisPip", "openPipSettings failed: ${e.message}")
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ORIENTATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setOrientationLandscape" -> {
                    this@MainActivity.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                    result.success(null)
                }
                "setOrientationPortrait" -> {
                    this@MainActivity.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT
                    result.success(null)
                }
                "resetOrientation" -> {
                    this@MainActivity.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        installCastChannel(flutterEngine)

        // Wake lock parcial (CPU) para que el proxy HTTP local del cast siga
        // sirviendo bytes aunque la pantalla se apague (no mantiene la pantalla
        // encendida: mejor batería que wakelock_plus).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WAKELOCK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    try {
                        if (wakeLock == null || wakeLock?.isHeld != true) {
                            val pm = applicationContext.getSystemService(POWER_SERVICE) as android.os.PowerManager
                            wakeLock = pm.newWakeLock(
                                android.os.PowerManager.SCREEN_BRIGHT_WAKE_LOCK,
                                "auristv:video_player")
                            wakeLock?.setReferenceCounted(false)
                            wakeLock?.acquire()
                        }
                        result.success(wakeLock?.isHeld == true)
                    } catch (e: Exception) {
                        android.util.Log.d("AurisWakeLock", "acquire falló: ${e.message}")
                        result.success(false)
                    }
                }
                "release" -> {
                    try {
                        wakeLock?.let { if (it.isHeld) it.release() }
                        wakeLock = null
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.d("AurisWakeLock", "release falló: ${e.message}")
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Cast Local (LAN, sin login): muchos drivers de Wi-Fi filtran los
        // paquetes broadcast/multicast; el MulticastLock lo habilita.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    try {
                        if (multicastLock == null) {
                            val wifi = applicationContext
                                .getSystemService(WIFI_SERVICE) as android.net.wifi.WifiManager
                            multicastLock = wifi.createMulticastLock("auristv_local_cast").apply {
                                setReferenceCounted(false)
                                acquire()
                            }
                        }
                        result.success(multicastLock?.isHeld == true)
                    } catch (e: Exception) {
                        android.util.Log.d("AurisNetwork", "multicast lock falló: ${e.message}")
                        result.success(false)
                    }
                }
                "releaseMulticastLock" -> {
                    try {
                        multicastLock?.release()
                        multicastLock = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(canRequestInstall())
                "openInstallSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = android.content.Intent(
                                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                android.net.Uri.parse("package:$packageName"))
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.d("AurisInstall", "openInstallSettings failed: ${e.message}")
                        result.success(false)
                    }
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "Ruta de APK vacía", null)
                    } else {
                        try {
                            val file = java.io.File(path)
                            val uri = androidx.core.content.FileProvider.getUriForFile(
                                this@MainActivity, "$packageName.fileprovider", file)
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                            intent.setDataAndType(uri, "application/vnd.android.package-archive")
                            intent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.d("AurisInstall", "installApk failed: ${e.message}")
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Google Cast nativo (Chromecast): registra el canal una única vez.
    private fun installCastChannel(flutterEngine: FlutterEngine) {
        CastChannel.attach(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    private fun canRequestInstall(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun hasPipPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val hasFeature = packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
        var opAllowed = true
        try {
            val appOps = getSystemService(APP_OPS_SERVICE) as android.app.AppOpsManager
            val mode = appOps.checkOpNoThrow(
                android.app.AppOpsManager.OPSTR_PICTURE_IN_PICTURE,
                android.os.Process.myUid(), packageName)
            opAllowed = mode == android.app.AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) { opAllowed = true }
        val permitted = hasFeature && opAllowed
        android.util.Log.d("AurisPip", "hasPipPermission -> $permitted (feature=$hasFeature op=$opAllowed)")
        return permitted
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        val permitted = hasPipPermission()
        android.util.Log.d("AurisPip", "onUserLeaveHint allowed=$isPipAllowed permitted=$permitted sdk=${Build.VERSION.SDK_INT}")
        if (isPipAllowed && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Notificar a Flutter de inmediato antes de que el sistema tome la captura para PiP
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, PIP_CHANNEL).invokeMethod("prepareForPip", null)
            }
            // Sin re-afirmación forzada a true: el flag isPipAllowed ya lo
            // gobierna Dart (overlay pipReady: mini/full + item + url).
            // Re-afirmar true aquí resucitaba PiP vacío tras un stop/X
            // legítimo (setPipAllowed(false) en vuelo + Home inmediato).
            // El dispose del fullscreen ya no toca allowed, así que la
            // carrera contraria (mini sin PiP) no existe.
            // Entrada manual en TODAS las APIs: el auto-enter de Android 12+
            // (setAutoEnterEnabled) falla en varios OEMs; el manual es no-op
            // si el sistema ya esta entrando.
            try {
                val params = buildPipParams()
                if (params != null) {
                    val ok = enterPictureInPictureMode(params)
                    android.util.Log.d("AurisPip", "manual enterPictureInPictureMode -> $ok")
                }
            } catch (e: Exception) {
                android.util.Log.d("AurisPip", "manual enter failed: ${e.message}")
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: android.content.res.Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)

        // NO tocar requestedOrientation al salir: Flutter restaura la
        // orientacion previa al PiP (PipService.onPipChanged). Resetear aqui
        // a UNSPECIFIED abria una carrera donde el sensor decidia (p. ej.
        // apaisado) y luego Dart re-fijaba vertical con salto visible.
        android.util.Log.d("AurisPip", "onPictureInPictureModeChanged inPip=$isInPictureInPictureMode")
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, PIP_CHANNEL).invokeMethod("onPipChanged", isInPictureInPictureMode)
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (interceptVolume) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeMethodChannel?.invokeMethod("volumeUp", null)
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeMethodChannel?.invokeMethod("volumeDown", null)
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (interceptVolume) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    return true
                }
            }
        }
        return super.onKeyUp(keyCode, event)
    }
}
