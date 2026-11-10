package com.auristv.oficial

import android.content.Context
import android.graphics.SurfaceTexture
import android.util.Log
import android.view.Surface
import android.view.TextureView
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.lang.reflect.Method

/**
 * Superficie nativa (TextureView) para el player de Móvil.
 *
 * Replica el mecanismo de TV: mpv pinta directo sobre la Surface
 * (`vo=mediacodec_embed`) en vez de usar la textura de Flutter
 * (`vo=gpu` + android.view.SurfaceTexture). El reinit de `vo=gpu` al conocer
 * los parámetros del stream está provocando el salto inicial de 0:05-0:20.
 *
 * Se usa TextureView y no SurfaceView a propósito: el motor de Flutter
 * descarta Texture Layer Hybrid Composition para cualquier vista que contenga
 * un SurfaceView (`VIEW_TYPES_REQUIRE_NON_TLHC`) y cae en Hybrid Composition
 * clásico, que convierte la superficie de Flutter en un ImageReader y obliga a
 * copiar todo el UI por frame (controles/gestos/seek lentos). Con TextureView
 * la vista se aloja en el wrapper de TLHC y Flutter conserva su superficie
 * normal, así que la UI vuelve a ir a 60fps.
 *
 * Se activa solo con `--dart-define=NATIVE_VIDEO_SURFACE=true`.
 */
class MobileVideoSurfaceFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return MobileVideoSurfaceView(context, viewId, messenger)
    }
}

