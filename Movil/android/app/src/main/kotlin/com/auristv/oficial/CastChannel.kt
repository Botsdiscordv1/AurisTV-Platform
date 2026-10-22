package com.auristv.oficial

import android.net.Uri
import android.util.Log
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.FragmentActivity
import androidx.mediarouter.app.MediaRouteButton
import androidx.mediarouter.media.MediaRouteSelector
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaSeekOptions
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.common.images.WebImage
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastState
import com.google.android.gms.cast.framework.CastStateListener
import com.google.android.gms.cast.framework.Session
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Canal de plataforma NATIVO para Google Cast (Chromecast).
 *
 * Nativo real: usa el Google Cast Android SDK (play-services-cast-framework)
 * con su diálogo oficial de selección de dispositivos (MediaRouteButton) y el
 * RemoteMediaClient del receptor conectado.
 *
 * MethodChannel  "auristv/cast"         (comandos desde Dart)
 * EventChannel   "auristv/castEvents"   (eventos hacia Dart)
 *
 * Eventos:
 *   availability {available} — hay (o no) Chromecasts en la red
 *   sessionStarted {deviceId, deviceName}
 *   mediaStatus {loaded, positionMs, durationMs, isPlaying, buffering, idle}
 *   sessionEnded {positionMs, durationMs} — la app local debe retomar aquí
 *   error {message}
 *
 * NOTA: el host DEBE ser un FlutterFragmentActivity: el MediaRouteButton
 * necesita getSupportFragmentManager() para abrir el diálogo nativo de Google.
 *
 * APIs verificadas contra play-services-cast-framework 22.3.1 (javap):
 *   - CastSession vive en cast.framework (no en cast)
 *   - WebImage vive en com.google.android.gms.common.images
 *   - CastMediaControlIntent.categoryForCast (categoryCast ya no existe)
 *   - SessionProvider ya no es genérica; OptionsProvider en cast.framework
 */
object CastChannel {
    const val TAG = "AurisCast"
    const val CHANNEL = "auristv/cast"
    const val EVENTS_CHANNEL = "auristv/castEvents"

    private var impl: CastChannelImpl? = null

    /** Llamar UNA vez desde MainActivity.configureFlutterEngine. */
    fun attach(activity: FragmentActivity, messenger: BinaryMessenger) {
        if (impl == null) {
            impl = CastChannelImpl(activity, messenger)
        }
    }
}

