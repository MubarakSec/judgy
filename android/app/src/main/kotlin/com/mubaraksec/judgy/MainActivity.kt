package com.mubaraksec.judgy

import android.os.Build
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "judgy/speech")
            .setMethodCallHandler { call, result ->
                if (call.method == "supportsOnDevice") {
                    result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
