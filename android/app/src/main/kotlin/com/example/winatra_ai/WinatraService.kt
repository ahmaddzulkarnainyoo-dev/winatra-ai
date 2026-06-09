package com.example.winatra_ai

import android.app.*
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WinatraService : Service() {

    companion object {
        const val CHANNEL_ID = "winatra_channel"
        const val RESULT_CHANNEL_ID = "winatra_result_channel"
        const val NOTIF_ID = 1
        const val RESULT_NOTIF_ID = 100
        const val ACTION_ANSWER = "ACTION_ANSWER"
        const val ACTION_CHANGE_MODE = "ACTION_CHANGE_MODE"
        const val ACTION_CLIPBOARD_RESULT = "CLIPBOARD_RESULT"
        const val ACTION_EXPLAIN = "ACTION_EXPLAIN"
        const val ACTION_COPY_ANSWER = "ACTION_COPY_ANSWER"
        const val PREFS_NAME = "winatra_prefs"
        const val KEY_MODE = "mode"
        const val PREF_KEY_API_INDEX = "api_key_index"
        const val PREF_KEY_LAST_QUOTA_RESET = "last_quota_reset"
        const val DEFAULT_DAILY_QUOTA = 7   // diubah dari 15 menjadi 7
        const val TAG = "WinatraService"

        data class ApiEndpoint(val key: String, val baseUrl: String, val type: String)

        // 24 Groq + 1 DeepSeek = 25 total
        private val API_ENDPOINTS = listOf(
            ApiEndpoint("BUILD_GROQ_KEY_1", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_2", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_3", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_4", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_5", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_6", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_7", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_8", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_9", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_10", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_11", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_12", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_13", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_14", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_15", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_16", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_17", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_18", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_19", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_20", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_21", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_22", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_23", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_GROQ_KEY_24", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_DEEPSEEK_KEY", "https://api.deepseek.com/v1", "DeepSeek")
        )
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
        .build()
    private var autoSolveEnabled = false
    private var clipboardListener: ClipboardManager.OnPrimaryClipChangedListener? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate called")
        createNotificationChannels()
        setupClipboardListener()
        showPersistentNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand action=${intent?.action}")
        when (intent?.action) {
            ACTION_CHANGE_MODE -> toggleMode()
            ACTION_CLIPBOARD_RESULT -> {
                if (FirebaseAuth.getInstance().currentUser == null) {
                    showResultNotification("Winatra AI", "Silakan login terlebih dahulu.")
                    return START_STICKY
                }
                val question = intent.getStringExtra(ClipboardActivity.EXTRA_QUESTION) ?: ""
                val modeType = intent.getStringExtra(ClipboardActivity.EXTRA_MODE_TYPE) ?: "answer"
                processClipboardResult(question, modeType)
            }
            ACTION_EXPLAIN -> {
                val question = intent.getStringExtra("question") ?: ""
                val answer = intent.getStringExtra("answer") ?: ""
                scope.launch { handleExplain(question, answer) }
            }
            ACTION_COPY_ANSWER -> {
                val answer = intent.getStringExtra("answer") ?: ""
                if (answer.isNotEmpty()) {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(android.content.ClipData.newPlainText("answer", answer))
                    Toast.makeText(this, "Jawaban disalin ke clipboard", Toast.LENGTH_SHORT).show()
                }
            }
            "SET_AUTO_SOLVE" -> {
                updateAutoSolve(intent.getBooleanExtra("enabled", false))
                showPersistentNotification()
            }
            "SYNC_MODE" -> {
                setMode(intent.getStringExtra("mode") ?: getMode())
                showPersistentNotification()
            }
            else -> showPersistentNotification()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        clipboardListener?.let {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.removePrimaryClipChangedListener(it)
        }
        scope.cancel()
        super.onDestroy()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, "Winatra AI Service", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Winatra AI Shortcut Service"
                setShowBadge(false)
            })
            manager.createNotificationChannel(NotificationChannel(
                RESULT_CHANNEL_ID, "Winatra AI Jawaban", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi hasil jawaban AI"
                setShowBadge(true)
                enableVibration(true)
                setSound(null, null)
            })
        }
    }

    private fun getMode() = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        .getString(KEY_MODE, "Essay") ?: "Essay"

    private fun setMode(mode: String) {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit().putString(KEY_MODE, mode).apply()
    }

    private fun toggleMode() {
        val current = getMode()
        val newMode = if (current == "Essay") "PG" else "Essay"
        setMode(newMode)
        showPersistentNotification()
    }

    private fun setupClipboardListener() {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        autoSolveEnabled = prefs.getBoolean("auto_solve", false)

        clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
            if (autoSolveEnabled) {
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = clipboard.primaryClip
                    val text = clip?.getItemAt(0)?.text?.toString()?.trim() ?: ""
                    if (text.isNotEmpty() && text.endsWith("?")) {
                        val intent = Intent(this, ClipboardActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        startActivity(intent)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Clipboard error: ${e.message}")
                }
            }
        }
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.addPrimaryClipChangedListener(clipboardListener)
    }

    private fun updateAutoSolve(enabled: Boolean) {
        autoSolveEnabled = enabled
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit().putBoolean("auto_solve", enabled).apply()
    }

    private fun showPersistentNotification() {
        val mode = getMode()
        val autoStatus = if (autoSolveEnabled) "ON" else "OFF"
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Winatra AI Shortcut")
            .setContentText("Mode: $mode | Auto: $autoStatus | Copy teks lalu tekan Jawab")
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setOngoing(true)
            .addAction(0, "Ganti Mode", PendingIntent.getService(
                this, 1, Intent(this, WinatraService::class.java).apply { action = ACTION_CHANGE_MODE },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .addAction(0, "Jawab", PendingIntent.getActivity(
                this, 0, Intent(this, ClipboardActivity::class.java).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .addAction(android.R.drawable.ic_menu_send, "Tanya", PendingIntent.getActivity(
                this, 3, Intent(this, ClipboardActivity::class.java).apply { putExtra("mode", "ask") },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .build()
        startForeground(NOTIF_ID, notification)
    }

    private fun showResultNotification(title: String, body: String, withExplain: Boolean = false, question: String = "", answer: String = "") {
        val builder = NotificationCompat.Builder(this, RESULT_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)

        if (withExplain && question.isNotEmpty() && answer.isNotEmpty()) {
            val explainIntent = Intent(this, WinatraService::class.java).apply {
                action = ACTION_EXPLAIN
                putExtra("question", question)
                putExtra("answer", answer)
            }
            val explainPending = PendingIntent.getService(this, 2, explainIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(0, "Kenapa?", explainPending)
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(RESULT_NOTIF_ID, builder.build())
    }

    // ---------- LIMIT & PREMIUM ----------
    private fun checkAndShowLimit(): Boolean {
        val remaining = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getInt("remaining_quota", -1)
        if (remaining <= 0 && remaining != -1) {
            showResultNotification("Winatra AI", "Maaf, kuota harian habis. Hubungi admin untuk langganan.\n• 5k/hari\n• 15k/minggu\n• 30k/bulan")
            return false
        }
        return true
    }

    private suspend fun resetDailyQuotaIfNeeded() {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        if (prefs.getString(PREF_KEY_LAST_QUOTA_RESET, "") == today) return
        prefs.edit().putString(PREF_KEY_LAST_QUOTA_RESET, today).putInt("remaining_quota", DEFAULT_DAILY_QUOTA).apply()
        syncRemainingQuotaToFirestore(DEFAULT_DAILY_QUOTA)
    }

    private suspend fun syncRemainingQuotaToFirestore(quota: Int) {
        FirebaseAuth.getInstance().currentUser?.let { user ->
            try {
                FirebaseFirestore.getInstance().collection("users").document(user.uid).update("remainingQuota", quota).await()
            } catch (e: Exception) { Log.e(TAG, "Firestore sync failed: ${e.message}") }
        }
    }

    private fun decrementRemainingQuota() {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val current = prefs.getInt("remaining_quota", 0)
        if (current > 0) {
            val newVal = current - 1
            prefs.edit().putInt("remaining_quota", newVal).apply()
            scope.launch { syncRemainingQuotaToFirestore(newVal) }
        }
    }

    private suspend fun isUserPremium(): Boolean = withContext(Dispatchers.IO) {
        try {
            val user = FirebaseAuth.getInstance().currentUser ?: return@withContext false
            val doc = FirebaseFirestore.getInstance().collection("users").document(user.uid).get().await()
            if (!doc.exists()) return@withContext false
            val isPremiumFlag = doc.getBoolean("isPremium") ?: false
            if (!isPremiumFlag) return@withContext false
            val expiry = doc.getTimestamp("premiumExpiry")?.toDate()
            if (expiry == null) return@withContext true
            expiry.after(Date())
        } catch (e: Exception) { false }
    }

    // ---------- API ROUND-ROBIN ----------
    private fun getStoredApiIndex(): Int {
        val idx = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getInt(PREF_KEY_API_INDEX, 0)
        return idx.coerceAtLeast(0) % API_ENDPOINTS.size
    }

    private fun saveApiIndex(index: Int) {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit().putInt(PREF_KEY_API_INDEX, index % API_ENDPOINTS.size).apply()
    }

    private suspend fun callAIWithFallback(question: String, mode: String): String {
        val startIdx = getStoredApiIndex()
        for (i in API_ENDPOINTS.indices) {
            val idx = (startIdx + i) % API_ENDPOINTS.size
            val endpoint = API_ENDPOINTS[idx]
            val result = performApiRequest(endpoint, question, mode)
            if (result != null && !result.startsWith("Error:")) {
                saveApiIndex(idx + 1)
                return result
            }
        }
        saveApiIndex(startIdx + 1)
        return "Error: All API keys failed."
    }

    private suspend fun performApiRequest(endpoint: ApiEndpoint, question: String, mode: String): String? {
        val systemPrompt = if (mode == "PG") "Jawab HANYA dengan satu huruf: A, B, C, atau D. Tidak perlu penjelasan."
                          else "Berikan jawaban yang lengkap dan jelas dalam Bahasa Indonesia."
        val model = if (endpoint.type == "DeepSeek") "deepseek-chat" else "llama-3.3-70b-versatile"

        val json = JSONObject().apply {
            put("model", model)
            put("messages", org.json.JSONArray().apply {
                put(JSONObject().apply { put("role", "system"); put("content", systemPrompt) })
                put(JSONObject().apply { put("role", "user"); put("content", question) })
            })
            put("max_tokens", if (mode == "PG") 10 else 500)
            put("temperature", 0.3)
        }

        val request = Request.Builder()
            .url("${endpoint.baseUrl}/chat/completions")
            .addHeader("Authorization", "Bearer ${endpoint.key}")
            .addHeader("Content-Type", "application/json")
            .post(json.toString().toRequestBody("application/json".toMediaType()))
            .build()

        return try {
            val response = client.newCall(request).execute()
            val body = response.body?.string() ?: ""
            if (response.isSuccessful) {
                var answer = JSONObject(body).getJSONArray("choices")
                    .getJSONObject(0).getJSONObject("message").getString("content").trim()
                if (mode == "PG") {
                    // Hanya ambil huruf pertama yang valid A/B/C/D (case insensitive)
                    val firstValid = answer.uppercase().firstOrNull { it in 'A'..'D' }
                    answer = if (firstValid != null) firstValid.toString() else "?"
                }
                answer
            } else {
                when (response.code) {
                    429, 503 -> "Error: rate_limit"
                    401, 403 -> "Error: auth_failed"
                    else -> "Error: ${response.code}"
                }
            }
        } catch (e: java.net.SocketTimeoutException) { "Error: timeout"
        } catch (e: java.io.IOException) { "Error: network"
        } catch (e: Exception) { "Error: ${e.message}" }
    }

    private suspend fun callExplanationWithFallback(question: String, answer: String): String {
        val startIdx = getStoredApiIndex()
        for (i in API_ENDPOINTS.indices) {
            val idx = (startIdx + i) % API_ENDPOINTS.size
            val endpoint = API_ENDPOINTS[idx]
            val result = performExplanationRequest(endpoint, question, answer)
            if (result != null && !result.startsWith("Error:")) {
                saveApiIndex(idx + 1)
                return result
            }
        }
        return "Error: All API keys failed for explanation."
    }

    private suspend fun performExplanationRequest(endpoint: ApiEndpoint, question: String, answer: String): String? {
        val json = JSONObject().apply {
            put("model", if (endpoint.type == "DeepSeek") "deepseek-chat" else "llama-3.3-70b-versatile")
            put("messages", org.json.JSONArray().apply {
                put(JSONObject().apply { put("role", "system"); put("content", "Jelaskan secara singkat mengapa jawaban yang benar adalah $answer. Berikan alasan logis dalam Bahasa Indonesia.") })
                put(JSONObject().apply { put("role", "user"); put("content", "Pertanyaan: $question") })
            })
            put("max_tokens", 300)
            put("temperature", 0.5)
        }
        val request = Request.Builder()
            .url("${endpoint.baseUrl}/chat/completions")
            .addHeader("Authorization", "Bearer ${endpoint.key}")
            .addHeader("Content-Type", "application/json")
            .post(json.toString().toRequestBody("application/json".toMediaType()))
            .build()
        return try {
            val response = client.newCall(request).execute()
            val body = response.body?.string() ?: ""
            if (response.isSuccessful) {
                JSONObject(body).getJSONArray("choices")
                    .getJSONObject(0).getJSONObject("message").getString("content").trim()
            } else { "Error: ${response.code}" }
        } catch (e: Exception) { "Error: ${e.message}" }
    }

    private fun processClipboardResult(question: String, modeType: String = "answer") {
        if (FirebaseAuth.getInstance().currentUser == null) {
            showResultNotification("Winatra AI", "Silakan login terlebih dahulu.")
            return
        }
        if (question.isEmpty()) {
            showResultNotification("Winatra AI", "Clipboard kosong! Salin pertanyaan dulu.")
            return
        }
        showResultNotification("Winatra AI", "⏳ Memproses...")
        scope.launch {
            resetDailyQuotaIfNeeded()
            val isPremium = isUserPremium()
            if (!isPremium && !checkAndShowLimit()) return@launch
            val answer = callAIWithFallback(question, if (modeType == "discussion") "Essay" else getMode())
            withContext(Dispatchers.Main) {
                if (answer.startsWith("Error:")) {
                    val msg = when {
                        answer.contains("rate_limit") -> "Layanan padat, coba lagi nanti."
                        answer.contains("auth_failed") -> "Masalah kunci API, laporkan ke pengembang."
                        answer.contains("timeout") -> "Koneksi lambat, coba lagi."
                        answer.contains("network") -> "Tidak ada koneksi internet."
                        else -> "Layanan sibuk, coba lagi nanti."
                    }
                    showResultNotification("Winatra AI", msg)
                    return@withContext
                }
                if (!isPremium) decrementRemainingQuota()
                if (modeType == "discussion") {
                    showDiscussionNotification(question, answer)
                } else {
                    if (getMode() == "PG") {
                        showResultNotification("Jawaban PG", "Jawaban: $answer", true, question, answer)
                    } else {
                        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(android.content.ClipData.newPlainText("answer", answer))
                        showResultNotification("Jawaban Essay", "Jawaban disalin ke clipboard!")
                    }
                }
            }
        }
    }

    private fun showDiscussionNotification(question: String, answer: String) {
        val builder = NotificationCompat.Builder(this, RESULT_CHANNEL_ID)
            .setContentTitle("💬 Diskusi AI")
            .setContentText("Pertanyaan: ${question.take(60)}...\nKlik untuk lihat jawaban")
            .setStyle(NotificationCompat.BigTextStyle().bigText(answer))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .addAction(0, "Salin", PendingIntent.getService(
                this, 4, Intent(this, WinatraService::class.java).apply {
                    action = ACTION_COPY_ANSWER
                    putExtra("answer", answer)
                }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(RESULT_NOTIF_ID + 1, builder.build())
    }

    private suspend fun handleExplain(question: String, answer: String) {
        showResultNotification("Winatra AI", "📖 Menyiapkan penjelasan...")
        val explanation = callExplanationWithFallback(question, answer)
        withContext(Dispatchers.Main) {
            if (explanation.startsWith("Error:")) {
                showResultNotification("Penjelasan", "Penjelasan tidak tersedia saat ini.")
            } else {
                showResultNotification("Penjelasan", explanation)
            }
        }
    }
}