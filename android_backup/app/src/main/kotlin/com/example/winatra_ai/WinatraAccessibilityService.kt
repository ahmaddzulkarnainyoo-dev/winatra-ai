package com.example.winatra_ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class WinatraAccessibilityService : AccessibilityService() {
    companion object {
        const val TAG = "WinatraAccessibilityService"
        const val ACTION_TEXT_UPDATED = "com.example.winatra_ai.ACCESSIBILITY_TEXT"
        const val EXTRA_TEXT = "text"

        @Volatile
        var lastAccessibilityText: String = ""

        @Volatile
        var isListening: Boolean = true
    }

    private var lastVolumeUpTime = 0L
    private val doublePressDelay = 700L

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_SPOKEN
            notificationTimeout = 100
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        }
        serviceInfo = info
        Log.d(TAG, "Service connected, listening for accessibility events")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isListening || event == null) return

        val eventType = event.eventType
        if (eventType == AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED ||
            eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val eventText = extractEventText(event)
            val screenText = if (eventText.isNotBlank()) eventText else extractTextFromRoot(rootInActiveWindow)
            if (screenText.isNotBlank() && screenText != lastAccessibilityText) {
                lastAccessibilityText = screenText
                sendTextEvent(screenText)
            }
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP && event.action == KeyEvent.ACTION_DOWN) {
            val now = System.currentTimeMillis()
            if (now - lastVolumeUpTime < doublePressDelay) {
                lastVolumeUpTime = 0L
                triggerRead()
                return true
            }
            lastVolumeUpTime = now
        }
        return super.onKeyEvent(event)
    }

    private fun extractEventText(event: AccessibilityEvent): String {
        val rawText = event.text?.joinToString(" ") { it?.toString().orEmpty() }?.trim().orEmpty()
        if (rawText.isNotBlank()) return rawText
        return event.contentDescription?.toString()?.trim().orEmpty()
    }

    private fun extractTextFromRoot(node: AccessibilityNodeInfo?): String {
        if (node == null) return ""
        val builder = StringBuilder()
        node.text?.toString()?.trim()?.let {
            if (it.isNotBlank()) builder.append(it).append(" ")
        }
        node.contentDescription?.toString()?.trim()?.let {
            if (it.isNotBlank()) builder.append(it).append(" ")
        }
        for (i in 0 until node.childCount) {
            builder.append(extractTextFromRoot(node.getChild(i))).append(" ")
        }
        return builder.toString().replace("\\s+".toRegex(), " ").trim()
    }

    private fun sendTextEvent(text: String) {
        val intent = Intent(ACTION_TEXT_UPDATED).apply {
            putExtra(EXTRA_TEXT, text)
        }
        sendBroadcast(intent)
        Log.d(TAG, "Broadcast accessibility text: ${text.take(120)}")
    }

    private fun triggerRead() {
        val text = if (lastAccessibilityText.isNotBlank()) {
            lastAccessibilityText
        } else {
            extractTextFromRoot(rootInActiveWindow)
        }

        if (text.isBlank()) {
            Log.d(TAG, "Tidak ada teks yang dapat dibaca saat trigger volume")
            return
        }

        sendTextEvent(text)
        sendTextForAI(text)
    }

    private fun sendTextForAI(text: String) {
        try {
            val intent = Intent(this, WinatraService::class.java).apply {
                action = WinatraService.ACTION_ACCESSIBILITY_RESULT
                putExtra("accessibility_text", text)
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Gagal mengirim teks ke WinatraService", e)
        }
    }
}
