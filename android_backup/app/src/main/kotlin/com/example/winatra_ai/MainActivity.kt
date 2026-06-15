package com.example.winatra_ai

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "winatra/service"
    private val CLIPBOARD_CHANNEL = "winatra/clipboard"
    private val LIMIT_CHANNEL = "winatra/limit"   // channel untuk limit harian
    private val ACCESSIBILITY_CHANNEL = "winatra_accessibility"
    private val ACCESSIBILITY_EVENTS_CHANNEL = "winatra_accessibility_events"
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001

    private var accessibilityEventSink: EventChannel.EventSink? = null
    private var accessibilityTextReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermission()
        // Hanya auto-start jika toggle notifikasi ON (baca dari Flutter SharedPreferences)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val notifEnabled = flutterPrefs.getBoolean("flutter.notif_enabled", true)
        if (notifEnabled) {
            startWinatraService()
        }
        requestBatteryOptimizationExemption()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
                )
            }
        }
    }

    private fun startWinatraService() {
        val intent = Intent(this, WinatraService::class.java)
        startForegroundService(intent)
    }

    private fun stopWinatraService() {
        stopService(Intent(this, WinatraService::class.java))
        val manager = getSystemService(android.app.NotificationManager::class.java)
        manager.cancel(WinatraService.NOTIF_ID)
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel untuk service control (notifikasi, mode, dll)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMode" -> {
                    val prefs = getSharedPreferences(WinatraService.PREFS_NAME, MODE_PRIVATE)
                    result.success(prefs.getString(WinatraService.KEY_MODE, "Essay"))
                }
                "setAutoSolve" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val prefs = getSharedPreferences(WinatraService.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit().putBoolean("auto_solve", enabled).apply()
                    val intent = Intent(this, WinatraService::class.java).apply {
                        action = "SET_AUTO_SOLVE"
                        putExtra("enabled", enabled)
                    }
                    startService(intent)
                    result.success(null)
                }
                "syncMode" -> {
                    val mode = call.argument<String>("mode") ?: "Essay"
                    val prefs = getSharedPreferences(WinatraService.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit().putString(WinatraService.KEY_MODE, mode).apply()
                    val intent = Intent(this, WinatraService::class.java).apply {
                        action = "SYNC_MODE"
                        putExtra("mode", mode)
                    }
                    startService(intent)
                    result.success(null)
                }
                "startService" -> {
                    startWinatraService()
                    result.success(null)
                }
                "stopService" -> {
                    stopWinatraService()
                    result.success(null)
                }
                "cancelNotification" -> {
                    val manager = getSystemService(android.app.NotificationManager::class.java)
                    manager.cancel(WinatraService.NOTIF_ID)
                    result.success(null)
                }
                "openKeyboardSettings" -> {
                    val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "getAndroidId" -> {
                    val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    result.success(androidId)
                }
                else -> result.notImplemented()
            }
        }

        // Channel untuk clipboard access (fallback)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getClipboard" -> {
                    try {
                        val clipboard = getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                        val clip = clipboard.primaryClip
                        val text = if (clip != null && clip.itemCount > 0) {
                            clip.getItemAt(0).text?.toString()?.trim() ?: ""
                        } else {
                            ""
                        }
                        Log.d("MainActivity", "Clipboard accessed via Flutter channel: ${text.take(50)}")
                        result.success(text)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to get clipboard: ${e.message}")
                        result.error("CLIPBOARD_ERROR", e.message, null)
                    }
                }
                "sendToService" -> {
                    try {
                        val question = call.argument<String>("question") ?: ""
                        Log.d("MainActivity", "Sending clipboard result to service via Flutter: ${question.take(50)}")
                        val intent = Intent(this, WinatraService::class.java).apply {
                            action = WinatraService.ACTION_CLIPBOARD_RESULT
                            putExtra(ClipboardActivity.EXTRA_QUESTION, question)
                        }
                        startService(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to send to service: ${e.message}")
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Channel untuk limit harian (15 permintaan / hari + premium)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIMIT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkLimit" -> {
                    result.notImplemented()
                }
                "incrementCount" -> {
                    result.notImplemented()
                }
                else -> result.notImplemented()
            }
        }

        // Accessibility bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSelectedText" -> {
                    result.success(WinatraAccessibilityService.lastAccessibilityText)
                }
                "getScreenText" -> {
                    result.success(WinatraAccessibilityService.lastAccessibilityText)
                }
                "startListening" -> {
                    WinatraAccessibilityService.isListening = true
                    result.success(null)
                }
                "stopListening" -> {
                    WinatraAccessibilityService.isListening = false
                    result.success(null)
                }
                "isAccessibilityServiceEnabled" -> {
                    val enabled = try {
                        val accessibilityEnabled = Settings.Secure.getInt(contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0)
                        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
                        accessibilityEnabled == 1 && enabledServices.contains("${packageName}/.WinatraAccessibilityService", ignoreCase = true)
                    } catch (e: Exception) {
                        false
                    }
                    result.success(enabled)
                }
                "processAccessibilityText" -> {
                    val text = call.argument<String>("text") ?: ""
                    if (text.isNotBlank()) {
                        val intent = Intent(this, WinatraService::class.java).apply {
                            action = WinatraService.ACTION_ACCESSIBILITY_RESULT
                            putExtra("accessibility_text", text)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                    }
                    result.success(null)
                }
                "requestAccessibilityPermission" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_EVENTS_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                accessibilityEventSink = events
                if (accessibilityTextReceiver == null) {
                    accessibilityTextReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            val text = intent?.getStringExtra(WinatraAccessibilityService.EXTRA_TEXT) ?: ""
                            if (text.isNotBlank()) {
                                accessibilityEventSink?.success(text)
                            }
                        }
                    }
                    registerReceiver(accessibilityTextReceiver, IntentFilter(WinatraAccessibilityService.ACTION_TEXT_UPDATED))
                }
            }

            override fun onCancel(arguments: Any?) {
                accessibilityEventSink = null
                if (accessibilityTextReceiver != null) {
                    unregisterReceiver(accessibilityTextReceiver)
                    accessibilityTextReceiver = null
                }
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        if (accessibilityTextReceiver != null) {
            unregisterReceiver(accessibilityTextReceiver)
            accessibilityTextReceiver = null
        }
    }
}
