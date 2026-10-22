package com.auristv.oficial

import android.content.Context
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.lang.reflect.Method

/**
 * Prototipo de superficie nativa (SurfaceView) para el player de Móvil.
 *
 * Replica el mecanismo de TV: mpv pinta directo sobre la Surface
 * (`vo=mediacodec_embed`) en vez de usar la textura de Flutter
 * (`vo=gpu` + android.view.SurfaceTexture). El reinit de `vo=gpu` al conocer
 * los parámetros del stream está provocando el salto inicial de 0:05-0:20.
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
) : PlatformView {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val surfaceView = SurfaceView(context)
    private var wid: Long = 0L

    private var fixedWidth = 0
    private var fixedHeight = 0

    private val callback = object : SurfaceHolder.Callback {
        override fun surfaceCreated(holder: SurfaceHolder) {
            Log.i(TAG, "surfaceCreated")
            applyFixedSize()
        }

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            val surface = holder.surface ?: return
            if (wid == 0L) {
                wid = newGlobalObjectRef(surface)
            }
            Log.i(TAG, "surfaceChanged wid=$wid size=${width}x$height")
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

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            Log.i(TAG, "surfaceDestroyed")
            channel.invokeMethod("onSurfaceDestroyed", mapOf("viewId" to viewId))
            if (wid != 0L) {
                deleteGlobalObjectRef(wid)
                wid = 0L
            }
        }
    }

    init {
        surfaceView.holder.addCallback(callback)
        surfaceView.holder.setFormat(android.graphics.PixelFormat.OPAQUE)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setVideoSize" -> {
                    val w = call.argument<Int>("width") ?: 0
                    val h = call.argument<Int>("height") ?: 0
                    if (w > 0 && h > 0) {
                        fixedWidth = w
                        fixedHeight = h
                        applyFixedSize()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun applyFixedSize() {
        if (fixedWidth <= 0 || fixedHeight <= 0) return
        try {
            surfaceView.holder.setFixedSize(fixedWidth, fixedHeight)
        } catch (t: Throwable) {
            Log.e(TAG, "setFixedSize", t)
        }
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        try {
            surfaceView.holder.removeCallback(callback)
        } catch (t: Throwable) {
            Log.e(TAG, "dispose", t)
        }
        if (wid != 0L) {
            deleteGlobalObjectRef(wid)
            wid = 0L
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
