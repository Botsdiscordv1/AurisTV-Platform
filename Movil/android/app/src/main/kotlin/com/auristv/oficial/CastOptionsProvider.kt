package com.auristv.oficial

import android.content.Context
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider
import com.google.android.gms.cast.framework.media.CastMediaOptions

/**
 * Proveedor de opciones del Google Cast SDK nativo (leído desde el meta-data
 * `OPTIONS_PROVIDER_CLASS_NAME` del AndroidManifest.xml).
 *
 * RECEIVER_APP_ID es el identificador del receptor registrado en la Google Cast
 * SDK Developer Console (https://cast.google.com/publish).
 *
 * "CC1AD845" es el *Default Media Receiver* de Google: funciona SIN registrar
 * la app y soporta HLS (.m3u8), DASH (.mpd) y MP4 progresivo.
 *
 * Para producción conviene registrar un Styled Media Receiver propio y
 * sustituir la constante (los Chromecasts de los usuarios no necesitan Config).
 */
class CastOptionsProvider : OptionsProvider {

    companion object {
        /// Placeholder: Default Media Receiver (sustituir por el App ID propio
        /// registrado en la Google Cast Developer Console para producción).
        const val RECEIVER_APP_ID = "CC1AD845"
    }

    override fun getCastOptions(context: Context): CastOptions {
        // MediaOptions por defecto: habilita notificación/controles de media
        // en pantalla de bloqueo con el Expanded Controller estándar del SDK.
        val mediaOptions = CastMediaOptions.Builder().build()

        return CastOptions.Builder()
            .setReceiverApplicationId(RECEIVER_APP_ID)
            .setCastMediaOptions(mediaOptions)
            .build()
    }

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? = null
}
