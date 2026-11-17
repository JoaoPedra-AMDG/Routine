package za.co.joaopedra.daybook

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "za.co.joaopedra.daybook/storage")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("routine", MODE_PRIVATE)
                when (call.method) {
                    "load" -> result.success(prefs.getString("schedule", null))
                    "save" -> {
                        val value = call.arguments as? String
                        if (value == null) result.error("invalid", "Invalid schedule", null)
                        else if (prefs.edit().putString("schedule", value).commit()) result.success(null)
                        else result.error("save_failed", "Could not save schedule", null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
