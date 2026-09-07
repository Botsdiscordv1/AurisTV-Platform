package com.auristv.oficial

import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val BRIGHTNESS_CHANNEL = "auristv/brightness"
    private val VOLUME_CHANNEL = "auristv/volume"
    private var interceptVolume = false

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setIntercept") {
                interceptVolume = call.argument<Boolean>("enabled") ?: false
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (interceptVolume && (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)) {
            // Senior Fix: Consumimos el evento para que Android no muestre su UI de volumen,
            // pero el plugin 'volume_controller' en Flutter seguirá detectando el cambio.
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
}
