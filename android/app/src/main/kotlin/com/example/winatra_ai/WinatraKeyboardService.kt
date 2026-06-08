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
import kotlinx.coroutines.tasks.await          // <--- TAMBAHKAN INI
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.Date                         // <--- TAMBAHKAN INI

class WinatraKeyboardService : InputMethodService() {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    private var isShift = false
    private var isCaps = false
    private var isSymbol = false
    private var currentTab = 0 // 0: ketik, 1: tanya AI, 2: baca

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
        // 20 API keys - akan diganti oleh GitHub Actions saat build
        private val GROQ_API_KEYS = arrayOf(
            "BUILD_GROQ_KEY_1",
            "BUILD_GROQ_KEY_2",
            "BUILD_GROQ_KEY_3",
            "BUILD_GROQ_KEY_4",
            "BUILD_GROQ_KEY_5",
            "BUILD_GROQ_KEY_6",
            "BUILD_GROQ_KEY_7",
            "BUILD_GROQ_KEY_8",
            "BUILD_GROQ_KEY_9",
            "BUILD_GROQ_KEY_10",
            "BUILD_GROQ_KEY_11",
            "BUILD_GROQ_KEY_12",
            "BUILD_GROQ_KEY_13",
            "BUILD_GROQ_KEY_14",
            "BUILD_GROQ_KEY_15",
            "BUILD_GROQ_KEY_16",
            "BUILD_GROQ_KEY_17",
            "BUILD_GROQ_KEY_18",
            "BUILD_GROQ_KEY_19",
            "BUILD_GROQ_KEY_20"
        )
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
            }
            2 -> {
                aiInputBar.visibility = View.GONE
                keyboardPanel.visibility = View.GONE
                readPanel.visibility = View.VISIBLE
                if (lastAnswer.isNotEmpty()) {
                    readAnswer.text = lastAnswer
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
                if (currentTab == 1) {
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
                refreshKeyboardRows(this, keyboardPanel.getChildAt(0) as LinearLayout)
            }
            "?123", "ABC" -> {
                isSymbol = !isSymbol
                isShift = false
                refreshKeyboardRows(this, keyboardPanel.getChildAt(0) as LinearLayout)
            }
            "SPACE" -> {
                if (currentTab == 1) {
                    val start = aiInput.selectionStart
                    val end = aiInput.selectionEnd
                    aiInput.text.replace(start, end, " ")
                } else {
                    ic.commitText(" ", 1)
                }
            }
            "ENTER" -> {
                if (currentTab == 1) {
                    val start = aiInput.selectionStart
                    val end = aiInput.selectionEnd
                    aiInput.text.replace(start, end, "\n")
                } else {
                    ic.commitText("\n", 1)
                }
            }
            else -> {
                if (currentTab == 1) {
                    val start = aiInput.selectionStart
                    val end = aiInput.selectionEnd
                    aiInput.text.replace(start, end, key)
                } else {
                    ic.commitText(key, 1)
                }
                if (isShift && !isCaps) {
                    isShift = false
                    refreshKeyboardRows(this, keyboardPanel.getChildAt(0) as LinearLayout)
                }
            }
        }
    }

    // ========== USER-FRIENDLY ERROR HANDLING ==========
    private fun getUserFriendlyErrorMessage(rawError: String): String {
        return when {
            rawError.contains("All Groq keys exhausted") -> "Layanan AI sedang sangat sibuk. Silakan coba lagi dalam beberapa menit."
            rawError.contains("409") || rawError.contains("Conflict") -> "Trafik ramai, coba lagi."
            rawError.contains("429") || rawError.contains("rate") -> "Layanan padat, coba lagi sebentar."
            rawError.contains("503") -> "Layanan AI sedang maintenance. Coba lagi nanti."
            rawError.contains("500") || rawError.contains("502") || rawError.contains("504") -> "Layanan sedang bermasalah. Tim kami sedang memperbaiki."
            rawError.contains("401") || rawError.contains("403") -> "Ada masalah teknis. Tim kami akan segera memperbaiki."
            rawError.contains("timeout") || rawError.contains("Timeout") -> "Koneksi lambat, coba lagi dengan sinyal yang lebih baik."
            rawError.contains("no internet") || rawError.contains("Network") || rawError.contains("UnknownHostException") -> "Tidak ada koneksi internet. Periksa jaringan Anda."
            else -> "Maaf, terjadi gangguan. Silakan coba beberapa saat lagi."
        }
    }
    // ========== END USER-FRIENDLY ==========

    private fun handleAIQuery() {
        val question = aiInput.text.toString().trim()
        if (question.isEmpty()) {
            showStatus("Ketik pertanyaan dulu...")
            return
        }
        lastQuestion = question
        scope.launch {
            // CEK PREMIUM DAN LIMIT
            val isPremium = isUserPremium()
            if (!isPremium) {
                if (!checkAndShowLimit()) return@launch
            } else {
                Log.d(TAG, "User is premium, skipping limit check")
            }
            sendToGroq(question, isPremium)
        }
    }

    private fun checkAndShowLimit(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val remaining = prefs.getInt("remaining_quota", -1)
        Log.d(TAG, "checkAndShowLimit: remaining = $remaining")
        if (remaining == -1) return true
        if (remaining <= 0) {
            showStatus("Maaf, lalu lintas sedang padat. Coba lagi nanti atau upgrade premium.")
            return false
        }
        return true
    }

    private fun decrementRemainingQuota() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val current = prefs.getInt("remaining_quota", 0)
        if (current > 0) {
            prefs.edit().putInt("remaining_quota", current - 1).apply()
            Log.d(TAG, "decrementRemainingQuota: $current -> ${current - 1}")
        }
    }

    private suspend fun isUserPremium(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val user = FirebaseAuth.getInstance().currentUser
                if (user == null) {
                    Log.d(TAG, "isUserPremium: No logged in user")
                    return@withContext false
                }

                val db = FirebaseFirestore.getInstance()
                val doc = db.collection("users").document(user.uid).get().await()
                if (!doc.exists()) {
                    Log.d(TAG, "isUserPremium: User document not found")
                    return@withContext false
                }

                val isPremiumFlag = doc.getBoolean("isPremium") ?: false
                if (!isPremiumFlag) {
                    return@withContext false
                }

                val premiumExpiry = doc.getTimestamp("premiumExpiry")?.toDate()
                if (premiumExpiry == null) {
                    Log.d(TAG, "isUserPremium: Premium without expiry = unlimited")
                    return@withContext true
                }

                val isValid = premiumExpiry.after(Date())
                Log.d(TAG, "isUserPremium: isPremium=$isPremiumFlag, expiryValid=$isValid")
                return@withContext isValid
            } catch (e: Exception) {
                Log.e(TAG, "isUserPremium: Error checking premium status: ${e.message}")
                return@withContext false
            }
        }
    }

    private fun showStatus(msg: String) {
        aiStatus.text = msg
        aiStatus.visibility = View.VISIBLE
    }

    private fun sendToGroq(question: String, isPremium: Boolean = false) {
        showStatus("⏳ Memproses...")
        val mode = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString("keyboard_mode", "Essay") ?: "Essay"
        scope.launch {
            val result = callGroqWithFallback(question, mode)
            withContext(Dispatchers.Main) {
                // Cek apakah result adalah error
                if (result.startsWith("Error:")) {
                    // Gagal total, tampilkan pesan ramah, jangan kurangi kuota
                    val friendlyMsg = getUserFriendlyErrorMessage(result)
                    showStatus(friendlyMsg)
                } else {
                    // Sukses, kurangi kuota jika tidak premium dan simpan jawaban
                    if (!isPremium) {
                        decrementRemainingQuota()
                    }
                    lastAnswer = result
                    aiStatus.visibility = View.GONE
                    switchTab(2)
                }
            }
        }
    }

    private fun callGroqWithFallback(question: String, mode: String): String {
        for (apiKey in GROQ_API_KEYS) {
            val result = performGroqRequest(apiKey, question, mode)
            // Jika result tidak diawali "Error:", berarti sukses
            if (result != null && !result.startsWith("Error:")) {
                return result
            } else {
                Log.w(TAG, "Groq API key failed: $result, trying next")
            }
        }
        return "Error: All Groq keys exhausted."
    }

    private fun performGroqRequest(apiKey: String, question: String, mode: String): String? {
        val systemPrompt = if (mode == "PG")
            "Jawab HANYA dengan satu huruf: A, B, C, atau D. Tidak perlu penjelasan."
        else
            "Berikan jawaban yang lengkap dan jelas dalam Bahasa Indonesia."

        val json = JSONObject().apply {
            put("model", "llama-3.3-70b-versatile")
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
            .url("https://api.groq.com/openai/v1/chat/completions")
            .addHeader("Authorization", "Bearer $apiKey")
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
                // Kembalikan error dengan prefix "Error:" + kode
                "Error: ${response.code}"
            }
        } catch (e: Exception) {
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