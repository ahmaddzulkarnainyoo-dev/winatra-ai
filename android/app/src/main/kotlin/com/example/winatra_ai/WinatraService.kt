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
        const val DEFAULT_DAILY_QUOTA = 15
        const val TAG = "WinatraService"

        data class ApiEndpoint(val key: String, val baseUrl: String, val type: String)

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
            ApiEndpoint("BUILD_GROQ_KEY_25", "https://api.groq.com/openai/v1", "Groq"),
            ApiEndpoint("BUILD_DEEPSEEK_KEY", "https://api.deepseek.com/v1", "DeepSeek")
        )
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val client = OkHttpClient()
    private var autoSolveEnabled = false
    private var clipboardListener: ClipboardManager.OnPrimaryClipChangedListener? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate called")
        createNotificationChannels()
        setupClipboardListener()
        showPersistentNotification()
        Log.d(TAG, "onCreate finished")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand action=${intent?.action}")
        when (intent?.action) {
            ACTION_CHANGE_MODE -> {
                Log.d(TAG, "ACTION_CHANGE_MODE received")
                toggleMode()
            }
            ACTION_CLIPBOARD_RESULT -> {
                val question = intent.getStringExtra(ClipboardActivity.EXTRA_QUESTION) ?: ""
                val modeType = intent.getStringExtra(ClipboardActivity.EXTRA_MODE_TYPE) ?: "answer"
                Log.d(TAG, "CLIPBOARD_RESULT received, question length=${question.length}, modeType=$modeType")
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
                    val clip = android.content.ClipData.newPlainText("answer", answer)
                    clipboard.setPrimaryClip(clip)
                    Toast.makeText(this, "Jawaban disalin ke clipboard", Toast.LENGTH_SHORT).show()
                }
            }
            "SET_AUTO_SOLVE" -> {
                val enabled = intent.getBooleanExtra("enabled", false)
                updateAutoSolve(enabled)
                showPersistentNotification()
            }
            "SYNC_MODE" -> {
                val mode = intent.getStringExtra("mode") ?: getMode()
                setMode(mode)
                showPersistentNotification()
                Log.d(TAG, "Mode synced to $mode")
            }
            else -> {
                Log.d(TAG, "No action, ensuring notification shown")
                showPersistentNotification()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        clipboardListener?.let {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.removePrimaryClipChangedListener(it)
        }
        scope.cancel()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val persistentChannel = NotificationChannel(
                CHANNEL_ID,
                "Winatra AI Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Winatra AI Shortcut Service"
                setShowBadge(false)
            }
            val resultChannel = NotificationChannel(
                RESULT_CHANNEL_ID,
                "Winatra AI Jawaban",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi hasil jawaban AI"
                setShowBadge(true)
                enableVibration(true)
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(persistentChannel)
            manager.createNotificationChannel(resultChannel)
            Log.d(TAG, "Notification channels created")
        }
    }

    private fun getMode(): String {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_MODE, "Essay") ?: "Essay"
    }

    private fun setMode(mode: String) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(KEY_MODE, mode).apply()
    }

    private fun toggleMode() {
        val current = getMode()
        val newMode = if (current == "Essay") "PG" else "Essay"
        setMode(newMode)
        Log.d(TAG, "Mode toggled to $newMode")
        showPersistentNotification()
    }

    private fun setupClipboardListener() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        autoSolveEnabled = prefs.getBoolean("auto_solve", false)
        Log.d(TAG, "Auto-solve initial: $autoSolveEnabled")

        clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
            Log.d(TAG, "Clipboard changed detected! Auto-solve enabled: $autoSolveEnabled")
            if (autoSolveEnabled) {
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = clipboard.primaryClip
                    var text = ""
                    if (clip != null && clip.itemCount > 0) {
                        text = clip.getItemAt(0).text?.toString()?.trim() ?: ""
                    }
                    Log.d(TAG, "Clipboard content: '$text'")
                    if (text.isNotEmpty() && text.endsWith("?")) {
                        Log.d(TAG, "Auto-solve triggered for question: ${text.take(50)}...")
                        val intent = Intent(this@WinatraService, ClipboardActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        startActivity(intent)
                    } else {
                        Log.d(TAG, "Clipboard changed but no question mark, ignoring")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in clipboard listener: ${e.message}", e)
                }
            } else {
                Log.d(TAG, "Auto-solve disabled, ignoring clipboard change")
            }
        }
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.addPrimaryClipChangedListener(clipboardListener)
        Log.d(TAG, "Clipboard listener registered")
    }

    private fun updateAutoSolve(enabled: Boolean) {
        autoSolveEnabled = enabled
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
            .putBoolean("auto_solve", enabled).apply()
        Log.d(TAG, "Auto-solve set to $autoSolveEnabled")
    }

    private fun showPersistentNotification() {
        val mode = getMode()
        val autoStatus = if (autoSolveEnabled) "ON" else "OFF"
        Log.d(TAG, "showPersistentNotification: mode=$mode, auto=$autoStatus")

        val answerIntent = Intent(this, ClipboardActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val answerPending = PendingIntent.getActivity(
            this, 0, answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val changeModeIntent = Intent(this, WinatraService::class.java).apply {
            action = ACTION_CHANGE_MODE
        }
        val changeModePending = PendingIntent.getService(
            this, 1, changeModeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val askIntent = Intent(this, ClipboardActivity::class.java).apply {
            putExtra("mode", "ask")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val askPending = PendingIntent.getActivity(
            this, 3, askIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val askAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send, "Tanya", askPending
        ).build()

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Winatra AI Shortcut")
            .setContentText("Mode: $mode | Auto: $autoStatus | Copy teks lalu tekan Jawab")
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, "Ganti Mode", changeModePending)
            .addAction(0, "Jawab", answerPending)
            .addAction(askAction)
            .build()

        try {
            startForeground(NOTIF_ID, notification)
            Log.d(TAG, "startForeground succeeded")
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
        }
    }

    private fun showResultNotification(title: String, body: String, withExplainButton: Boolean = false, question: String = "", answer: String = "") {
        val manager = getSystemService(NotificationManager::class.java)
        val builder = NotificationCompat.Builder(this, RESULT_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)

        if (title.contains("PG") && !withExplainButton) {
            builder.setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_VIBRATE)
                .setVibrate(longArrayOf(0, 200, 100, 200))
        } else {
            builder.setPriority(NotificationCompat.PRIORITY_DEFAULT)
        }

        if (withExplainButton && question.isNotEmpty() && answer.isNotEmpty()) {
            val explainIntent = Intent(this, WinatraService::class.java).apply {
                action = ACTION_EXPLAIN
                putExtra("question", question)
                putExtra("answer", answer)
            }
            val explainPending = PendingIntent.getService(this, 2, explainIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            builder.addAction(0, "Kenapa?", explainPending)
        }

        manager.notify(RESULT_NOTIF_ID, builder.build())
        Log.d(TAG, "Result notification shown: $title")
    }

    // ========== LIMIT & PREMIUM FUNCTIONS ==========
    private fun checkAndShowLimit(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val remaining = prefs.getInt("remaining_quota", -1)
        Log.d(TAG, "checkAndShowLimit: remaining = $remaining")
        if (remaining == -1) return true
        if (remaining <= 0) {
            showResultNotification(
                "Winatra AI",
                "Maaf, kuota harian Anda habis. Silakan hubungi admin di WhatsApp [NOMOR_ADMIN] dan kirimkan bukti pembayaran. Pilih paket langganan:\n• 5.000/hari\n• 15.000/minggu\n• 30.000/bulan\nTransfer ke rekening [REKENING]. Admin akan mengaktifkan premium setelah konfirmasi."
            )
            return false
        }
        return true
    }

    private suspend fun resetDailyQuotaIfNeeded() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val lastReset = prefs.getString(PREF_KEY_LAST_QUOTA_RESET, "") ?: ""
        if (lastReset == today) return

        prefs.edit()
            .putString(PREF_KEY_LAST_QUOTA_RESET, today)
            .putInt("remaining_quota", DEFAULT_DAILY_QUOTA)
            .apply()
        Log.d(TAG, "Reset harian: kuota menjadi $DEFAULT_DAILY_QUOTA")

        syncRemainingQuotaToFirestore(DEFAULT_DAILY_QUOTA)
    }

    private suspend fun syncRemainingQuotaToFirestore(quota: Int) {
        try {
            val user = FirebaseAuth.getInstance().currentUser ?: return
            FirebaseFirestore.getInstance()
                .collection("users")
                .document(user.uid)
                .update("remainingQuota", quota)
                .await()
            Log.d(TAG, "Synced remainingQuota to Firestore: $quota")
        } catch (e: Exception) {
            Log.e(TAG, "syncRemainingQuotaToFirestore: ${e.message}")
        }
    }

    private suspend fun syncQuotaFromFirestore() {
        try {
            val user = FirebaseAuth.getInstance().currentUser ?: return
            val doc = FirebaseFirestore.getInstance()
                .collection("users")
                .document(user.uid)
                .get()
                .await()
            if (doc.exists()) {
                val remoteQuota = doc.getLong("remainingQuota")?.toInt() ?: DEFAULT_DAILY_QUOTA
                val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                prefs.edit().putInt("remaining_quota", remoteQuota).apply()
                Log.d(TAG, "Synced quota from Firestore: $remoteQuota")
            }
        } catch (e: Exception) {
            Log.e(TAG, "syncQuotaFromFirestore: ${e.message}")
        }
    }

    private fun decrementRemainingQuota() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val current = prefs.getInt("remaining_quota", 0)
        if (current > 0) {
            val newVal = current - 1
            prefs.edit().putInt("remaining_quota", newVal).apply()
            Log.d(TAG, "decrementRemainingQuota: $current -> $newVal")
            scope.launch { syncRemainingQuotaToFirestore(newVal) }
        }
    }

    private suspend fun isUserPremium(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val user = FirebaseAuth.getInstance().currentUser
                if (user == null) return@withContext false
                val doc = FirebaseFirestore.getInstance().collection("users").document(user.uid).get().await()
                if (!doc.exists()) return@withContext false
                val isPremiumFlag = doc.getBoolean("isPremium") ?: false
                if (!isPremiumFlag) return@withContext false
                val premiumExpiry = doc.getTimestamp("premiumExpiry")?.toDate()
                if (premiumExpiry == null) return@withContext true
                return@withContext premiumExpiry.after(Date())
            } catch (e: Exception) {
                Log.e(TAG, "isUserPremium error: ${e.message}")
                return@withContext false
            }
        }
    }
    // ========== END LIMIT & PREMIUM ==========

    private fun processClipboardResult(question: String, modeType: String = "answer") {
        val mode = getMode()
        Log.d(TAG, "processClipboardResult: question length=${question.length}, mode=$mode, modeType=$modeType")

        if (question.isEmpty()) {
            Log.w(TAG, "Clipboard is empty!")
            showResultNotification("Winatra AI", "Clipboard kosong! Salin pertanyaan terlebih dahulu.")
            return
        }

        showResultNotification("Winatra AI", "⏳ Memproses pertanyaan...")

        scope.launch {
            try {
                resetDailyQuotaIfNeeded()
                syncQuotaFromFirestore()
                val isPremium = isUserPremium()
                if (!isPremium) {
                    if (!checkAndShowLimit()) return@launch
                } else {
                    Log.d(TAG, "User is premium, skipping limit check")
                }

                val answer = withContext(Dispatchers.IO) {
                callAIWithFallback(question, if (modeType == "discussion") "Essay" else mode)
            }

            withContext(Dispatchers.Main) {
                if (answer.startsWith("Error:")) {
                    val friendlyMsg = getUserFriendlyErrorMessage(answer)
                    showResultNotification("Winatra AI", friendlyMsg)
                    return@withContext
                }

                if (!isPremium) decrementRemainingQuota()

                if (modeType == "discussion") {
                    showDiscussionNotification(question, answer)
                } else {
                    if (mode == "PG") {
                        showResultNotification("Jawaban PG", "Jawaban: $answer", true, question, answer)
                    } else {
                        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = android.content.ClipData.newPlainText("answer", answer)
                        clipboard.setPrimaryClip(clip)
                        showResultNotification("Jawaban Essay", "Jawaban disalin ke clipboard!")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in processClipboardResult: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    showResultNotification("Winatra AI", "Terjadi error: ${e.message}")
                }
            }
        }
    }

    private fun getUserFriendlyErrorMessage(rawError: String): String {
        return when {
            rawError.contains("All API keys failed") -> "Layanan AI sedang sangat sibuk. Coba lagi nanti. Jika masalah berlanjut, hubungi admin untuk informasi paket premium."
            rawError.contains("429") -> "Trafik padat, coba lagi sebentar."
            rawError.contains("401") || rawError.contains("403") -> "Ada masalah teknis. Tim kami sedang memperbaiki."
            rawError.contains("timeout") -> "Koneksi lambat, coba lagi dengan sinyal lebih baik."
            rawError.contains("network") -> "Tidak ada koneksi internet. Periksa jaringan Anda."
            else -> "Maaf, terjadi gangguan. Silakan coba beberapa saat lagi."
        }
    }

    private fun showDiscussionNotification(question: String, answer: String) {
        val manager = getSystemService(NotificationManager::class.java)
        val builder = NotificationCompat.Builder(this, RESULT_CHANNEL_ID)
            .setContentTitle("💬 Diskusi AI")
            .setContentText("Pertanyaan: ${question.take(60)}...\nKlik untuk lihat jawaban")
            .setStyle(NotificationCompat.BigTextStyle().bigText(answer))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

        val copyIntent = Intent(this, WinatraService::class.java).apply {
            action = ACTION_COPY_ANSWER
            putExtra("answer", answer)
        }
        val copyPending = PendingIntent.getService(this, 4, copyIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        builder.addAction(0, "Salin", copyPending)

        manager.notify(RESULT_NOTIF_ID + 1, builder.build())
        Log.d(TAG, "Discussion notification shown")
    }

    private suspend fun handleExplain(question: String, answer: String) {
        Log.d(TAG, "handleExplain called")
        showResultNotification("Winatra AI", "📖 Menyiapkan penjelasan...")
        val explanation = withContext(Dispatchers.IO) {
            callExplanationWithFallback(question, answer)
        }
        withContext(Dispatchers.Main) {
            if (explanation.startsWith("Error:")) {
                val friendlyMsg = getUserFriendlyErrorMessage(explanation)
                showResultNotification("Penjelasan", friendlyMsg)
            } else {
                showResultNotification("Penjelasan", explanation)
            }
        }
    }

    // ========== API CALL WITH FALLBACK (Groq + DeepSeek) ==========
    private fun getStoredApiIndex(): Int {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getInt(PREF_KEY_API_INDEX, 0).coerceAtLeast(0) % API_ENDPOINTS.size
    }

    private fun saveApiIndex(index: Int) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putInt(PREF_KEY_API_INDEX, index % API_ENDPOINTS.size).apply()
    }

    private suspend fun callAIWithFallback(question: String, mode: String): String {
        val startIndex = getStoredApiIndex()
        for (i in API_ENDPOINTS.indices) {
            val idx = (startIndex + i) % API_ENDPOINTS.size
            val endpoint = API_ENDPOINTS[idx]
            val result = performApiRequest(endpoint, question, mode)
            if (result != null && !result.startsWith("Error:")) {
                saveApiIndex((idx + 1) % API_ENDPOINTS.size)
                return result
            } else {
                Log.w(TAG, "API endpoint failed: ${endpoint.type} ${endpoint.key.take(12)}... error=$result")
            }
        }
        saveApiIndex((startIndex + 1) % API_ENDPOINTS.size)
        return "Error: All API keys failed."
    }

    private suspend fun performApiRequest(endpoint: ApiEndpoint, question: String, mode: String): String? {
        val systemPrompt = if (mode == "PG")
            "Jawab HANYA dengan satu huruf: A, B, C, atau D. Tidak perlu penjelasan."
        else
            "Berikan jawaban yang lengkap dan jelas dalam Bahasa Indonesia."

        val model = if (endpoint.type == "DeepSeek") "deepseek-v4-flash" else "llama-3.3-70b-versatile"

        val json = JSONObject().apply {
            put("model", model)
            put("messages", org.json.JSONArray().apply {
                put(JSONObject().apply {
                    put("role", "system")
                    put("content", systemPrompt)
                })
                put(JSONObject().apply {
                    put("role", "user")
                    put("content", question)
                })
            })
            put("max_tokens", if (mode == "PG") 10 else 500)
            put("temperature", 0.3)
        }

        val body = json.toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url("${endpoint.baseUrl}/chat/completions")
            .addHeader("Authorization", "Bearer ${endpoint.key}")
            .addHeader("Content-Type", "application/json")
            .post(body)
            .build()

        return try {
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()
            if (response.isSuccessful && responseBody != null) {
                val result = JSONObject(responseBody)
                var answer = result
                    .getJSONArray("choices")
                    .getJSONObject(0)
                    .getJSONObject("message")
                    .getString("content")
                    .trim()
                if (mode == "PG") {
                    answer = answer.replace(Regex("[^A-Da-d]"), "")
                    if (answer.isEmpty()) return "?"
                    answer = answer[0].uppercaseChar().toString()
                }
                answer
            } else {
                "Error: ${response.code}"
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }

    private suspend fun callExplanationWithFallback(question: String, answer: String): String {
        val startIndex = getStoredApiIndex()
        for (i in API_ENDPOINTS.indices) {
            val idx = (startIndex + i) % API_ENDPOINTS.size
            val endpoint = API_ENDPOINTS[idx]
            val result = performExplanationRequest(endpoint, question, answer)
            if (result != null && !result.startsWith("Error:")) {
                saveApiIndex((idx + 1) % API_ENDPOINTS.size)
                return result
            }
        }
        return "Error: All API keys failed for explanation."
    }

    private suspend fun performExplanationRequest(endpoint: ApiEndpoint, question: String, answer: String): String? {
        val systemPrompt = "Jelaskan secara singkat dan jelas mengapa jawaban yang benar untuk pertanyaan berikut adalah $answer. Berikan alasan yang logis dalam Bahasa Indonesia."
        val userContent = "Pertanyaan: $question"

        val json = JSONObject().apply {
            put("model", if (endpoint.type == "DeepSeek") "deepseek-v4-flash" else "llama-3.3-70b-versatile")
            put("messages", org.json.JSONArray().apply {
                put(JSONObject().apply {
                    put("role", "system")
                    put("content", systemPrompt)
                })
                put(JSONObject().apply {
                    put("role", "user")
                    put("content", userContent)
                })
            })
            put("max_tokens", 300)
            put("temperature", 0.5)
        }

        val body = json.toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url("${endpoint.baseUrl}/chat/completions")
            .addHeader("Authorization", "Bearer ${endpoint.key}")
            .addHeader("Content-Type", "application/json")
            .post(body)
            .build()

        return try {
            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()
            if (response.isSuccessful && responseBody != null) {
                val result = JSONObject(responseBody)
                result
                    .getJSONArray("choices")
                    .getJSONObject(0)
                    .getJSONObject("message")
                    .getString("content")
                    .trim()
            } else {
                "Error: ${response.code}"
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }
}