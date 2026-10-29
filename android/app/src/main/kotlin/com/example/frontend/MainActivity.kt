package com.example.frontend

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "orvo/voice_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    OrvoVoiceBridge.sink = events
                    if (OrvoVoiceBridge.engineConnected) OrvoVoiceBridge.emit("ready")
                }
                override fun onCancel(arguments: Any?) { OrvoVoiceBridge.sink = null }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orvo/voice_control")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        OrvoVoiceBridge.enabled = call.argument<Boolean>("enabled") ?: false
                        OrvoVoiceBridge.onEnabledChanged?.invoke(OrvoVoiceBridge.enabled)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        OrvoVoiceBridge.sink = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

/** Connect your local wake-word/ASR engine here. No microphone is opened here. */
object OrvoVoiceBridge {
    internal var sink: EventChannel.EventSink? = null
    @Volatile var enabled = true
    @Volatile var engineConnected = false
        private set
    var onEnabledChanged: ((Boolean) -> Unit)? = null
    private val main = Handler(Looper.getMainLooper())
    fun engineReady() { engineConnected = true; emit("ready") }
    fun emit(type: String, text: String = "") {
        if (!enabled && type != "ready") return
        main.post {
            if (enabled || type == "ready") sink?.success(mapOf("type" to type, "text" to text))
        }
    }
}
