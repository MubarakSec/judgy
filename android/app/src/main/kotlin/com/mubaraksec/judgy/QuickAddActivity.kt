package com.mubaraksec.judgy

import android.widget.Toast
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class QuickAddActivity : FlutterFragmentActivity() {
    override fun getDartEntrypointFunctionName() = "quickAddMain"

    override fun getBackgroundMode() = FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "judgy/quick_add_overlay")
            .setMethodCallHandler { call, result ->
                if (call.method == "finish") {
                    val message = call.arguments as? String
                    if (message != null) Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
                    finish()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
