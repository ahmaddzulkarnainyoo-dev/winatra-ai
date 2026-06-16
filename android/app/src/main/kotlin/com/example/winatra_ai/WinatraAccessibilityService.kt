package com.example.winatra_ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.content.ContextCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.Locale

class WinatraAccessibilityService : AccessibilityService(), TextToSpeech.OnInitListener {
    companion object {
        const val TAG = "WinatraAccessibilityService"
        const val ACTION_TEXT_UPDATED = "com.example.winatra_ai.ACCESSIBILITY_TEXT"
        const val EXTRA_TEXT = "text"

        @Volatile
        var lastAccessibilityText: String = ""

        @Volatile
        var isListening: Boolean = true

        @Volatile
        var currentService: WinatraAccessibilityService? = null
    }

    private var lastVolumeUpTime = 0L
    private val doublePressDelay = 700L
    private val handler = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var isSpeechReady = false
    private var pendingCommand = ""
    private var userName = "Pengguna"
    private var proactiveEnabled = true
    private var voiceCommandEnabled = true
    private var lastReadText = ""
    private var lastTtsMessage = ""

    override fun onCreate() {
        super.onCreate()
        tts = TextToSpeech(this, this)
        initSpeechRecognizer()
        fetchUserName()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        currentService = this
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                    AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_SPOKEN
            notificationTimeout = 100
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        }
        serviceInfo = info
        Log.d(TAG, "Service connected, listening for accessibility events")
        speakGreeting("Halo $userName, Winatra siap membantu. Ada yang bisa saya bantu?")
    }

    override fun onDestroy() {
        super.onDestroy()
        currentService = null
        speechRecognizer?.destroy()
        tts?.shutdown()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isListening || event == null) return

        val eventType = event.eventType
        when (eventType) {
            AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                val eventText = extractEventText(event)
                val screenText = if (eventText.isNotBlank()) eventText else extractTextFromRoot(rootInActiveWindow)
                if (screenText.isNotBlank() && screenText != lastAccessibilityText) {
                    lastAccessibilityText = screenText
                    sendTextEvent(screenText)
                }
            }
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                if (proactiveEnabled) {
                    val notificationText = extractEventText(event)
                    if (notificationText.isNotBlank()) {
                        speakNotification(notificationText)
                    }
                }
            }
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                if (proactiveEnabled) {
                    val packageName = event.packageName?.toString() ?: ""
                    val screenText = extractTextFromRoot(rootInActiveWindow)
                    val friendlyApp = friendlyAppName(packageName)
                    if (friendlyApp.isNotBlank()) {
                        speakGreeting("Halo $userName, saya lihat kamu membuka $friendlyApp. Ada yang ingin dibantu?")
                    }
                    if (screenText.isNotBlank() && screenText != lastAccessibilityText) {
                        lastAccessibilityText = screenText
                        sendTextEvent(screenText)
                    }
                }
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

    private fun friendlyAppName(packageName: String): String {
        return when {
            packageName.contains("whatsapp", true) -> "WhatsApp"
            packageName.contains("chrome", true) -> "Chrome"
            packageName.contains("classroom", true) -> "Google Classroom"
            packageName.contains("mentari", true) -> "Mentari"
            packageName.contains("webview", true) -> "browser"
            packageName.isNotBlank() -> packageName
            else -> "aplikasi"
        }
    }

    private fun speakNotification(notificationText: String) {
        if (!isSpeechReady) return
        val title = "Ada notifikasi baru"
        speak("$title. $notificationText. Ada pesan masuk. Ingin saya balas?")
    }

    private fun speakGreeting(message: String) {
        if (!isSpeechReady || !proactiveEnabled) return
        speak(message)
    }

    private fun speak(message: String) {
        lastTtsMessage = message
        tts?.speak(message, TextToSpeech.QUEUE_FLUSH, null, "WINATRA_TTS")
        Log.d(TAG, "TTS speak: $message")
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale("id", "ID")
            isSpeechReady = true
            Log.d(TAG, "TextToSpeech initialized")
        } else {
            Log.e(TAG, "TextToSpeech initialization failed")
        }
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

    private fun fetchUserName() {
        val currentUser = FirebaseAuth.getInstance().currentUser
        if (currentUser != null) {
            FirebaseFirestore.getInstance().collection("users").document(currentUser.uid)
                .get()
                .addOnSuccessListener { snapshot ->
                    val displayName = snapshot.getString("displayName")
                    if (!displayName.isNullOrBlank()) {
                        userName = displayName
                    }
                }
                .addOnFailureListener { e ->
                    Log.w(TAG, "Failed to fetch user name: ${e.message}")
                }
        }
    }

    private fun initSpeechRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.w(TAG, "Speech recognition not available")
            return
        }
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    Log.d(TAG, "SpeechRecognizer ready")
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) {
                    Log.w(TAG, "SpeechRecognizer error: $error")
                    if (proactiveEnabled) {
                        speak("Maaf, saya tidak mengerti. Coba ulangi.")
                    }
                }
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val command = matches?.firstOrNull()?.lowercase(Locale.getDefault()) ?: ""
                    Log.d(TAG, "SpeechRecognizer results: $command")
                    if (command.isNotBlank()) {
                        if (command.contains("winatra", true)) {
                            processVoiceCommand(command)
                        } else {
                            speak("Maaf, saya tidak mendengar kata Winatra. Silakan mulai lagi dengan Winatra.")
                        }
                    }
                }
            })
        }
    }

    private fun startVoiceCommandListening() {
        if (!voiceCommandEnabled || speechRecognizer == null) {
            speak("Voice command belum aktif atau tidak tersedia.")
            return
        }
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            speak("Izin mikrofon belum diberikan. Aktifkan izin di pengaturan.")
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id-ID")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Hai Winatra, silakan bicara...")
        }
        speechRecognizer?.startListening(intent)
        speak("Saya mendengarkan, katakan perintah Anda setelah kata Winatra.")
    }

    private fun processVoiceCommand(command: String) {
        val normalized = command.lowercase(Locale.getDefault())
        when {
            normalized.contains("halo winatra") || normalized.contains("winatra halo") -> {
                speak("Halo $userName. Saya siap membantu. Silakan katakan perintah Anda.")
            }
            normalized.contains("baca pesan") -> {
                handleReadWhatsApp()
            }
            normalized.contains("baca layar") -> {
                handleReadScreen()
            }
            normalized.contains("jawab pertanyaan") || normalized.contains("kerjakan tugas") -> {
                handleAnswerQuestion()
            }
            normalized.contains("buka whatsapp") || normalized.contains("buka chrome") || normalized.contains("buka google classroom") -> {
                openAppByName(normalized)
            }
            normalized.contains("tulis ") -> {
                handleWriteText(normalized)
            }
            normalized.contains("salin jawaban") -> {
                handleCopyAnswer()
            }
            normalized.contains("baca ulang") -> {
                handleReadAgain()
            }
            else -> {
                speak("Maaf, saya tidak mengerti. Coba ulangi.")
            }
        }
    }

    private fun handleReadWhatsApp() {
        val root = rootInActiveWindow
        if (root == null) {
            speak("Tidak dapat membaca layar. Mohon buka WhatsApp terlebih dahulu.")
            return
        }
        val messages = collectRecentMessages(root)
        if (messages.isEmpty()) {
            speak("Tidak ada pesan baru, $userName.")
            return
        }
        val speakText = messages.takeLast(5).joinToString(". ") { it }
        lastReadText = speakText
        speak("Berikut beberapa pesan terakhir: $speakText")
    }

    private fun handleReadScreen() {
        val screenText = extractTextFromRoot(rootInActiveWindow)
        if (screenText.isBlank()) {
            speak("Tidak ada teks yang dapat dibaca saat ini.")
            return
        }
        lastReadText = screenText
        speak(screenText)
    }

    private fun handleAnswerQuestion() {
        val text = extractTextFromRoot(rootInActiveWindow)
        if (text.isBlank()) {
            speak("Tidak ada pertanyaan yang dapat saya temukan di layar.")
            return
        }
        lastReadText = text
        sendTextForAI(text)
        speak("Saya sedang mencari jawaban. Silakan periksa notifikasi.")
    }

    private fun handleWriteText(command: String) {
        val writeText = command.substringAfter("tulis ").trim()
        if (writeText.isBlank()) {
            speak("Teks belum ditemukan. Ulangi perintah dengan kata-kata yang jelas.")
            return
        }
        if (findTextInputAndSet(writeText)) {
            speak("Teks berhasil ditulis.")
        } else {
            speak("Tidak menemukan kolom input aktif. Pastikan aplikasi memiliki fokus text field.")
        }
    }

    private fun handleCopyAnswer() {
        if (lastReadText.isBlank()) {
            speak("Tidak ada jawaban untuk disalin.")
            return
        }
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
        clipboard.setPrimaryClip(android.content.ClipData.newPlainText("winatra_answer", lastReadText))
        speak("Jawaban disalin ke clipboard.")
    }

    private fun handleReadAgain() {
        if (lastTtsMessage.isBlank()) {
            speak("Belum ada pembacaan sebelumnya.")
            return
        }
        speak(lastTtsMessage)
    }

    private fun openAppByName(command: String) {
        val packageName = when {
            command.contains("whatsapp") -> "com.whatsapp"
            command.contains("chrome") -> "com.android.chrome"
            command.contains("classroom") -> "com.google.android.apps.classroom"
            else -> ""
        }
        if (packageName.isBlank()) {
            speak("Aplikasi tidak diketahui. Coba sebutkan lagi.")
            return
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)
            speak("Membuka aplikasi.")
        } else {
            speak("Tidak dapat menemukan aplikasi yang diminta pada perangkat ini.")
        }
    }

    private fun findTextInputAndSet(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val editNodes = mutableListOf<AccessibilityNodeInfo>()
        findNodesByClassName(root, "android.widget.EditText", editNodes)
        if (editNodes.isEmpty()) return false
        val input = editNodes.firstOrNull() ?: return false
        val arguments = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        val success = input.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
        if (success) {
            if (!clickSendButton()) {
                input.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            }
        }
        return success
    }

    private fun clickSendButton(): Boolean {
        val root = rootInActiveWindow ?: return false
        val buttons = mutableListOf<AccessibilityNodeInfo>()
        findNodesByClassName(root, "android.widget.Button", buttons)
        for (button in buttons) {
            val text = button.text?.toString()?.lowercase(Locale.getDefault()) ?: ""
            if (text.contains("kirim") || text.contains("send") || text.contains("reply")) {
                if (button.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                    return true
                }
            }
        }
        return false
    }

    private fun collectRecentMessages(root: AccessibilityNodeInfo?): List<String> {
        if (root == null) return emptyList()
        val texts = mutableListOf<String>()
        if (!root.text.isNullOrBlank()) {
            texts.add(root.text.toString())
        }
        for (i in 0 until root.childCount) {
            texts.addAll(collectRecentMessages(root.getChild(i)))
        }
        return texts.distinct().filter { it.length > 2 }
    }

    private fun findNodesByClassName(root: AccessibilityNodeInfo?, className: String, results: MutableList<AccessibilityNodeInfo>) {
        if (root == null) return
        if (root.className?.toString() == className) {
            results.add(root)
        }
        for (i in 0 until root.childCount) {
            findNodesByClassName(root.getChild(i), className, results)
        }
    }
