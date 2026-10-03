package com.example.sterymed_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity): the device unlock prompt of
// local_auth is a fragment-based BiometricPrompt and needs it.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Hides the app's content in the recent-apps switcher (and blocks
        // screenshots) on shared clinic devices. Dart turns it on/off.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "steriymed/privacy"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.arguments as? Boolean ?: true
                    runOnUiThread {
                        if (secure) {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