class CastChannelImpl(
    private val activity: FragmentActivity,
    messenger: BinaryMessenger
) : SessionManagerListener<Session> {

    private val methodChannel = MethodChannel(messenger, CastChannel.CHANNEL)
    private val eventChannel = EventChannel(messenger, CastChannel.EVENTS_CHANNEL)

    private var sink: EventChannel.EventSink? = null
    private var castContext: CastContext? = null
    private var sessionManagerAdded = false
    private var remoteClient: RemoteMediaClient? = null
    private var routeButton: MediaRouteButton? = null

    /// Última posición/duración conocidas del receptor (para sessionEnded).
    private var lastRemotePositionMs = 0L
    private var lastRemoteDurationMs = 0L
    private var lastMediaStatus: Map<String, Any?> = mapOf("loaded" to false)

    // ------------------------------------------------------------------
    // Listeners del SDK
    // ------------------------------------------------------------------

    private val castStateListener = CastStateListener { state ->
        emit("availability", mapOf("available" to (state != CastState.NO_DEVICES_AVAILABLE)))
    }

    /** Actualizaciones cada ~1s del receptor (timeline remoto). */
    private val progressListener = RemoteMediaClient.ProgressListener { positionMs, durationMs ->
        lastRemotePositionMs = positionMs
        // El SDK reporta DURATION_UNKNOWN (-1) hasta que el receptor conoce la
        // longitud real (HLS al iniciar). No propagar el -1: rompe clamp del UI.
        if (durationMs > 0) lastRemoteDurationMs = durationMs
        emitMediaStatus()
    }

    /** Cambios de estado (play/pause/buffering/carga). */
    private val mediaListener = object : RemoteMediaClient.Listener {
        override fun onStatusUpdated() { emitMediaStatus() }
        override fun onMetadataUpdated() {}
        override fun onQueueStatusUpdated() {}
        override fun onPreloadStatusUpdated() {}
        override fun onSendingRemoteMediaRequest() { emitMediaStatus() }
        override fun onAdBreakStatusUpdated() {}
    }

    init {
        methodChannel.setMethodCallHandler { call, result -> handleMethod(call, result) }
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                sink = events
            }
            override fun onCancel(args: Any?) {
                sink = null
            }
        })
    }

    // ------------------------------------------------------------------
    // MethodChannel
    // ------------------------------------------------------------------

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "init" -> init(result)
                "isAvailable" -> result.success(castContext != null)
                "showDeviceChooser" -> showDeviceChooser(result)
                "loadMedia" -> loadMedia(call, result)
                "play" -> withClient(result) { it.play() }
                "pause" -> withClient(result) { it.pause() }
                "seek" -> withClient(result) {
                    val ms = (call.argument<Number>("ms")).let { n ->
                        if (n != null) n.toLong() else 0L
                    }
                    it.seek(MediaSeekOptions.Builder().setPosition(ms).build())
                }
                "setVolume" -> withVolume(call, result)
                "stopCasting" -> stopCasting(result)
                "getMediaStatus" -> result.success(lastMediaStatus)
                else -> result.notImplemented()
            }
        } catch (t: Throwable) {
            Log.e(CastChannel.TAG, "handleMethod ${call.method} failed", t)
            result.error("CAST_ERROR", t.message, null)
        }
    }

    private fun init(result: MethodChannel.Result) {
        try {
            if (castContext == null) {
                castContext = CastContext.getSharedInstance(activity.applicationContext)
            }
            val ctx = castContext
            if (ctx == null) {
                Log.w(CastChannel.TAG, "CastContext no disponible (¿sin Google Play Services?)")
                result.success(false)
                return
            }
            if (!sessionManagerAdded) {
                ctx.sessionManager.addSessionManagerListener(this)
                sessionManagerAdded = true
            }
            ctx.addCastStateListener(castStateListener)
            emit(
                "availability",
                mapOf("available" to (ctx.castState != CastState.NO_DEVICES_AVAILABLE))
            )
            result.success(true)
        } catch (t: Throwable) {
            Log.w(CastChannel.TAG, "Cast no disponible en este dispositivo: ${t.message}")
            result.success(false)
        }
    }

    /**
     * Abre el DIÁLOGO NATIVO de Google Cast (igual que YouTube/Netflix).
     * Se usa un MediaRouteButton real añadido a la decor view (tamaño 0):
     * no tiene UI propia, solo sirve para lanzar el chooser del SDK.
     */
    private fun showDeviceChooser(result: MethodChannel.Result) {
        val ctx = castContext
        if (ctx == null) {
            result.success(false)
            return
        }
        try {
            val decor = activity.window.decorView as? ViewGroup
            if (decor == null) {
                result.success(false)
                return
            }
            val button = routeButton
            if (button == null) {
                val b = MediaRouteButton(activity)
                b.visibility = View.VISIBLE
                b.setRouteSelector(
                    MediaRouteSelector.Builder()
                        .addControlCategory(
                            CastMediaControlIntent.categoryForCast(CastOptionsProvider.RECEIVER_APP_ID)
                        )
                        .build()
                )
                decor.addView(b, ViewGroup.LayoutParams(0, 0))
                routeButton = b
            }
            // showDialog() exige que la vista esté attachada (gestiona su
            // FragmentManager en onAttachedToWindow), por eso el post.
            decor.post {
                try {
                    routeButton?.showDialog()
                    result.success(true)
                } catch (t: Throwable) {
                    Log.e(CastChannel.TAG, "showDialog failed", t)
                    result.success(false)
                }
            }
        } catch (t: Throwable) {
            Log.e(CastChannel.TAG, "showDeviceChooser failed", t)
            result.success(false)
        }
    }

    private fun loadMedia(call: MethodCall, result: MethodChannel.Result) {
        val session = castContext?.sessionManager?.getCurrentCastSession()
        val client = session?.remoteMediaClient
        if (session == null || client == null) {
            result.error("NO_CAST_SESSION", "No hay sesión de Cast activa", null)
            return
        }
        val url = call.argument<String>("url")
        if (url.isNullOrEmpty()) {
            result.error("NO_URL", "URL vacía", null)
            return
        }

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
        call.argument<String>("title")?.let { metadata.putString(MediaMetadata.KEY_TITLE, it) }
        call.argument<String>("subtitle")?.let {
            metadata.putString(MediaMetadata.KEY_SUBTITLE, it)
        }
        call.argument<String>("imageUrl")?.let { image ->
            try {
                metadata.addImage(WebImage(Uri.parse(image)))
            } catch (t: Throwable) {
                Log.w(CastChannel.TAG, "imageUrl inválida: ${t.message}")
            }
        }

        val info = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(contentTypeFor(url))
            .setMetadata(metadata)
            .build()

        val startMs = (call.argument<Number>("startMs"))?.toLong() ?: 0L
        val request = MediaLoadRequestData.Builder()
            .setMediaInfo(info)
            .setCurrentTime(startMs)
            .setAutoplay(true)
            .build()

        result.success(true)
        client.load(request).setResultCallback { r ->
            if (r != null && !r.status.isSuccess) {
                Log.w(CastChannel.TAG, "load falló: ${r.status.statusMessage}")
                emit(
                    "error",
                    mapOf("message" to ("No se pudo iniciar la transmisión: ${r.status.statusMessage}"))
                )
            }
        }
    }

    /** Ejecuta una llamada que exige RemoteMediaClient (play/pause/seek). */
    private inline fun withClient(
        result: MethodChannel.Result,
        block: (RemoteMediaClient) -> Unit
    ) {
        val client = castContext?.sessionManager?.getCurrentCastSession()?.remoteMediaClient
        if (client == null) {
            result.error("NO_CAST_SESSION", "No hay sesión de Cast activa", null)
            return
        }
        block(client)
        result.success(true)
    }

    /** Volumen del receptor con CastSession.setVolume (0.0 — 1.0). */
    private fun withVolume(call: MethodCall, result: MethodChannel.Result) {
        val session: CastSession? =
            castContext?.sessionManager?.getCurrentCastSession()
        if (session == null) {
            result.error("NO_CAST_SESSION", "No hay sesión de Cast activa", null)
            return
        }
        val volume = call.argument<Number>("volume")?.toDouble() ?: 1.0
        session.setVolume(volume.coerceIn(0.0, 1.0))
        result.success(true)
    }

    /** Detiene la reproducción y desconecta la sesión (trigger de handback). */
    private fun stopCasting(result: MethodChannel.Result) {
        try {
            val manager = castContext?.sessionManager
            val session = manager?.getCurrentCastSession()
            if (session == null) {
                result.success(false)
                return
            }
            session.remoteMediaClient?.stop()
            manager.endCurrentSession(true)
            result.success(true)
        } catch (t: Throwable) {
            Log.e(CastChannel.TAG, "stopCasting failed", t)
            result.success(false)
        }
    }

    // ------------------------------------------------------------------
    // SessionManagerListener
    // ------------------------------------------------------------------

    override fun onSessionStarting(session: Session) {}

    override fun onSessionStarted(session: Session, sessionId: String) {
        attachClient(session)
        emit(
            "sessionStarted",
            mapOf(
                "deviceId" to session.getSessionId(),
                "deviceName" to
                    ((session as? CastSession)?.getCastDevice()?.friendlyName ?: "Chromecast"),
            )
        )
    }

    override fun onSessionStartFailed(session: Session, error: Int) {
        emit("error", mapOf("message" to "No se pudo conectar al Chromecast (código $error)"))
    }
    override fun onSessionSuspended(session: Session, reason: Int) {}

    override fun onSessionResuming(session: Session, sessionId: String) {
        attachClient(session)
    }

    override fun onSessionResumed(session: Session, wasResumeAll: Boolean) {
        attachClient(session)
    }

    override fun onSessionResumeFailed(session: Session, error: Int) {
        detachClient()
    }

    override fun onSessionEnding(session: Session) {}

    override fun onSessionEnded(session: Session, error: Int) {
        val castSession = session as? CastSession
        val rawPos = castSession?.remoteMediaClient?.getApproximateStreamPosition()
        val rawDur = castSession?.remoteMediaClient?.getStreamDuration()
        val pos = (rawPos ?: lastRemotePositionMs).coerceAtLeast(0)
        // DURATION_UNKNOWN (-1) del SDK: conservar la última duración conocida.
        val dur = if ((rawDur ?: -1L) > 0) rawDur else lastRemoteDurationMs
        detachClient()
        // La app local debe retomar la reproducción en esta posición.
        emit("sessionEnded", mapOf("positionMs" to pos, "durationMs" to dur))
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private fun attachClient(session: Session) {
        detachClient()
        (session as? CastSession)?.remoteMediaClient?.let { client ->
            remoteClient = client
            client.addListener(mediaListener)
            client.addProgressListener(progressListener, 1000)
        }
    }

    private fun detachClient() {
        remoteClient?.let {
            try {
                it.removeListener(mediaListener)
                it.removeProgressListener(progressListener)
            } catch (_: Exception) {}
        }
        remoteClient = null
    }

    private fun emitMediaStatus() {
        val client = remoteClient ?: return
        val status = client.mediaStatus
        val data = HashMap<String, Any?>()
        val state = status?.playerState
        val approxPos = client.getApproximateStreamPosition()
        lastRemotePositionMs = if (approxPos > 0) approxPos else lastRemotePositionMs
        val streamDur = client.getStreamDuration()
        // Duración desconocida (-1) durante el arranque del stream: se conserva
        // la última válida para que el timeline no reciba valores inválidos.
        if (streamDur > 0) lastRemoteDurationMs = streamDur
        data["loaded"] = status != null
        data["positionMs"] = lastRemotePositionMs
        data["durationMs"] = lastRemoteDurationMs
        data["isPlaying"] = state == MediaStatus.PLAYER_STATE_PLAYING
        data["buffering"] =
            state == MediaStatus.PLAYER_STATE_BUFFERING || state == MediaStatus.PLAYER_STATE_LOADING
        data["idle"] = state == MediaStatus.PLAYER_STATE_IDLE
        lastMediaStatus = data
        emit("mediaStatus", data)
    }

    /** MIME del stream para el Default Media Receiver (HLS/DASH/MP4). */
    private fun contentTypeFor(url: String): String = when {
        url.contains(".m3u8") -> "application/x-mpegurl"
        url.contains(".mpd") -> "application/dash+xml"
        url.contains(".mp4") -> "video/mp4"
        else -> "application/x-mpegurl"
    }

    private fun emit(event: String, args: Map<String, Any?> = emptyMap()) {
        val payload = HashMap<String, Any?>(args)
        payload["event"] = event
        activity.runOnUiThread {
            try {
                sink?.success(payload)
            } catch (_: Exception) {}
        }
    }
}
