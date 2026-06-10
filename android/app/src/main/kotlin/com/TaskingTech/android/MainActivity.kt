package com.TaskingTech.android

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stalky/support")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSupportEmail" -> {
                        val email = call.argument<String>("email").orEmpty()
                        val subject = call.argument<String>("subject").orEmpty()
                        val uri = Uri.Builder()
                            .scheme("mailto")
                            .opaquePart(email)
                            .appendQueryParameter("subject", subject)
                            .build()
                        val intent = Intent(Intent.ACTION_SENDTO, uri)

                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (_: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
