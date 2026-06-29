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
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "winatra/service"
    private val ACCESSIBILITY_CHANNEL = "winatra_accessibility"
    private val ACCESSIBILITY_EVENTS_CHANNEL = "winatra_accessibility_events"
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001

    private var accessibilityEventSink: EventChannel.EventSink? = null
    private var accessibilityTextReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestNotificationPermission()
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val notifEnabled = flutterPrefs.getBoolean("flutter.notif_enabled", true)
        if (notifEnabled) {
            startWinatraService()
        }
        requestBatteryOptimizationExemption()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST_CODE)
            }
        }
    }

    private fun startWinatraService() {
        val intent = Intent(this, WinatraService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
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
                "setVoiceCommandEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit().putBoolean("accessibility_voice_command_enabled", enabled).apply()
                    WinatraAccessibilityService.currentService?.voiceCommandEnabled = enabled
                    result.success(null)
                }
                "setProactiveEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit().putBoolean("accessibility_proactive_enabled", enabled).apply()
                    WinatraAccessibilityService.currentService?.proactiveEnabled = enabled
                    result.success(null)
                }
                "testVoiceCommand" -> {
                    WinatraAccessibilityService.currentService?.startVoiceCommandListening()
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

