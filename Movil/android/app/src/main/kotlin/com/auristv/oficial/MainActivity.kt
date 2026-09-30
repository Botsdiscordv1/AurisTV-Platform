package com.auristv.oficial

import android.app.PictureInPictureParams
import android.content.pm.ActivityInfo
import android.os.Build
import android.os.Bundle
import android.util.Rational
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val BRIGHTNESS_CHANNEL = "auristv/brightness"
    private val VOLUME_CHANNEL = "auristv/volume"
    private val PIP_CHANNEL = "auristv/pip"
    private val ORIENTATION_CHANNEL = "auristv/orientation"
    private var interceptVolume = false
    private var volumeMethodChannel: MethodChannel? = null
    private var isPipAllowed = false
    private var currentAspectRatioWidth = 16
    private var currentAspectRatioHeight = 9
    private var isInPlayer = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Senior Immersive Elite: Forzar el dibujo detrás del Notch y barras de sistema
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        window.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

                        // Notificar a Flutter que prepare la UI para PiP
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, PIP_CHANNEL).invokeMethod("prepareForPip", null)
                        }

                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(width, height))
                            .build()
                        val success = enterPictureInPictureMode(params)
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

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val params = PictureInPictureParams.Builder()
                            .setAutoEnterEnabled(isPipAllowed)
                            .setAspectRatio(Rational(width, height))
                            .build()
                        setPictureInPictureParams(params)
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
                "resetOrientation" -> {
                    this@MainActivity.requestedOrientation = android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                    result.success(null)
                }
                else -> result.notImplemented()
            }
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
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(currentAspectRatioWidth, currentAspectRatioHeight))
                    .build()
                val ok = enterPictureInPictureMode(params)
                android.util.Log.d("AurisPip", "manual enterPictureInPictureMode -> $ok")
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
