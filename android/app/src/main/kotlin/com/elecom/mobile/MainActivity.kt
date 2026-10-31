package com.elecom.mobile

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.elecom.mobile/device_info")
            .setMethodCallHandler { call, result ->
                if (call.method == "deviceName") {
                    result.success("${Build.MANUFACTURER} ${Build.MODEL}".trim())
                } else {
                    result.notImplemented()
                }
            }
    }
}
