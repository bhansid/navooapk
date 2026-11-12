package com.navoo.navoo

import android.app.WallpaperManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "navoo/device").setMethodCallHandler { call, result ->
            if (call.method == "setWallpaper") {
                try {
                    val path = call.argument<String>("path")!!
                    val where = call.argument<Int>("where") ?: 3
                    val wm = WallpaperManager.getInstance(applicationContext)
                    if (Build.VERSION.SDK_INT >= 24) {
                        var flags = 0
                        if (where == 1 || where == 3) flags = flags or WallpaperManager.FLAG_SYSTEM
                        if (where == 2 || where == 3) flags = flags or WallpaperManager.FLAG_LOCK
                        FileInputStream(path).use { wm.setStream(it, null, true, flags) }
                    } else {
                        FileInputStream(path).use { wm.setStream(it) }
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("WALLPAPER", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
