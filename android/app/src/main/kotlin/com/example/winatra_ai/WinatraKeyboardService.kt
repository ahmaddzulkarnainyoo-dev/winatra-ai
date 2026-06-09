package com.example.winatra_ai

import android.app.*
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.inputmethod.InputConnection
import android.widget.*
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
import kotlin.random.Random

class WinatraKeyboardService : InputMethodService() {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    private var isShift = false
    private var isCaps = false
    private var isSymbol = false
    private var currentTab = 0

    private var lastAnswer = ""
    private var lastQuestion = ""

    private lateinit var rootView: LinearLayout
    private lateinit var tabBar: LinearLayout
    private lateinit var keyboardPanel: LinearLayout
    private lateinit var aiInputBar: LinearLayout
    private lateinit var readPanel: LinearLayout
    private lateinit var aiInput: EditText
    private lateinit var aiStatus: TextView
    private lateinit var readAnswer: TextView
    private lateinit var readStatus: TextView
    private lateinit var readScrollView: ScrollView

    companion object {
        const val TAG = "WinatraKeyboardService"
        const val PREFS_NAME = "winatra_prefs"
        const val PREF_KEY_LAST_QUOTA_RESET = "last_quota_reset"
        const val DEFAULT_DAILY_QUOTA = 8
        const val DEEPSEEK_WEIGHT = 96      // Bobot DeepSeek (96 dari total 120 = 80%)

        data class ApiEndpoint(val key: String, val baseUrl: String, val type: String)

        // Daftar asli endpoint (24 Groq + 1 DeepSeek)
        private val API_ENDPOINTS = listOf(
            ApiEndpoint("BUILD_DEEPSEEK_KEY", "https://api.deepseek.com/v1", "DeepSeek"),
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
            ApiEndpoint("BUILD_GROQ_KEY_24", "https://api.groq.com/openai/v1", "Groq")
        )

        // Daftar berbobot: DeepSeek diulang DEEPSEEK_WEIGHT kali, setiap Groq 1 kali
        private val WEIGHTED_ENDPOINTS: List<ApiEndpoint> by lazy {
            val deepseek = API_ENDPOINTS.first { it.type == "DeepSeek" }
            val groqs = API_ENDPOINTS.filter { it.type == "Groq" }
            List(DEEPSEEK_WEIGHT) { deepseek } + groqs
        }

        val ROWS_LOWER = arrayOf(
            arrayOf("q","w","e","r","t","y","u","i","o","p"),
            arrayOf("a","s","d","f","g","h","j","k","l"),
            arrayOf("SHIFT","z","x","c","v","b","n","m","⌫"),
            arrayOf("?123", ",", ".", "?", "SPACE", "ENTER")
        )
        val ROWS_UPPER = arrayOf(
            arrayOf("Q","W","E","R","T","Y","U","I","O","P"),
            arrayOf("A","S","D","F","G","H","J","K","L"),
            arrayOf("SHIFT","Z","X","C","V","B","N","M","⌫"),
            arrayOf("?123", ",", ".", "?", "SPACE", "ENTER")
        )
        val ROWS_SYMBOL = arrayOf(
            arrayOf("1","2","3","4","5","6","7","8","9","0"),
            arrayOf("@","#","$","%","&","-","+","(",")","/"),
            arrayOf("*","\"","'",":",";","!","?", "⌫"),
            arrayOf("ABC", ",", ".", "SPACE", "ENTER")
        )
    }

    override fun onCreateInputView(): View {
        val ctx = this

        rootView = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1C1C1E"))
        }

