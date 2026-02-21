package com.example.hume

import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.hume/fullscreen"

    private var windowInsetsController: WindowInsetsControllerCompat? = null
    private var _isFullscreen = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableEdgeToEdge" -> {
                    enableEdgeToEdge()
                    result.success(null)
                }
                "enterFullscreen" -> {
                    enterFullscreen()
                    result.success(null)
                }
                "exitFullscreen" -> {
                    exitFullscreen()
                    result.success(null)
                }
                "toggleFullscreen" -> {
                    toggleFullscreen()
                    result.success(null)
                }
                "isFullscreen" -> {
                    val isFullscreen = isFullscreen()
                    result.success(isFullscreen)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Enable edge-to-edge mode for modern Android devices.
     * Content draws behind system bars while keeping them visible.
     * This is the recommended approach for Android 14+.
     */
    private fun enableEdgeToEdge() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    /**
     * Enter fullscreen mode by hiding system bars.
     * Uses the new Android 14 API with WindowInsetsControllerCompat.
     * User can swipe from edges to temporarily reveal bars.
     */
    private fun enterFullscreen() {
        windowInsetsController = WindowCompat.getInsetsController(
            window,
            window.decorView
        ).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
        _isFullscreen = true
    }

    private fun exitFullscreen() {
        windowInsetsController = WindowCompat.getInsetsController(
            window,
            window.decorView
        ).apply {
            show(WindowInsetsCompat.Type.systemBars())
        }
        _isFullscreen = false
    }

    private fun toggleFullscreen() {
        if (isFullscreen()) {
            exitFullscreen()
        } else {
            enterFullscreen()
        }
    }

    private fun isFullscreen(): Boolean = _isFullscreen
}
