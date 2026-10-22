package com.auristv.oficial.tv

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val INSTALL_CHANNEL = "auristv/install"
    private val WATCH_NEXT_CHANNEL = "auristv/watchnext"
    private val SYSTEM_CHANNEL = "auristv/system"

    private var watchNextChannel: MethodChannel? = null
    private var pendingWatchNextRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "auris/tv-video-surface",
            TvVideoSurfaceFactory(flutterEngine.dartExecutor.binaryMessenger),
        )

        // Watch Next: publica "Continuar Viendo" en el launcher de Android/Google TV.
        pendingWatchNextRoute = extractWatchNextRoute(intent)
        watchNextChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WATCH_NEXT_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialRoute" -> {
                        result.success(pendingWatchNextRoute)
                        pendingWatchNextRoute = null
                    }
                    "sync" -> {
                        try {
                            WatchNextHelper.sync(this@MainActivity, toEntries(call.arguments))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WATCH_NEXT_SYNC", e.message, null)
                        }
                    }
                    "clear" -> {
                        try {
                            WatchNextHelper.clear(this@MainActivity)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WATCH_NEXT_CLEAR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCastService" -> {
                    try {
                        val intent = Intent(this@MainActivity, LocalCastForegroundService::class.java).apply {
                            action = LocalCastForegroundService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            this@MainActivity.startForegroundService(intent)
                        } else {
                            this@MainActivity.startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_FAILED", e.message, null)
                    }
                }
                "wakeUp" -> {
                    try {
                        val route = call.argument<String>("route")
                        wakeUpAndBringToFront(route)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKE_UP_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun wakeUpAndBringToFront(route: String? = null) {
        this@MainActivity.runOnUiThread {
            try {
                val act = this@MainActivity
                val context = act.applicationContext

                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    if (!route.isNullOrEmpty()) {
                        data = android.net.Uri.parse("auristv://watchnext?route=${android.net.Uri.encode(route)}")
                    }
                    setPackage(context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    act.setShowWhenLocked(true)
                    act.setTurnScreenOn(true)
                } else {
                    @Suppress("DEPRECATION")
                    act.window?.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                    )
                }

                context.startActivity(intent)

            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error waking up TV: ${e.message}")
            }
        }
    }

    private fun triggerFullScreenNotification(context: Context, pendingIntent: PendingIntent) {
        try {
            val channelId = "auristv_cast_wakeup"
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "AurisTV Cast",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Canal para despertar la TV al recibir Cast"
                    setBypassDnd(true)
                }
                nm.createNotificationChannel(channel)
            }

            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Reproduciendo Cast...")
                .setContentText("AurisTV")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)

            nm.notify(9999, builder.build())

            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                nm.cancel(9999)
            }, 2000)
        } catch (_: Exception) {}
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = extractWatchNextRoute(intent) ?: return
        val channel = watchNextChannel
        if (channel != null) {
            channel.invokeMethod("onDeepLink", route)
        } else {
            pendingWatchNextRoute = route
        }
    }

    /**
     * Extrae la ruta interna del deep link de Watch Next.
     *
     * Admite dos formas:
     *  - `auristv://watchnext?route=...` (el launcher parsea la sintaxis `intent:`).
     *  - `intent://watchnext?route=...#Intent;...;end` (el launcher NO parsea y
     *    entrega el URI crudo; se toma la query antes del fragmento).
     */
    private fun extractWatchNextRoute(intent: Intent?): String? {
        val data = intent?.data ?: return null
        val scheme = data.scheme?.lowercase()
        if (scheme != "auristv" && scheme != "intent") return null
        if (!"watchnext".equals(data.host, ignoreCase = true)) return null
        return data.getQueryParameter("route")?.takeIf { it.isNotEmpty() }
    }

    private fun toEntries(arguments: Any?): List<Map<String, Any?>> {
        val raw = arguments as? List<*> ?: return emptyList()
        return raw.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            map.entries.associate { (key, value) -> key.toString() to value }
        }
    }

    private fun canRequestInstall(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }
}