        tabBar = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#2C2C2E"))
        }
        tabBar.addView(buildTabBtn(ctx, "⌨", "Ketik", 0))
        tabBar.addView(buildTabBtn(ctx, "✨", "Tanya AI", 1))
        tabBar.addView(buildTabBtn(ctx, "📖", "Baca", 2))
        rootView.addView(tabBar)

        aiInputBar = buildAIInputBar(ctx).apply { visibility = View.GONE }
        rootView.addView(aiInputBar)

        keyboardPanel = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1C1C1E"))
        }
        buildKeyboardRows(ctx)
        rootView.addView(keyboardPanel)

        readPanel = buildReadPanel(ctx).apply { visibility = View.GONE }
        rootView.addView(readPanel)

        return rootView
    }

    private fun buildTabBtn(ctx: Context, icon: String, label: String, index: Int): LinearLayout {
        val container = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setPadding(0, dp(12), 0, dp(12))
            setBackgroundColor(if (currentTab == index) Color.parseColor("#3A3A3C") else Color.TRANSPARENT)
            tag = "tab_$index"
            setOnClickListener { switchTab(index) }
        }
        val iconTv = TextView(ctx).apply {
            text = icon
            textSize = 24f
            gravity = Gravity.CENTER
            setTextColor(if (currentTab == index) Color.WHITE else Color.parseColor("#8E8E93"))
            tag = "icon_$index"
        }
        val labelTv = TextView(ctx).apply {
            text = label
            textSize = 11f
            gravity = Gravity.CENTER
            setTextColor(if (currentTab == index) Color.WHITE else Color.parseColor("#636366"))
            tag = "label_$index"
        }
        container.addView(iconTv)
        container.addView(labelTv)
        return container
    }

    private fun switchTab(tab: Int) {
        currentTab = tab
        updateTabColors()
        when (tab) {
            0 -> {
                aiInputBar.visibility = View.GONE
                keyboardPanel.visibility = View.VISIBLE
                readPanel.visibility = View.GONE
            }
            1 -> {
                aiInputBar.visibility = View.VISIBLE
                keyboardPanel.visibility = View.VISIBLE
                readPanel.visibility = View.GONE
                scope.launch {
                    val isPremium = isUserPremium()
                    withContext(Dispatchers.Main) {
                        if (isPremium) {
                            aiStatus.text = "✨ Akun Premium: Tanpa Batas ✨"
                            aiStatus.visibility = View.VISIBLE
                        } else {
                            aiStatus.visibility = View.GONE
                        }
                    }
                }
            }
            2 -> {
                aiInputBar.visibility = View.GONE
                keyboardPanel.visibility = View.GONE
                readPanel.visibility = View.VISIBLE
                scope.launch {
                    val isPremium = isUserPremium()
                    withContext(Dispatchers.Main) {
                        if (lastAnswer.isNotEmpty()) {
                            val premiumHeader = if (isPremium) "✨ Akun Premium - Unlimited ✨\n\n" else ""
                            readAnswer.text = premiumHeader + lastAnswer
                            readScrollView.visibility = View.VISIBLE
                            readStatus.text = "Pertanyaan: $lastQuestion"
                            readStatus.visibility = View.VISIBLE
                        } else {
                            readStatus.text = "Belum ada jawaban. Tanya dulu di tab ✨"
                            readStatus.visibility = View.VISIBLE
                            readScrollView.visibility = View.GONE
                        }
                    }
                }
            }
        }
    }

    private fun updateTabColors() {
        for (i in 0..2) {
            val tabView = tabBar.findViewWithTag<LinearLayout>("tab_$i")
            if (tabView != null) {
                val icon = tabView.findViewWithTag<TextView>("icon_$i")
                val label = tabView.findViewWithTag<TextView>("label_$i")
                val active = i == currentTab
                tabView.setBackgroundColor(if (active) Color.parseColor("#3A3A3C") else Color.TRANSPARENT)
                icon?.setTextColor(if (active) Color.WHITE else Color.parseColor("#8E8E93"))
                label?.setTextColor(if (active) Color.WHITE else Color.parseColor("#636366"))
            }
        }
    }

    private fun buildAIInputBar(ctx: Context): LinearLayout {
        val bar = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#2C2C2E"))
            setPadding(dp(16), dp(14), dp(16), dp(14))
        }

        aiStatus = TextView(ctx).apply {
            text = ""
            textSize = 13f
            setTextColor(Color.parseColor("#636366"))
            visibility = View.GONE
            setPadding(0, 0, 0, dp(8))
        }
        bar.addView(aiStatus)

        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        aiInput = EditText(ctx).apply {
            hint = "Ketik pertanyaan..."
            setHintTextColor(Color.parseColor("#636366"))
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#3A3A3C"))
            textSize = 16f
            setPadding(dp(16), dp(14), dp(16), dp(14))
            maxLines = 2
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            isFocusableInTouchMode = true
        }

        val btnSend = TextView(ctx).apply {
            text = "Kirim"
            textSize = 15f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#0A84FF"))
            setPadding(dp(24), dp(14), dp(24), dp(14))
            val params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            params.setMargins(dp(14), 0, 0, 0)
            layoutParams = params
            setOnClickListener { handleAIQuery() }
        }

        row.addView(aiInput)
        row.addView(btnSend)
        bar.addView(row)

        return bar
    }

    private fun buildReadPanel(ctx: Context): LinearLayout {
        val panel = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1C1C1E"))
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }

        readStatus = TextView(ctx).apply {
            text = "Belum ada jawaban. Tanya dulu di tab ✨"
            textSize = 13f
            setTextColor(Color.parseColor("#636366"))
            setPadding(0, 0, 0, dp(10))
        }
        panel.addView(readStatus)

        readScrollView = ScrollView(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(280)
            )
            visibility = View.GONE
        }
        readAnswer = TextView(ctx).apply {
            text = ""
            textSize = 16f
            setTextColor(Color.parseColor("#EBEBF5"))
            setLineSpacing(0f, 1.5f)
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }
        readScrollView.addView(readAnswer)
        panel.addView(readScrollView)

        val actionRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.setMargins(0, dp(20), 0, 0) }
        }

        val btnInsert = TextView(ctx).apply {
            text = "↳ Sisipkan"
            textSize = 15f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#0A84FF"))
            setPadding(dp(22), dp(14), dp(22), dp(14))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            setOnClickListener {
                currentInputConnection?.commitText(lastAnswer, 1)
                switchTab(0)
            }
        }

        val btnClear = TextView(ctx).apply {
            text = "Hapus"
            textSize = 15f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#8E8E93"))
            setBackgroundColor(Color.parseColor("#2C2C2E"))
            setPadding(dp(22), dp(14), dp(22), dp(14))
            val params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            params.setMargins(dp(12), 0, 0, 0)
            layoutParams = params
            setOnClickListener {
                lastAnswer = ""
                lastQuestion = ""
                readAnswer.text = ""
                readScrollView.visibility = View.GONE
                readStatus.text = "Belum ada jawaban. Tanya dulu di tab ✨"
            }
        }

        actionRow.addView(btnInsert)
        actionRow.addView(btnClear)
        panel.addView(actionRow)

        return panel
    }

    private fun buildKeyboardRows(ctx: Context) {
        val container = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6), dp(8), dp(6), dp(10))
        }
        refreshKeyboardRows(ctx, container)
        keyboardPanel.addView(container)
    }

    private fun refreshKeyboardRows(ctx: Context, container: LinearLayout) {
        container.removeAllViews()
        val rows = when {
            isSymbol -> ROWS_SYMBOL
            isShift || isCaps -> ROWS_UPPER
            else -> ROWS_LOWER
        }
        for (row in rows) {
            val rowLayout = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).also { it.setMargins(0, dp(5), 0, dp(5)) }
            }
            for (key in row) {
                val btn = buildKeyButton(ctx, key)
                rowLayout.addView(btn)
            }
            container.addView(rowLayout)
        }
    }

    private fun buildKeyButton(ctx: Context, label: String): TextView {
        val isSpecial = label in listOf("SHIFT", "⌫", "?123", "ABC", "SPACE", "ENTER")
        val text = when (label) {
            "SHIFT" -> if (isCaps) "⇪" else "⇧"
            "SPACE" -> "space"
            "ENTER" -> "return"
            else -> label
        }
        return TextView(ctx).apply {
            this.text = text
            textSize = if (isSpecial) 14f else 18f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setBackgroundColor(
                if (isSpecial) Color.parseColor("#3A3A3C") else Color.parseColor("#2C2C2E")
            )
            isAllCaps = false
            setTypeface(null, android.graphics.Typeface.BOLD)

            val weight = when (label) {
                "SPACE" -> 3.5f
                "ENTER" -> 1.8f
                "SHIFT", "⌫", "?123", "ABC" -> 1.3f
                else -> 1f
            }
            layoutParams = LinearLayout.LayoutParams(0, dp(50), weight).apply {
                setMargins(dp(4), 0, dp(4), 0)
            }
            setPadding(dp(2), dp(6), dp(2), dp(6))
            setOnClickListener { handleKeyPress(label) }
        }
    }

    private fun handleKeyPress(key: String) {
        val ic = currentInputConnection ?: return
        when (key) {
            "⌫" -> {
                if (currentTab == 1 && ::aiInput.isInitialized) {
                    val len = aiInput.text.length
                    if (len > 0) aiInput.text.delete(len - 1, len)
                } else {
                    ic.deleteSurroundingText(1, 0)
                }
            }
            "SHIFT" -> {
                when {
                    isCaps -> { isCaps = false; isShift = false }
                    isShift -> isCaps = true
                    else -> isShift = true
                }
                if (keyboardPanel.getChildAt(0) is LinearLayout) {
                    refreshKeyboardRows(this, keyboardPanel.getChildAt(0) as LinearLayout)
                }
            }
            "?123", "ABC" -> {
                isSymbol = !isSymbol
                isShift = false
                if (keyboardPanel.getChildAt(0) is LinearLayout) {
                    refreshKeyboardRows(this, keyboardPanel.getChildAt(0) as LinearLayout)
                }
            }
            "SPACE" -> {
                if (currentTab == 1 && ::aiInput.isInitialized) {
                    val start = aiInput.selectionStart
                    val end = aiInput.selectionEnd
                    aiInput.text.replace(start, end, " ")
                } else {
                    ic.commitText(" ", 1)
                }
            }
            "ENTER" -> {
                if (currentTab == 1 && ::aiInput.isInitialized) {
                    val start = aiInput.selectionStart
                    val end = aiInput.selectionEnd
                    aiInput.text.replace(start, end, "\n")
                } else {
                    ic.commitText("\n", 1)
                }
            }
            else -> {
                if (currentTab == 1 && ::aiInput.isInitialized) {
                    val start = aiInput.selectionStart
                    val end = aiInput.selectionEnd
                    aiInput.text.replace(start, end, key)
                } else {
                    ic.commitText(key, 1)
                }
                if (isShift && !isCaps) {
                    isShift = false
                    if (keyboardPanel.getChildAt(0) is LinearLayout) {
                        refreshKeyboardRows(this, keyboardPanel.getChildAt(0) as LinearLayout)
                    }
                }
            }
        }
    }

    // ========== USER-FRIENDLY ERROR ==========
    private fun getUserFriendlyErrorMessage(rawError: String, keyType: String): String {
        val errorText = rawError.lowercase()
        return when {
            errorText.contains("all api keys failed") -> "Maaf, layanan AI sedang sangat sibuk. Silakan coba lagi beberapa saat."
            errorText.contains("429") -> "Trafik padat, coba lagi nanti."
            errorText.contains("401") || errorText.contains("403") -> "Ada masalah teknis, tim kami sedang memperbaiki."
            errorText.contains("timeout") -> "Koneksi lambat, coba lagi dengan sinyal lebih baik."
            errorText.contains("network") -> "Tidak ada koneksi internet. Periksa jaringan Anda."
            else -> "Maaf, terjadi gangguan. Silakan coba lagi nanti."
        }
    }

    // ---------- LIMIT & PREMIUM ----------
    private fun checkAndShowLimit(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val remaining = prefs.getInt("remaining_quota", -1)
        if (remaining <= 0 && remaining != -1) {
            showStatus("Kuota harian habis. Hubungi admin untuk langganan (5k/hari, 15k/minggu, 30k/bulan).")
            return false
        }
        return true
    }

    private suspend fun resetDailyQuotaIfNeeded() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        if (prefs.getString(PREF_KEY_LAST_QUOTA_RESET, "") == today) return
        prefs.edit()
            .putString(PREF_KEY_LAST_QUOTA_RESET, today)
            .putInt("remaining_quota", DEFAULT_DAILY_QUOTA)
            .apply()
        Log.d(TAG, "Reset harian: kuota menjadi $DEFAULT_DAILY_QUOTA")
        FirebaseAuth.getInstance().currentUser?.let { user ->
            try {
                FirebaseFirestore.getInstance().collection("users").document(user.uid)
                    .update("remainingQuota", DEFAULT_DAILY_QUOTA).await()
            } catch (e: Exception) { Log.e(TAG, "Failed to sync reset quota: ${e.message}") }
        }
    }

    private suspend fun syncQuotaFromFirestore() {
        try {
            val user = FirebaseAuth.getInstance().currentUser ?: return
            val doc = FirebaseFirestore.getInstance().collection("users").document(user.uid).get().await()
            val remoteQuota = doc.getLong("remainingQuota")?.toInt() ?: DEFAULT_DAILY_QUOTA
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putInt("remaining_quota", remoteQuota).apply()
        } catch (e: Exception) { Log.e(TAG, "syncQuotaFromFirestore error: ${e.message}") }
    }

    private fun decrementRemainingQuota() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val current = prefs.getInt("remaining_quota", 0)
        if (current > 0) {
            val newVal = current - 1
            prefs.edit().putInt("remaining_quota", newVal).apply()
            scope.launch {
                FirebaseAuth.getInstance().currentUser?.let { user ->
                    try {
                        FirebaseFirestore.getInstance().collection("users").document(user.uid)
                            .update("remainingQuota", newVal).await()
                    } catch (e: Exception) { Log.e(TAG, "Failed to sync decrement: ${e.message}") }
                }
            }
        }
    }

    private suspend fun isUserPremium(): Boolean = withContext(Dispatchers.IO) {
        try {
            val user = FirebaseAuth.getInstance().currentUser ?: return@withContext false
            val doc = FirebaseFirestore.getInstance().collection("users").document(user.uid).get().await()
            if (!doc.exists()) return@withContext false
            val isPremium = doc.getBoolean("isPremium") ?: false
            if (!isPremium) return@withContext false
            val expiry = doc.getTimestamp("premiumExpiry")?.toDate()
            if (expiry == null) return@withContext true
            expiry.after(Date())
        } catch (e: Exception) { false }
    }

    private fun showStatus(msg: String) {
        aiStatus.text = msg
        aiStatus.visibility = View.VISIBLE
    }

    private fun handleAIQuery() {
        if (FirebaseAuth.getInstance().currentUser == null) {
            showStatus("Silakan login terlebih dahulu.")
            return
        }
        val question = aiInput.text.toString().trim()
        if (question.isEmpty()) {
            showStatus("Ketik pertanyaan dulu...")
            return
        }
        lastQuestion = question
        scope.launch {
            resetDailyQuotaIfNeeded()
            syncQuotaFromFirestore()
            val isPremium = isUserPremium()
            if (!isPremium && !checkAndShowLimit()) return@launch
            sendToAi(question, isPremium)
        }
    }

    private fun sendToAi(question: String, isPremium: Boolean = false) {
        showStatus("⏳ Memproses...")
        val mode = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString("keyboard_mode", "Essay") ?: "Essay"
        scope.launch {
            val result = callAIWithFallback(question, mode)
            withContext(Dispatchers.Main) {
                if (result.startsWith("Error:")) {
                    showStatus(getUserFriendlyErrorMessage(result, "AI"))
                } else {
                    if (!isPremium) decrementRemainingQuota()
                    lastAnswer = result
                    aiStatus.visibility = View.GONE
                    switchTab(2)
                }
            }
        }
    }

    // ---------- WEIGHTED RANDOM API FALLBACK ----------
    private suspend fun callAIWithFallback(question: String, mode: String): String {
        // Salin daftar berbobot untuk request ini (akan diubah jika ada endpoint gagal)
        val candidates = WEIGHTED_ENDPOINTS.toMutableList()
        Log.i(TAG, "Starting API call with ${candidates.size} weighted candidates (Q: ${question.take(50)})")
        var attemptCount = 0
        while (candidates.isNotEmpty()) {
            attemptCount++
            // Pilih endpoint secara acak (dengan bobot) dari daftar kandidat
            val idx = Random.nextInt(candidates.size)
            val endpoint = candidates[idx]
            Log.d(TAG, "Attempt $attemptCount: Using ${endpoint.type} (key=${endpoint.key.take(15)}...)")
            val result = performApiRequest(endpoint, question, mode)
            if (result != null && !result.startsWith("Error:")) {
                Log.i(TAG, "✓ Success from ${endpoint.type} after $attemptCount attempts")
                return result
            } else {
                // Hapus endpoint yang gagal untuk request ini (agar tidak dicoba lagi)
                candidates.removeAt(idx)
                Log.w(TAG, "✗ ${endpoint.type} failed: ${result?.take(30)}, remaining: ${candidates.size}")
            }
        }
        Log.e(TAG, "✗ All API keys failed after $attemptCount attempts!")
        return "Error: All API keys failed."
    }

    private suspend fun performApiRequest(endpoint: ApiEndpoint, question: String, mode: String): String? {
        val systemPrompt = if (mode == "PG") "Jawab HANYA dengan satu huruf: A, B, C, atau D. Tidak perlu penjelasan."
                          else "Berikan jawaban yang lengkap dan jelas dalam Bahasa Indonesia."
        val model = if (endpoint.type == "DeepSeek") "deepseek-chat" else "llama-3.3-70b-versatile"

        // Validate API key
        if (endpoint.key.startsWith("BUILD_")) {
            Log.e(TAG, "❌ INVALID KEY DETECTED: ${endpoint.key} (placeholder not replaced!)")
            return "Error: placeholder_key"
        }

        val json = JSONObject().apply {
            put("model", model)
            put("messages", org.json.JSONArray().apply {
                put(JSONObject().apply { put("role", "system"); put("content", systemPrompt) })
                put(JSONObject().apply { put("role", "user"); put("content", question) })
            })
            put("max_tokens", if (mode == "PG") 10 else 500)
            put("temperature", 0.3)
        }

        val url = "${endpoint.baseUrl}/chat/completions"
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer ${endpoint.key}")
            .addHeader("Content-Type", "application/json")
            .post(json.toString().toRequestBody("application/json".toMediaType()))
            .build()

        return try {
            Log.d(TAG, "→ Calling ${endpoint.type} at $url (model=$model)")
            val response = client.newCall(request).execute()
            val body = response.body?.string() ?: ""
            if (response.isSuccessful) {
                var answer = JSONObject(body).getJSONArray("choices")
                    .getJSONObject(0).getJSONObject("message").getString("content").trim()
                if (mode == "PG") {
                    val firstValid = answer.uppercase().firstOrNull { it in 'A'..'D' }
                    answer = if (firstValid != null) firstValid.toString() else "?"
                }
                Log.d(TAG, "← Got response from ${endpoint.type}: ${answer.take(50)}...")
                answer
            } else {
                val errorMsg = when (response.code) {
                    429, 503 -> "rate_limit"
                    401, 403 -> "auth_failed (key invalid?)"
                    else -> response.code.toString()
                }
                Log.w(TAG, "✗ ${endpoint.type} returned ${response.code}: $errorMsg. Body: ${body.take(100)}")
                "Error: $errorMsg"
            }
        } catch (e: java.net.SocketTimeoutException) {
            Log.w(TAG, "✗ ${endpoint.type} timeout: ${e.message}")
            "Error: timeout"
        } catch (e: java.io.IOException) {
            Log.w(TAG, "✗ ${endpoint.type} network error: ${e.message}")
            "Error: network"
        } catch (e: Exception) {
            Log.e(TAG, "✗ ${endpoint.type} exception: ${e.message}", e)
            "Error: ${e.message}"
        }
    }

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}