package com.example.winatra_ai

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.graphics.drawable.ColorStateList
import android.inputmethodservice.InputMethodService
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.*
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
        const val DEEPSEEK_WEIGHT = 96

        data class ApiEndpoint(val key: String, val baseUrl: String, val type: String)

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

        private val WEIGHTED_ENDPOINTS: List<ApiEndpoint> by lazy {
            val deepseek = API_ENDPOINTS.first { it.type == "DeepSeek" }
            val groqs = API_ENDPOINTS.filter { it.type == "Groq" }
            List(DEEPSEEK_WEIGHT) { deepseek } + groqs
        }

        // ========== SPECIALIZATION PROMPTS MAPPING (SAMA SEPERTI WinatraService.kt) ==========
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

        val ROWS_LOWER = arrayOf(
            arrayOf("q","w","e","r","t","y","u","i","o","p"),
            arrayOf("a","s","d","f","g","h","j","k","l"),
            arrayOf("⇧","z","x","c","v","b","n","m","⌫"),     // IMPROVED: SHIFT -> ⇧
            arrayOf("?123", ",", "space", ".", "↩")            // IMPROVED: SPACE -> space, ENTER -> ↩
        )
        val ROWS_UPPER = arrayOf(
            arrayOf("Q","W","E","R","T","Y","U","I","O","P"),
            arrayOf("A","S","D","F","G","H","J","K","L"),
            arrayOf("⇪","Z","X","C","V","B","N","M","⌫"),     // IMPROVED: CAPS LOCK ⇪
            arrayOf("?123", ",", "space", ".", "↩")
        )
        val ROWS_SYMBOL = arrayOf(
            arrayOf("1","2","3","4","5","6","7","8","9","0"),
            arrayOf("@","#","$","%","&","-","+","(",")","/"),
            arrayOf("*","\"","'",":",";","!","?","⌫"),
            arrayOf("ABC", ",", "space", ".", "↩")
        )

        // IMPROVED: Warna tema keyboard
        const val COLOR_KEY_BG        = "#2C2C2E"   // tombol huruf/angka
        const val COLOR_KEY_FUNC      = "#3D3D3F"   // tombol fungsi
        const val COLOR_KEY_ACTION    = "#0A84FF"   // tombol Enter / aksen biru
        const val COLOR_KEY_PRESSED   = "#4A4A4C"   // efek tekan
        const val COLOR_KEY_TEXT      = "#FFFFFF"
        const val COLOR_KB_BG         = "#131315"   // background keyboard lebih gelap
        const val COLOR_TAB_BG        = "#1C1C1E"
        const val COLOR_TAB_ACTIVE_BG = "#2C2C2E"
        const val COLOR_PANEL_BG      = "#1C1C1E"
        const val COLOR_INPUT_BG      = "#2C2C2E"
        const val COLOR_HINT          = "#636366"
        const val COLOR_SUBTEXT       = "#8E8E93"
        const val COLOR_TEXT_MAIN     = "#EBEBF5"
    }

    override fun onCreateInputView(): View {
        val ctx = this

        rootView = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor(COLOR_KB_BG))
        }

        // IMPROVED: Tab bar lebih bersih
        tabBar = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor(COLOR_TAB_BG))
        }
        tabBar.addView(buildTabBtn(ctx, "⌨", "Ketik", 0))
        tabBar.addView(buildTabBtn(ctx, "✦", "Tanya AI", 1))   // IMPROVED: ikon lebih rapi
        tabBar.addView(buildTabBtn(ctx, "📖", "Baca", 2))
        rootView.addView(tabBar)

        aiInputBar = buildAIInputBar(ctx).apply { visibility = View.GONE }
        rootView.addView(aiInputBar)

        keyboardPanel = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor(COLOR_KB_BG))
        }
        buildKeyboardRows(ctx)
        rootView.addView(keyboardPanel)

        readPanel = buildReadPanel(ctx).apply { visibility = View.GONE }
        rootView.addView(readPanel)

        return rootView
    }

    // IMPROVED: Tab button dengan desain lebih bersih
    private fun buildTabBtn(ctx: Context, icon: String, label: String, index: Int): LinearLayout {
        val container = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setPadding(0, dp(10), 0, dp(10))
            setBackgroundColor(if (currentTab == index) Color.parseColor(COLOR_TAB_ACTIVE_BG) else Color.TRANSPARENT)
            tag = "tab_$index"
            setOnClickListener { switchTab(index) }
        }
        // IMPROVED: indicator garis atas saat aktif
        val indicator = View(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(dp(32), dp(2))
            setBackgroundColor(if (currentTab == index) Color.parseColor(COLOR_KEY_ACTION) else Color.TRANSPARENT)
            tag = "indicator_$index"
        }
        val iconTv = TextView(ctx).apply {
            text = icon
            textSize = 22f
            gravity = Gravity.CENTER
            setTextColor(if (currentTab == index) Color.WHITE else Color.parseColor(COLOR_SUBTEXT))
            tag = "icon_$index"
        }
        val labelTv = TextView(ctx).apply {
            text = label
            textSize = 10f
            gravity = Gravity.CENTER
            setTextColor(if (currentTab == index) Color.WHITE else Color.parseColor(COLOR_HINT))
            tag = "label_$index"
        }
        container.addView(indicator)
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
                        if (::aiStatus.isInitialized) {  // FIX: null-check
                            if (isPremium) {
                                aiStatus.text = "✨ Akun Premium: Tanpa Batas"
                                aiStatus.visibility = View.VISIBLE
                            } else {
                                aiStatus.visibility = View.GONE
                            }
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
                            val premiumHeader = if (isPremium) "✨ Premium — Unlimited\n\n" else ""
                            readAnswer.text = premiumHeader + lastAnswer
                            readScrollView.visibility = View.VISIBLE
                            readStatus.text = "Pertanyaan: $lastQuestion"
                            readStatus.visibility = View.VISIBLE
                        } else {
                            readStatus.text = "Belum ada jawaban. Tanya dulu di tab ✦"
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
                val indicator = tabView.findViewWithTag<View>("indicator_$i")
                val icon = tabView.findViewWithTag<TextView>("icon_$i")
                val label = tabView.findViewWithTag<TextView>("label_$i")
                val active = i == currentTab
                tabView.setBackgroundColor(if (active) Color.parseColor(COLOR_TAB_ACTIVE_BG) else Color.TRANSPARENT)
                indicator?.setBackgroundColor(if (active) Color.parseColor(COLOR_KEY_ACTION) else Color.TRANSPARENT)
                icon?.setTextColor(if (active) Color.WHITE else Color.parseColor(COLOR_SUBTEXT))
                label?.setTextColor(if (active) Color.WHITE else Color.parseColor(COLOR_HINT))
            }
        }
    }

    // IMPROVED: Input bar lebih rapi dengan rounded input field
    private fun buildAIInputBar(ctx: Context): LinearLayout {
        val bar = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor(COLOR_TAB_BG))
            setPadding(dp(12), dp(10), dp(12), dp(10))
        }

        aiStatus = TextView(ctx).apply {
            text = ""
            textSize = 12f
            setTextColor(Color.parseColor(COLOR_HINT))
            visibility = View.GONE
            setPadding(dp(4), 0, 0, dp(6))
        }
        bar.addView(aiStatus)

        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // IMPROVED: Input field dengan rounded corners
        val inputBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(22).toFloat()
            setColor(Color.parseColor(COLOR_INPUT_BG))
        }
        aiInput = EditText(ctx).apply {
            hint = "Ketik pertanyaan..."
            setHintTextColor(Color.parseColor(COLOR_HINT))
            setTextColor(Color.WHITE)
            background = inputBg
            textSize = 15f
            setPadding(dp(16), dp(12), dp(16), dp(12))
            maxLines = 2
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            isFocusableInTouchMode = true
        }

        // IMPROVED: Tombol kirim bulat
        val sendBg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor(COLOR_KEY_ACTION))
        }
        val btnSend = TextView(ctx).apply {
            text = "↑"
            textSize = 20f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = sendBg
            setTypeface(null, android.graphics.Typeface.BOLD)
            val size = dp(44)
            val params = LinearLayout.LayoutParams(size, size)
            params.setMargins(dp(10), 0, 0, 0)
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
            setBackgroundColor(Color.parseColor(COLOR_PANEL_BG))
            setPadding(dp(16), dp(14), dp(16), dp(14))
        }

        readStatus = TextView(ctx).apply {
            text = "Belum ada jawaban. Tanya dulu di tab ✦"
            textSize = 13f
            setTextColor(Color.parseColor(COLOR_HINT))
            setPadding(0, 0, 0, dp(10))
        }
        panel.addView(readStatus)

        readScrollView = ScrollView(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(260)
            )
            visibility = View.GONE
        }
        // IMPROVED: Rounded card untuk jawaban
        val answerBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(12).toFloat()
            setColor(Color.parseColor("#2C2C2E"))
        }
        readAnswer = TextView(ctx).apply {
            text = ""
            textSize = 15f
            setTextColor(Color.parseColor(COLOR_TEXT_MAIN))
            setLineSpacing(dp(4).toFloat(), 1f)
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = answerBg
        }
        readScrollView.addView(readAnswer)
        panel.addView(readScrollView)

        val actionRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.setMargins(0, dp(14), 0, 0) }
        }

        // IMPROVED: Tombol dengan rounded corners
        val insertBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(22).toFloat()
            setColor(Color.parseColor(COLOR_KEY_ACTION))
        }
        val btnInsert = TextView(ctx).apply {
            text = "↳ Sisipkan"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            background = insertBg
            setTypeface(null, android.graphics.Typeface.BOLD)
            setPadding(dp(20), dp(12), dp(20), dp(12))
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            setOnClickListener {
                currentInputConnection?.commitText(lastAnswer, 1)
                switchTab(0)
            }
        }

        val clearBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(22).toFloat()
            setColor(Color.parseColor("#3A3A3C"))
        }
        val btnClear = TextView(ctx).apply {
            text = "Hapus"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor(COLOR_SUBTEXT))
            background = clearBg
            setPadding(dp(20), dp(12), dp(20), dp(12))
            val params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            params.setMargins(dp(10), 0, 0, 0)
            layoutParams = params
            setOnClickListener {
                lastAnswer = ""
                lastQuestion = ""
                readAnswer.text = ""
                readScrollView.visibility = View.GONE
                readStatus.text = "Belum ada jawaban. Tanya dulu di tab ✦"
            }
        }

        actionRow.addView(btnInsert)
        actionRow.addView(btnClear)
        panel.addView(actionRow)

        return panel
    }

    private fun buildKeyboardRows(ctx: Context) {
        // IMPROVED: Padding keyboard lebih rapi, mirip Gboard
        val container = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(4), dp(6), dp(4), dp(12))
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
                ).also { it.setMargins(0, dp(4), 0, dp(4)) }  // IMPROVED: margin antar baris lebih baik
            }
            for (key in row) {
                val btn = buildKeyButton(ctx, key)
                rowLayout.addView(btn)
            }
            container.addView(rowLayout)
        }
    }

    // IMPROVED: Fungsi helper untuk membuat rounded drawable tombol
    private fun makeKeyDrawable(color: String, radius: Float = 8f): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(radius.toInt()).toFloat()
            setColor(Color.parseColor(color))
        }
    }

    private fun buildKeyButton(ctx: Context, label: String): TextView {
        val isFuncKey = label in listOf("⇧","⇪","⌫","?123","ABC","space","↩")

        // IMPROVED: Tentukan warna & teks setiap tombol
        val (displayText, bgColor, fontSize) = when (label) {
            "⇧"   -> Triple("⇧", if (isShift && !isCaps) "#0A84FF" else COLOR_KEY_FUNC, 20f) // aktif biru
            "⇪"   -> Triple("⇪", COLOR_KEY_ACTION, 20f)    // caps lock selalu biru
            "⌫"   -> Triple("⌫", COLOR_KEY_FUNC, 20f)
            "space" -> Triple("", COLOR_KEY_FUNC, 14f)       // IMPROVED: spasi tanpa teks, biar lebar
            "↩"   -> Triple("↩", COLOR_KEY_ACTION, 20f)     // IMPROVED: Enter biru
            "?123" -> Triple("?123", COLOR_KEY_FUNC, 13f)
            "ABC"  -> Triple("ABC", COLOR_KEY_FUNC, 13f)
            else  -> Triple(label, COLOR_KEY_BG, 20f)        // IMPROVED: font size 20
        }

        return TextView(ctx).apply {
            text = displayText
            textSize = fontSize
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor(COLOR_KEY_TEXT))
            background = makeKeyDrawable(bgColor)
            isAllCaps = false
            // IMPROVED: Font bold untuk label lebih jelas
            setTypeface(null, if (isFuncKey) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL)

            // IMPROVED: Weight & ukuran tombol lebih proporsional
            val weight = when (label) {
                "space" -> 3.8f
                "↩"    -> 1.5f
                "⇧","⇪","⌫" -> 1.4f
                "?123","ABC" -> 1.4f
                else -> 1f
            }
            // IMPROVED: Tinggi tombol 56dp, margin lebih rapat 2dp
            layoutParams = LinearLayout.LayoutParams(0, dp(52), weight).apply {
                setMargins(dp(3), 0, dp(3), 0)
            }
            setPadding(dp(2), dp(4), dp(2), dp(4))

            // IMPROVED: Efek tekan visual (darken on press)
            setOnTouchListener { v, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        (v as TextView).background = makeKeyDrawable(COLOR_KEY_PRESSED)
                        false
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        (v as TextView).background = makeKeyDrawable(bgColor)
                        false
                    }
                    else -> false
                }
            }
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
            "⇧", "⇪" -> {  // IMPROVED: handle both shift symbols
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
            "space" -> {
                if (currentTab == 1 && ::aiInput.isInitialized) {
                    val start = aiInput.selectionStart
                    val end = aiInput.selectionEnd
                    aiInput.text.replace(start.coerceAtLeast(0), end.coerceAtLeast(0), " ")
                } else {
                    ic.commitText(" ", 1)
                }
            }
            "↩" -> {  // IMPROVED: handle new enter symbol
                if (currentTab == 1 && ::aiInput.isInitialized) {
                    handleAIQuery()  // IMPROVED: Enter di tab AI langsung kirim
                } else {
                    ic.commitText("\n", 1)
                }
            }
            else -> {
                if (currentTab == 1 && ::aiInput.isInitialized) {
                    val start = aiInput.selectionStart.coerceAtLeast(0)
                    val end = aiInput.selectionEnd.coerceAtLeast(0)
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

    // FIX: showStatus dengan null-check
    private fun showStatus(msg: String) {
        if (!::aiStatus.isInitialized) return
        aiStatus.text = msg
        aiStatus.visibility = View.VISIBLE
    }

    // FIX: handleAIQuery dengan null-check dan try-catch
    private fun handleAIQuery() {
        if (!::aiInput.isInitialized || !::aiStatus.isInitialized) return

        if (FirebaseAuth.getInstance().currentUser == null) {
            showStatus("Silakan login terlebih dahulu.")
            return
        }
        val question = aiInput.text?.toString()?.trim() ?: ""
        if (question.isEmpty()) {
            showStatus("Ketik pertanyaan dulu...")
            return
        }
        lastQuestion = question
        scope.launch {
            try {
                resetDailyQuotaIfNeeded()
                syncQuotaFromFirestore()
                val isPremium = isUserPremium()
                if (!isPremium && !checkAndShowLimit()) return@launch
                sendToAi(question, isPremium)
            } catch (e: Exception) {
                Log.e(TAG, "handleAIQuery error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    showStatus("Terjadi error. Silakan coba lagi.")
                }
            }
        }
    }

    // FIX: sendToAi dengan try-catch dan null-check aiStatus
    private fun sendToAi(question: String, isPremium: Boolean = false) {
        val isOffline = isOfflineMode()
        
        if (isOffline) {
            // Mode offline - tampilkan info
            showStatus("🔒 Mode Offline: Buka app untuk jawab dengan AI lokal")
            if (::aiInput.isInitialized) aiInput.text.clear()
            lastQuestion = question
            return
        }
        
        showStatus("⏳ Sedang memproses...")
        val mode = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString("keyboard_mode", "Essay") ?: "Essay"
        scope.launch {
            try {
                val result = callAIWithFallback(question, mode)
                withContext(Dispatchers.Main) {
                    if (result.startsWith("Error:")) {
                        showStatus(getUserFriendlyErrorMessage(result, "AI"))
                    } else {
                        if (!isPremium) decrementRemainingQuota()
                        lastAnswer = result
                        if (::aiStatus.isInitialized) aiStatus.visibility = View.GONE
                        switchTab(2)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "sendToAi error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    showStatus("Terjadi gangguan. Silakan coba lagi.")
                }
            }
        }
    }

    // ---------- WEIGHTED RANDOM API FALLBACK ----------
    private suspend fun callAIWithFallback(question: String, mode: String): String {
        val candidates = WEIGHTED_ENDPOINTS.toMutableList()
        Log.i(TAG, "Starting API call with ${candidates.size} weighted candidates (Q: ${question.take(50)})")
        var attemptCount = 0
        while (candidates.isNotEmpty()) {
            attemptCount++
            val idx = Random.nextInt(candidates.size)
            val endpoint = candidates[idx]
            Log.d(TAG, "Attempt $attemptCount: Using ${endpoint.type} (key=${endpoint.key.take(15)}...)")
            val result = performApiRequest(endpoint, question, mode)
            if (result != null && !result.startsWith("Error:")) {
                Log.i(TAG, "✓ Success from ${endpoint.type} after $attemptCount attempts")
                return result
            } else {
                candidates.removeAt(idx)
                Log.w(TAG, "✗ ${endpoint.type} failed: ${result?.take(30)}, remaining: ${candidates.size}")
            }
        }
        Log.e(TAG, "✗ All API keys failed after $attemptCount attempts!")
        return "Error: All API keys failed."
    }

    private suspend fun performApiRequest(endpoint: ApiEndpoint, question: String, mode: String): String? {
        // Baca specialization dari SharedPreferences
        val specialization = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
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

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    private fun isOfflineMode() = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getBoolean("offline_mode_enabled", false)

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}