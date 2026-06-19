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
import kotlin.random.Random

class WinatraService : Service() {

    companion object {
        const val CHANNEL_ID = "winatra_channel"
        const val RESULT_CHANNEL_ID = "winatra_result_channel"
        const val NOTIF_ID = 1
        const val RESULT_NOTIF_ID = 100
        const val ACTION_ANSWER = "ACTION_ANSWER"
        const val ACTION_CHANGE_MODE = "ACTION_CHANGE_MODE"
        const val ACTION_CLIPBOARD_RESULT = "CLIPBOARD_RESULT"
        const val ACTION_ACCESSIBILITY_RESULT = "ACCESSIBILITY_RESULT"
        const val ACTION_EXPLAIN = "ACTION_EXPLAIN"
        const val ACTION_COPY_ANSWER = "ACTION_COPY_ANSWER"
        const val PREFS_NAME = "winatra_prefs"
        const val KEY_MODE = "mode"
        const val PREF_KEY_LAST_QUOTA_RESET = "last_quota_reset"
        const val DEFAULT_DAILY_QUOTA = 8
        const val TAG = "WinatraService"
        const val DEEPSEEK_WEIGHT = 96   // Bobot untuk DeepSeek (96 dari total 120 = 80%)

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

        // ========== SPECIALIZATION PROMPTS MAPPING ==========
        private val SPECIALIZATION_PROMPTS = mapOf(
            "general" to "Anda adalah asisten AI yang membantu menjawab pertanyaan dengan jelas, akurat, dan mendalam.",
            // Mata Kuliah Universitas
            "fisika" to "Anda adalah ahli Fisika berpengalaman. Jawab dengan rumus yang relevan, penjelasan konsep yang mendalam, dan contoh aplikasi nyata. Sertakan satuan dan dimensi ketika diperlukan.",
            "kimia" to "Anda adalah ahli Kimia berpengalaman. Jelaskan dengan persamaan reaksi, struktur molekul, dan mekanisme reaksi. Berikan contoh praktis dalam kehidupan sehari-hari.",
            "biologi" to "Anda adalah ahli Biologi berpengalaman. Jelaskan proses biologis dengan detail, sertakan nama-nama ilmiah (Latin), dan contoh organisme konkret. Bahas mekanisme sel dan genetika jika relevan.",
            "matematika" to "Anda adalah tutor Matematika berpengalaman. Berikan solusi langkah demi langkah, tunjukkan setiap proses perhitungan, dan jelaskan konsep dasarnya. Sertakan visualisasi atau contoh numerik.",
            "statistika" to "Anda adalah ahli Statistika. Jelaskan dengan konsep probabilitas, distribusi, dan metode analisis. Gunakan notasi statistik yang tepat dan berikan contoh penerapan data real.",
            "ilmu_komputer" to "Anda adalah ahli Ilmu Komputer. Jelaskan dengan algoritma, kompleksitas waktu (Big O), pseudocode, dan contoh implementasi. Bahas best practices dan trade-offs.",
            "teknik_sipil" to "Anda adalah insinyur Teknik Sipil berpengalaman. Jelaskan dengan prinsip struktur, beban, material, dan standar konstruksi Indonesia. Sertakan perhitungan teknis jika relevan.",
            "teknik_elektro" to "Anda adalah insinyur Teknik Elektro. Jelaskan dengan rangkaian listrik, tegangan, arus, frekuensi, dan teori Thevenin-Norton jika relevan. Gunakan diagram skematik mental.",
            "teknik_mesin" to "Anda adalah insinyur Teknik Mesin. Jelaskan dengan prinsip mekanika, termodinamika, keseimbangan gaya, dan material properties. Sertakan perhitungan kekuatan bahan jika perlu.",
            "hukum" to "Anda adalah praktisi Hukum Indonesia berpengalaman. Jawab berdasarkan peraturan perundang-undangan, kasus preseden, dan asas-asas hukum. Sebutkan pasal dan sumber peraturan yang relevan.",
            "ekonomi" to "Anda adalah ekonom berpengalaman. Jelaskan dengan teori mikro-makro, penawaran-permintaan, elastisitas, dan contoh ekonomi Indonesia. Bahas dampak kebijakan nyata.",
            "akuntansi" to "Anda adalah akuntan profesional. Jelaskan dengan prinsip debit-kredit, jurnal, buku besar, dan laporan keuangan sesuai standar PSAK. Sertakan jurnal contoh jika relevan.",
            "manajemen" to "Anda adalah manajer berpengalaman. Jelaskan dengan fungsi manajemen (planning, organizing, leading, controlling), teori organisasi, dan best practices industri.",
            "psikologi" to "Anda adalah psikolog berpengalaman. Jelaskan dengan teori psikologi, penelitian empiris, dan aplikasi praktis. Sebutkan tokoh psikolog yang relevan dan teori mereka.",
            "sosiologi" to "Anda adalah sosiolog berpengalaman. Jelaskan dengan teori sosial, struktur masyarakat, interaksi sosial, dan konteks budaya Indonesia.",
            "filsafat" to "Anda adalah filsuf berpengalaman. Jelaskan dengan argumen logis, contoh pemikiran dari berbagai aliran filsafat, dan implikasi filosofis.",
            "sejarah" to "Anda adalah sejarawan berpengalaman. Jelaskan dengan konteks historis, fakta akurat, kronologi, dan analisis sebab-akibat. Sertakan tokoh sejarah relevan.",
            "geografi" to "Anda adalah ahli Geografi. Jelaskan dengan aspek fisik (alam) dan sosial (manusia), lokasi, peta mental, iklim, dan dampak geografis.",
            "linguistik" to "Anda adalah ahli Linguistik. Jelaskan dengan teori bahasa, struktur gramatika, semantik, dan fonologi. Berikan contoh analisis bahasa konkret.",
            "sastra" to "Anda adalah kritikus sastra berpengalaman. Jelaskan dengan analisis teks, gaya bahasa, makna filosofis, dan konteks budaya pengarang.",
            "pendidikan" to "Anda adalah pendidik berpengalaman. Jelaskan dengan teori belajar, metode mengajar, kurikulum, dan pedagogis yang efektif.",
            "kesehatan_masyarakat" to "Anda adalah ahli Kesehatan Masyarakat. Jelaskan dengan epidemiologi, pencegahan penyakit, promosi kesehatan, dan kebijakan kesehatan.",
            "kedokteran" to "Anda adalah dokter berpengalaman. Jawab dengan patofisiologi, diagnosis diferensial, terapi farmakologi, dan evidence-based medicine. CATATAN: Konsultasi dokter sungguhan untuk diagnosis nyata.",
            "farmasi" to "Anda adalah apoteker berpengalaman. Jelaskan dengan farmakokinetik, farmakodinamik, indikasi obat, efek samping, dan interaksi obat.",
            "keperawatan" to "Anda adalah perawat berpengalaman. Jelaskan dengan asuhan keperawatan, standar perawatan, asepsis, dan patient care.",
            "arsitektur" to "Anda adalah arsitek berpengalaman. Jelaskan dengan desain ruang, estetika, fungsi bangunan, material, dan standar desain Indonesia.",
            "seni_rupa" to "Anda adalah seniman dan kritikus seni rupa. Jelaskan dengan teori seni, elemen desain, teknik, aliran seni, dan konteks budaya.",
            "desain_komunikasi_visual" to "Anda adalah desainer komunikasi visual berpengalaman. Jelaskan dengan prinsip desain, tipografi, warna, layout, dan psikologi visual.",
            "hubungan_internasional" to "Anda adalah ahli Hubungan Internasional. Jelaskan dengan teori HI, kebijakan luar negeri, diplomasi, dan dinamika global.",
            "ilmu_politik" to "Anda adalah ahli Ilmu Politik. Jelaskan dengan teori politik, sistem pemerintahan, kepemimpinan, dan dinamika kekuasaan.",
            "komunikasi" to "Anda adalah ahli Komunikasi. Jelaskan dengan teori komunikasi, proses komunikasi, media massa, dan strategi komunikasi.",
            "jurnalistik" to "Anda adalah jurnalis berpengalaman. Jelaskan dengan kode etik jurnalistik, penulisan berita, investigasi, dan newsworthiness.",

            // Mata Pelajaran SMA/SMP/SD
            "matematika_wajib" to "Anda adalah guru Matematika Wajib berpengalaman. Jelaskan dengan konsep dasar, rumus, dan contoh soal berlevel SMA. Berikan langkah solusi yang mudah dipahami.",
            "matematika_peminatan" to "Anda adalah guru Matematika Peminatan berpengalaman. Jelaskan kalkulus, trigonometri lanjut, atau aljabar dengan detail dan contoh aplikasi.",
            "fisika_sma" to "Anda adalah guru Fisika SMA berpengalaman. Jelaskan dengan rumus, diagram gaya, dan contoh fenomena sehari-hari yang mudah dipahami siswa.",
            "kimia_sma" to "Anda adalah guru Kimia SMA berpengalaman. Jelaskan dengan persamaan reaksi, struktur atom, dan eksperimen laboratorium level SMA.",
            "biologi_sma" to "Anda adalah guru Biologi SMA berpengalaman. Jelaskan dengan mekanisme biologi, ekosistem, dan contoh organisme konkret yang mudah dipahami.",
            "ekonomi_sma" to "Anda adalah guru Ekonomi SMA berpengalaman. Jelaskan dengan penawaran-permintaan, konsumsi, produksi, dan ekonomi Indonesia level SMA.",
            "geografi_sma" to "Anda adalah guru Geografi SMA berpengalaman. Jelaskan dengan peta, lokasi, iklim, dan fenomena geografis dengan contoh konkret.",
            "sejarah_sma" to "Anda adalah guru Sejarah SMA berpengalaman. Jelaskan dengan kronologi, tokoh sejarah, dan dampak peristiwa dengan analisis yang mudah dipahami.",
            "sosiologi_sma" to "Anda adalah guru Sosiologi SMA berpengalaman. Jelaskan dengan struktur sosial, interaksi masyarakat, dan dinamika budaya.",
            "antropologi_sma" to "Anda adalah guru Antropologi SMA berpengalaman. Jelaskan dengan budaya, tradisi, etnis, dan keragaman budaya Indonesia.",
            "bahasa_indonesia" to "Anda adalah guru Bahasa Indonesia berpengalaman. Jelaskan dengan tata bahasa, puisi, prosa, analisis teks, dan EYD yang benar.",
            "bahasa_inggris" to "Anda adalah guru Bahasa Inggris berpengalaman. Jelaskan dengan grammar, vocabulary, pronunciation, dan contoh dialog sehari-hari.",
            "bahasa_arab" to "Anda adalah guru Bahasa Arab berpengalaman. Jelaskan dengan kaidah Bahasa Arab, vocabulary, dan contoh kalimat level SMA.",
            "pkn" to "Anda adalah guru PKN berpengalaman. Jelaskan dengan nilai-nilai Pancasila, UUD 1945, hak-kewajiban warga negara, dan sistem pemerintahan.",
            "agama_islam" to "Anda adalah guru Agama Islam berpengalaman. Jelaskan dengan ayat Al-Quran, hadis, akidah, ibadah, akhlak, dan hukum Islam.",
            "agama_kristen" to "Anda adalah guru Agama Kristen berpengalaman. Jelaskan dengan Alkitab, teologi Kristen, dan ajaran iman Kristen.",
            "agama_katolik" to "Anda adalah guru Agama Katolik berpengalaman. Jelaskan dengan Alkitab, katekismus, dan ajaran Gereja Katolik.",
            "agama_hindu" to "Anda adalah guru Agama Hindu berpengalaman. Jelaskan dengan Weda, Upanisad, dan filosofi Hindu.",
            "agama_buddha" to "Anda adalah guru Agama Buddha berpengalaman. Jelaskan dengan Tri Pitaka, Empat Kebenaran Mulia, dan ajaran Buddha.",
            "seni_budaya" to "Anda adalah guru Seni Budaya berpengalaman. Jelaskan dengan seni rupa, musik, tari, teater, dan warisan budaya Indonesia.",
            "prakarya" to "Anda adalah guru Prakarya berpengalaman. Jelaskan dengan teknik kerajinan, rekayasa, budi daya, dan proses produksi level SMA.",
            "pjok" to "Anda adalah guru PJOK berpengalaman. Jelaskan dengan teknik olahraga, kebugaran, kesehatan, dan peraturan permainan.",
            "informatika_tik" to "Anda adalah guru Informatika/TIK berpengalaman. Jelaskan dengan dasar komputer, pemrograman level pemula, dan literasi digital.",
            "kewirausahaan" to "Anda adalah guru Kewirausahaan berpengalaman. Jelaskan dengan peluang bisnis, rencana usaha, dan jiwa entrepreneur."
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
        createNotificationChannels()
        setupClipboardListener()
        showPersistentNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
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
                    Toast.makeText(this, "Jawaban disalin", Toast.LENGTH_SHORT).show()
                }
            }
            ACTION_ACCESSIBILITY_RESULT -> {
                val text = intent.getStringExtra("accessibility_text") ?: ""
                processAccessibilityText(text)
            }
            "SET_AUTO_SOLVE" -> {
                updateAutoSolve(intent.getBooleanExtra("enabled", false))
                showPersistentNotification()
            }
            "SYNC_MODE" -> {
                setMode(intent.getStringExtra("mode") ?: getMode())
                showPersistentNotification()
            }
            "SET_OFFLINE_MODE" -> {
                setOfflineMode(intent.getBooleanExtra("enabled", false))
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
            manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Winatra AI Service", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Winatra AI Shortcut Service"
                setShowBadge(false)
            })
            manager.createNotificationChannel(NotificationChannel(RESULT_CHANNEL_ID, "Winatra AI Jawaban", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Notifikasi hasil jawaban AI"
                setShowBadge(true)
                enableVibration(true)
                setSound(null, null)
            })
        }
    }

    private fun getMode() = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(KEY_MODE, "Essay") ?: "Essay"
    private fun setMode(mode: String) = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit().putString(KEY_MODE, mode).apply()
    private fun isOfflineMode() = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getBoolean("offline_mode_enabled", false)
    private fun setOfflineMode(enabled: Boolean) = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit().putBoolean("offline_mode_enabled", enabled).apply()
    
    private fun toggleMode() {
        val current = getMode()
        setMode(if (current == "Essay") "PG" else "Essay")
        showPersistentNotification()
    }

    private fun setupClipboardListener() {
        autoSolveEnabled = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getBoolean("auto_solve", false)
        clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
            if (autoSolveEnabled) {
                try {
                    val text = (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).primaryClip?.getItemAt(0)?.text?.toString()?.trim() ?: ""
                    if (text.isNotEmpty() && text.endsWith("?")) {
                        startActivity(Intent(this, ClipboardActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        })
                    }
                } catch (e: Exception) { Log.e(TAG, "Clipboard error", e) }
            }
        }
        (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).addPrimaryClipChangedListener(clipboardListener)
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
            .addAction(0, "Ganti Mode", PendingIntent.getService(this, 1, Intent(this, WinatraService::class.java).apply { action = ACTION_CHANGE_MODE }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .addAction(0, "Jawab", PendingIntent.getActivity(this, 0, Intent(this, ClipboardActivity::class.java).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .addAction(android.R.drawable.ic_menu_send, "Tanya", PendingIntent.getActivity(this, 3, Intent(this, ClipboardActivity::class.java).apply { putExtra("mode", "ask") }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .build()
        startForeground(NOTIF_ID, notification)
    }

    private fun showResultNotification(title: String, body: String, withExplain: Boolean = false, question: String = "", answer: String = "") {
        val builder = NotificationCompat.Builder(this, RESULT_CHANNEL_ID)
            .setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(android.R.drawable.ic_dialog_info).setAutoCancel(true)
        if (withExplain && question.isNotEmpty() && answer.isNotEmpty()) {
            builder.addAction(0, "Kenapa?", PendingIntent.getService(this, 2, Intent(this, WinatraService::class.java).apply {
                action = ACTION_EXPLAIN
                putExtra("question", question)
                putExtra("answer", answer)
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(RESULT_NOTIF_ID, builder.build())
    }

    // ---------- LIMIT & PREMIUM (kuota gratis 7) ----------
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
            } catch (e: Exception) { Log.e(TAG, "Firestore sync failed", e) }
        }
    }

    private fun decrementRemainingQuota() {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val current = prefs.getInt("remaining_quota", 0)
        if (current > 0) {
            prefs.edit().putInt("remaining_quota", current - 1).apply()
            scope.launch { syncRemainingQuotaToFirestore(current - 1) }
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
            expiry == null || expiry.after(Date())
        } catch (e: Exception) { false }
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
        // Baca specialization dari SharedPreferences
        val specialization = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .getString("user_specialization", "general") ?: "general"
        
        // Ambil prompt spesialisasi dari mapping (fallback ke "general" jika tidak ditemukan)
        val specializationPrompt = SPECIALIZATION_PROMPTS[specialization] 
            ?: SPECIALIZATION_PROMPTS["general"]!!
        
        // Buat system prompt final
        val systemPrompt = if (mode == "PG") {
            "Jawab HANYA dengan satu huruf: A, B, C, atau D. Tidak perlu penjelasan."
        } else {
            "$specializationPrompt\n\nBerikan jawaban yang lengkap dan jelas dalam Bahasa Indonesia."
        }
        
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
            Log.d(TAG, "→ Calling ${endpoint.type} at $url (model=$model, specialization=$specialization)")
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

    // ---------- EXPLANATION (sama dengan weighted random) ----------
    private suspend fun callExplanationWithFallback(question: String, answer: String): String {
        val candidates = WEIGHTED_ENDPOINTS.toMutableList()
        while (candidates.isNotEmpty()) {
            val idx = Random.nextInt(candidates.size)
            val endpoint = candidates[idx]
            val result = performExplanationRequest(endpoint, question, answer)
            if (result != null && !result.startsWith("Error:")) {
                return result
            } else {
                candidates.removeAt(idx)
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

    // ---------- PROSES UTAMA ----------
    private fun processClipboardResult(question: String, modeType: String = "answer") {
        if (FirebaseAuth.getInstance().currentUser == null) {
            showResultNotification("Winatra AI", "Silakan login terlebih dahulu.")
            return
        }
        if (question.isEmpty()) {
            showResultNotification("Winatra AI", "Clipboard kosong! Salin pertanyaan dulu.")
            return
        }
        
        // Cek offline mode
        val isOffline = isOfflineMode()
        
        if (isOffline) {
            // Mode offline - tampilkan notifikasi untuk membuka app
            showOfflineNotification(question, modeType)
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
                        (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                            .setPrimaryClip(android.content.ClipData.newPlainText("answer", answer))
                        showResultNotification("Jawaban Essay", "Jawaban disalin ke clipboard!")
                    }
                }
            }
        }
    }

    private fun showOfflineNotification(question: String, modeType: String) {
        val shortQuestion = question.take(60) + if (question.length > 60) "..." else ""
        val builder = NotificationCompat.Builder(this, RESULT_CHANNEL_ID)
            .setContentTitle("🔒 Mode Offline Aktif")
            .setContentText("Tanya: $shortQuestion")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Buka app untuk menjawab dengan AI lokal + dokumen Anda.\n\nPertanyaan: $question"))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this, 
                    (System.currentTimeMillis() % 10000).toInt(),
                    Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        putExtra("offline_question", question)
                        putExtra("open_offline_screen", true)
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(RESULT_NOTIF_ID + 2, builder.build())
    }

    private fun processAccessibilityText(text: String) {
        if (FirebaseAuth.getInstance().currentUser == null) {
            showResultNotification("Winatra AI", "Silakan login terlebih dahulu.")
            return
        }
        if (text.isBlank()) {
            showResultNotification("Winatra AI", "Tidak ada teks yang dapat dibaca.")
            return
        }
        showResultNotification("Winatra AI", "⏳ Memproses teks aksesibilitas...")
        scope.launch {
            resetDailyQuotaIfNeeded()
            val isPremium = isUserPremium()
            if (!isPremium && !checkAndShowLimit()) return@launch
            val answer = callAIWithFallback(text, getMode())
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
                showResultNotification("Jawaban Asisten Belajar", answer)
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
            .addAction(0, "Salin", PendingIntent.getService(this, 4, Intent(this, WinatraService::class.java).apply {
                action = ACTION_COPY_ANSWER
                putExtra("answer", answer)
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(RESULT_NOTIF_ID + 1, builder.build())
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