class MobileVideoSurfaceView(
    context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
) : PlatformView, TextureView.SurfaceTextureListener {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val textureView = TextureView(context)

    // `Surface` que envuelve el SurfaceTexture de la TextureView: es lo que
    // mpv recibe como `--wid`. Se libera en paralelo a la ref JNI.
    private var surface: Surface? = null
    private var wid: Long = 0L

    // Tamaño del vídeo (lo manda Dart vía `setVideoSize`). Equivale a
    // `SurfaceHolder.setFixedSize`: fija el tamaño del buffer en vez del de
    // la vista.
    private var fixedWidth = 0
    private var fixedHeight = 0

    private var lastWidth = 0
    private var lastHeight = 0

    init {
        // Mismo equivalente que `holder.setFormat(PixelFormat.OPAQUE)`.
        textureView.isOpaque = true
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSurface" -> {
                    val target = call.argument<Int>("viewId")
                    if ((target == null || target == viewId) && wid != 0L) {
                        val (w, h) = bufferSize(textureView.width, textureView.height)
                        if (w > 0 && h > 0) notifySurface(w, h)
                    }
                    result.success(null)
                }
                "setVideoSize" -> {
                    // Varias superficies comparten el canal; solo la que
                    // coincide con viewId aplica el tamaño.
                    val target = call.argument<Int>("viewId")
                    val w = call.argument<Int>("width") ?: 0
                    val h = call.argument<Int>("height") ?: 0
                    if ((target == null || target == viewId) && w > 0 && h > 0) {
                        fixedWidth = w
                        fixedHeight = h
                        applyBufferSize(textureView.width, textureView.height)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // El listener va el último: `onSurfaceTextureAvailable` puede llegar
        // de forma síncrona si la TextureView ya creó su SurfaceTexture.
        textureView.surfaceTextureListener = this
    }

    // ---------------------------------------------------------------------
    // TextureView.SurfaceTextureListener
    // ---------------------------------------------------------------------

    override fun onSurfaceTextureAvailable(
        surfaceTexture: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        val newSurface = Surface(surfaceTexture)
        surface = newSurface
        wid = newGlobalObjectRef(newSurface)
        Log.i(TAG, "onSurfaceTextureAvailable view=$viewId wid=$wid ${width}x$height")
        applyBufferSize(width, height)
    }

    override fun onSurfaceTextureSizeChanged(
        surfaceTexture: SurfaceTexture,
        width: Int,
        height: Int,
    ) {
        Log.i(TAG, "onSurfaceTextureSizeChanged view=$viewId ${width}x$height")
        applyBufferSize(width, height)
    }

    override fun onSurfaceTextureDestroyed(surfaceTexture: SurfaceTexture): Boolean {
        Log.i(TAG, "onSurfaceTextureDestroyed view=$viewId wid=$wid")
        teardown()
        // true: TextureView libera el SurfaceTexture (ya no nos sirve).
        return true
    }

    override fun onSurfaceTextureUpdated(surfaceTexture: SurfaceTexture) = Unit

    // ---------------------------------------------------------------------
    // Protocolo con Dart
    // ---------------------------------------------------------------------

    private fun notifySurface(width: Int, height: Int) {
        if (wid == 0L) return
        lastWidth = width
        lastHeight = height
        channel.invokeMethod(
            "onSurface",
            mapOf(
                "viewId" to viewId,
                "wid" to wid,
                "width" to width,
                "height" to height,
            ),
        )
    }

    /// Tamaño de buffer que debe usar la superficie: el del vídeo si ya se
    /// conoce, si no el de la vista (igual que SurfaceView antes/después de
    /// `setFixedSize`).
    private fun bufferSize(viewW: Int, viewH: Int): Pair<Int, Int> {
        if (fixedWidth > 0 && fixedHeight > 0) return fixedWidth to fixedHeight
        if (viewW > 0 && viewH > 0) return viewW to viewH
        if (lastWidth > 0 && lastHeight > 0) return lastWidth to lastHeight
        return 0 to 0
    }

    private fun applyBufferSize(viewW: Int, viewH: Int) {
        if (wid == 0L) return
        val (w, h) = bufferSize(viewW, viewH)
        if (w <= 0 || h <= 0) return
        try {
            // Equivalente a `SurfaceHolder.setFixedSize(w, h)`.
            textureView.surfaceTexture?.setDefaultBufferSize(w, h)
        } catch (t: Throwable) {
            Log.e(TAG, "setDefaultBufferSize", t)
        }
        if (w != lastWidth || h != lastHeight) {
            notifySurface(w, h)
        }
    }

    /// Desconecta a mpv y libera la ref JNI + la Surface. Idempotente.
    private fun teardown() {
        val currentWid = wid
        if (currentWid != 0L) {
            // Avisar a Dart para que mpv suelte el wid antes de liberar la ref.
            try {
                channel.invokeMethod(
                    "onSurfaceDestroyed",
                    mapOf("viewId" to viewId, "wid" to currentWid),
                )
            } catch (t: Throwable) {
                Log.e(TAG, "teardown notify", t)
            }
            wid = 0L
            deleteGlobalObjectRef(currentWid)
        }
        try {
            surface?.release()
        } catch (t: Throwable) {
            Log.e(TAG, "surface release", t)
        }
        surface = null
        lastWidth = 0
        lastHeight = 0
    }

    override fun getView(): View = textureView

    override fun dispose() {
        try {
            textureView.surfaceTextureListener = null
        } catch (t: Throwable) {
            Log.e(TAG, "dispose listener", t)
        }
        teardown()
        try {
            channel.setMethodCallHandler(null)
        } catch (t: Throwable) {
            Log.e(TAG, "dispose channel", t)
        }
    }

    companion object {
        private const val TAG = "AurisMobileSurface"
        private const val CHANNEL = "auris/mobile_video_surface"

        // Mismo helper nativo que usa media_kit_video en Android.
        private var newGlobalObjectRefMethod: Method? = null
        private var deleteGlobalObjectRefMethod: Method? = null

        init {
            try {
                val cls = Class.forName("com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper")
                newGlobalObjectRefMethod = cls
                    .getDeclaredMethod("newGlobalObjectRef", Object::class.java)
                    .apply { isAccessible = true }
                deleteGlobalObjectRefMethod = cls
                    .getDeclaredMethod("deleteGlobalObjectRef", Long::class.javaPrimitiveType)
                    .apply { isAccessible = true }
            } catch (t: Throwable) {
                Log.e(TAG, "MediaKitAndroidHelper no disponible", t)
            }
        }

        private fun newGlobalObjectRef(obj: Any): Long {
            return try {
                (newGlobalObjectRefMethod?.invoke(null, obj) as? Long) ?: 0L
            } catch (t: Throwable) {
                Log.e(TAG, "newGlobalObjectRef", t)
                0L
            }
        }

        private fun deleteGlobalObjectRef(ref: Long) {
            try {
                deleteGlobalObjectRefMethod?.invoke(null, ref)
            } catch (t: Throwable) {
                Log.e(TAG, "deleteGlobalObjectRef", t)
            }
        }
    }
}
