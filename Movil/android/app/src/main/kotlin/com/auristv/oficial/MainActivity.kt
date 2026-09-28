package com.auristv.oficial

import android.app.PictureInPictureParams
import android.content.pm.ActivityInfo
import android.graphics.Rect
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
    private var currentSourceRect: Rect? = null

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

                        val left = call.argument<Double>("rectLeft")?.toInt()
                        val top = call.argument<Double>("rectTop")?.toInt()
                        val right = call.argument<Double>("rectRight")?.toInt()
                        val bottom = call.argument<Double>("rectBottom")?.toInt()

                        val builder = PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(width, height))

                        if (left != null && top != null && right != null && bottom != null && right > left && bottom > top) {
                            currentSourceRect = Rect(left, top, right, bottom)
                            builder.setSourceRectHint(currentSourceRect!!)
                        }

                        val success = enterPictureInPictureMode(builder.build())
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

                    val left = call.argument<Double>("rectLeft")?.toInt()
                    val top = call.argument<Double>("rectTop")?.toInt()
                    val right = call.argument<Double>("rectRight")?.toInt()
                    val bottom = call.argument<Double>("rectBottom")?.toInt()

                    if (left != null && top != null && right != null && bottom != null && right > left && bottom > top) {
                        currentSourceRect = Rect(left, top, right, bottom)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val builder = PictureInPictureParams.Builder()
                            .setAutoEnterEnabled(isPipAllowed)
                            .setAspectRatio(Rational(width, height))

                        currentSourceRect?.let {
                            builder.setSourceRectHint(it)
                        }

                        setPictureInPictureParams(builder.build())
                    }
                    result.success(null)
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

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isPipAllowed && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            val builder = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(currentAspectRatioWidth, currentAspectRatioHeight))
            currentSourceRect?.let {
                builder.setSourceRectHint(it)
            }
            enterPictureInPictureMode(builder.build())
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: android.content.res.Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
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
