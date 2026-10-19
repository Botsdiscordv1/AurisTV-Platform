package com.auristv.oficial.tv

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.tvprovider.media.tv.TvContractCompat
import androidx.tvprovider.media.tv.WatchNextProgram

/**
 * Publica el "Continuar Viendo" de la app en el launcher de Android/Google TV
 * mediante la Watch Next API (TvProvider).
 *
 * Cada entrada se inserta/actualiza con una clave estable
 * (`internal_provider_id`) para no duplicar tarjetas entre sincronizaciones.
 * Al pulsar una tarjeta el launcher abre `auristv://watchnext?route=...`, que
 * MainActivity reenvía a Flutter para navegar al contenido.
 */
object WatchNextHelper {
    private const val TAG = "AurisWatchNext"
    private const val PREFS = "auris_watch_next"
    private const val KEY_MAP = "program_ids"
    private const val SCHEME = "auristv"
    private const val HOST = "watchnext"

    fun isAvailable(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

    /** Inserta/actualiza las entradas y elimina las que ya no se muestran. */
    fun sync(context: Context, entries: List<Map<String, Any?>>) {
        if (!isAvailable()) return
        val resolver = context.contentResolver
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = loadMap(prefs)
        val keep = HashSet<String>()

        for (entry in entries) {
            val key = entry.string("key")
            if (key.isEmpty()) continue
            keep.add(key)
            try {
                val values = buildValues(entry, context.packageName)
                val existingId = ids[key] ?: findProgramId(context, key)
                var updated = false
                if (existingId != null && existingId > 0) {
                    val rows = resolver.update(
                        TvContractCompat.buildWatchNextProgramUri(existingId),
                        values, null, null,
                    )
                    updated = rows > 0
                    if (updated) ids[key] = existingId
                }
                if (!updated) {
                    val uri = resolver.insert(
                        TvContractCompat.WatchNextPrograms.CONTENT_URI, values,
                    )
                    val newId = uri?.lastPathSegment?.toLongOrNull()
                    if (newId != null && newId > 0) {
                        ids[key] = newId
                    } else {
                        ids.remove(key)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "sync($key) failed: ${e.message}")
            }
        }

        // Quitar de Watch Next lo que ya no está en Continuar Viendo.
        val iterator = ids.entries.iterator()
        while (iterator.hasNext()) {
            val (key, id) = iterator.next()
            if (keep.contains(key)) continue
            try {
                resolver.delete(TvContractCompat.buildWatchNextProgramUri(id), null, null)
            } catch (e: Exception) {
                Log.w(TAG, "delete($key) failed: ${e.message}")
            }
            iterator.remove()
        }
        saveMap(prefs, ids)
    }

    /** Borra todas las tarjetas publicadas por la app. */
    fun clear(context: Context) {
        if (!isAvailable()) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = loadMap(prefs)
        val resolver = context.contentResolver
        for (id in ids.values) {
            try {
                resolver.delete(TvContractCompat.buildWatchNextProgramUri(id), null, null)
            } catch (e: Exception) {
                Log.w(TAG, "clear($id) failed: ${e.message}")
            }
        }
        prefs.edit().remove(KEY_MAP).apply()
    }

    private fun buildValues(entry: Map<String, Any?>, packageName: String): ContentValues {
        val key = entry.string("key")
        val title = entry.string("title")
        val description = entry.string("description")
        val poster = entry.string("posterUrl")
        val thumbnail = entry.string("thumbnailUrl")
        val logo = entry.string("logoUrl")
        val contentId = entry.string("contentId")
        val route = entry.string("route")
        val isEpisode = entry["isEpisode"] == true
        val duration = entry.long("durationMs").coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()
        val position = entry.long("positionMs").coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()
        val engagement = entry.long("lastEngagement").takeIf { it > 0 } ?: System.currentTimeMillis()

        val builder = WatchNextProgram.Builder()
        builder.setWatchNextType(TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_CONTINUE)
        builder.setType(
            if (isEpisode) {
                TvContractCompat.PreviewProgramColumns.TYPE_TV_EPISODE
            } else {
                TvContractCompat.PreviewProgramColumns.TYPE_MOVIE
            },
        )
        builder.setInternalProviderId(key)
        builder.setLastEngagementTimeUtcMillis(engagement)
        builder.setDurationMillis(duration)
        builder.setLastPlaybackPositionMillis(position)
        if (title.isNotEmpty()) builder.setTitle(title)
        if (description.isNotEmpty()) builder.setDescription(description)
        if (poster.isNotEmpty()) {
            builder.setPosterArtUri(Uri.parse(poster))
            // El banner/backdrop es horizontal: se declara 16:9 para que el
            // launcher no lo recorte como póster vertical.
            builder.setPosterArtAspectRatio(
                TvContractCompat.PreviewProgramColumns.ASPECT_RATIO_16_9,
            )
        }
        if (thumbnail.isNotEmpty()) {
            builder.setThumbnailUri(Uri.parse(thumbnail))
            builder.setThumbnailAspectRatio(
                TvContractCompat.PreviewProgramColumns.ASPECT_RATIO_16_9,
            )
        }
        if (logo.isNotEmpty()) builder.setLogoUri(Uri.parse(logo))
        if (contentId.isNotEmpty()) builder.setSeriesId(contentId)
        if (isEpisode) {
            val season = entry.int("season")
            val episodeNumber = entry.int("episodeNumber")
            if (season > 0) builder.setSeasonNumber(season)
            if (episodeNumber > 0) builder.setEpisodeNumber(episodeNumber)
            val episodeTitle = entry.string("episodeTitle")
            if (episodeTitle.isNotEmpty()) builder.setEpisodeTitle(episodeTitle)
        }
        if (route.isNotEmpty()) {
            // Intent EXPLÍCITO (sintaxis `intent:` con package) para que el
            // launcher abra la app directamente sin el diálogo "Abrir con".
            val intentUri = Uri.parse("intent://$HOST")
                .buildUpon()
                .appendQueryParameter("route", route)
                .fragment(
                    "Intent;scheme=$SCHEME;package=$packageName;" +
                        "launchFlags=0x10000000;end",
                )
                .build()
            builder.setIntentUri(intentUri)
        }
        return builder.build().toContentValues()
    }

    /** Busca el id ya publicado para [key] (recuperación tras reinicio). */
    private fun findProgramId(context: Context, key: String): Long? {
        return try {
            context.contentResolver.query(
                TvContractCompat.WatchNextPrograms.CONTENT_URI,
                arrayOf("_id", "internal_provider_id"),
                "internal_provider_id = ?",
                arrayOf(key),
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getLong(0) else null
            }
        } catch (e: Exception) {
            Log.w(TAG, "findProgramId($key) failed: ${e.message}")
            null
        }
    }

    private fun loadMap(prefs: android.content.SharedPreferences): MutableMap<String, Long> {
        val raw = prefs.getString(KEY_MAP, null) ?: return mutableMapOf()
        val out = mutableMapOf<String, Long>()
        for (pair in raw.split(";")) {
            if (pair.isEmpty()) continue
            val separator = pair.indexOf('=')
            if (separator <= 0) continue
            val key = pair.substring(0, separator)
            val id = pair.substring(separator + 1).toLongOrNull() ?: continue
            out[key] = id
        }
        return out
    }

    private fun saveMap(prefs: android.content.SharedPreferences, map: Map<String, Long>) {
        val raw = map.entries.joinToString(";") { "${it.key}=${it.value}" }
        prefs.edit().putString(KEY_MAP, raw).apply()
    }

    private fun Map<String, Any?>.string(key: String): String =
        (this[key] as? String)?.trim().orEmpty()

    private fun Map<String, Any?>.long(key: String): Long =
        (this[key] as? Number)?.toLong() ?: 0L

    private fun Map<String, Any?>.int(key: String): Int =
        (this[key] as? Number)?.toInt() ?: 0
}
