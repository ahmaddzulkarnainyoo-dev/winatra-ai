package com.example.winatra_ai

import android.app.Activity
import android.app.AlertDialog
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast

class ClipboardActivity : Activity() {
    companion object {
        const val TAG = "ClipboardActivity"
        const val EXTRA_QUESTION = "clipboard_question"
        const val EXTRA_MODE_TYPE = "mode_type"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate")

        // Tampilkan loading view sederhana agar user mendapat umpan balik
        showLoadingView()

        val mode = intent.getStringExtra("mode")
        if (mode == "ask") {
            showInputDialog()
        } else {
            // Beri delay agar activity siap, lalu baca clipboard dengan retry
            Handler(Looper.getMainLooper()).postDelayed({
                readClipboardWithRetry(5)
            }, 300)
        }
    }

    private fun showLoadingView() {
        try {
            val layout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(50, 50, 50, 50)
                setBackgroundColor(android.graphics.Color.parseColor("#1A1A2E"))
            }

            val progressBar = ProgressBar(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                // Warna indigo
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    indeterminateTintList = android.content.res.ColorStateList.valueOf(
                        android.graphics.Color.parseColor("#6B4EFF")
                    )
                }
            }

            val textView = TextView(this).apply {
                text = "Memproses..."
                setTextColor(android.graphics.Color.parseColor("#9B7EFF"))
                textSize = 16f
                gravity = Gravity.CENTER
                setPadding(0, 20, 0, 0)
            }

            layout.addView(progressBar)
            layout.addView(textView)

            setContentView(layout)

            // Buat window kecil di tengah
            val params = window.attributes
            params.width = android.view.WindowManager.LayoutParams.WRAP_CONTENT
            params.height = android.view.WindowManager.LayoutParams.WRAP_CONTENT
            params.gravity = Gravity.CENTER
            window.attributes = params
            window.setBackgroundDrawableResource(android.R.color.transparent)
        } catch (e: Exception) {
            Log.w(TAG, "Error showing loading view: ${e.message}")
        }
    }

    private fun readClipboardWithRetry(retryCount: Int) {
        var question = ""
        var attempts = 0
        while (attempts < retryCount) {
            attempts++
            question = readClipboard()
            if (question.isNotEmpty()) {
                Log.d(TAG, "Clipboard read successfully on attempt $attempts: '${question.take(50)}...'")
                break
            }
            if (attempts < retryCount) {
                Log.d(TAG, "Clipboard empty, retry $attempts/$retryCount")
                try {
                    Thread.sleep(200)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                }
            }
        }
        if (question.isEmpty()) {
            Log.w(TAG, "Clipboard still empty after $retryCount retries")
            showToast("Clipboard kosong! Salin pertanyaan dulu.")
        }
        sendQuestionToService(question, "answer")
    }

    private fun readClipboard(): String {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        return try {
            val clip = clipboard.primaryClip
            if (clip != null && clip.itemCount > 0) {
                val text = clip.getItemAt(0).text?.toString()?.trim() ?: ""
                if (text.isNotEmpty()) {
                    Log.d(TAG, "Clipboard content (${text.length} chars): '${text.take(100)}'")
                    text
                } else {
                    Log.w(TAG, "Clipboard item is empty")
                    ""
                }
            } else {
                Log.w(TAG, "Clipboard is null or has no items")
                ""
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading clipboard", e)
            ""
        }
    }

    private fun showInputDialog() {
        window.decorView.post {
            val input = EditText(this).apply {
                hint = "Ketik pertanyaan..."
                setPadding(50, 20, 50, 20)
                isSingleLine = false
                maxLines = 3
            }
            val layout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(50, 30, 50, 20)
                addView(input)
            }

            AlertDialog.Builder(this)
                .setTitle("Tanya AI")
                .setView(layout)
                .setPositiveButton("Kirim") { _, _ ->
                    val question = input.text.toString().trim()
                    if (question.isNotEmpty()) {
                        sendQuestionToService(question, "discussion")
                    } else {
                        showToast("Pertanyaan kosong")
                        finish()
                    }
                }
                .setNegativeButton("Batal") { _, _ -> finish() }
                .setOnCancelListener { finish() }
                .show()
        }
    }

    private fun sendQuestionToService(question: String, modeType: String) {
        Log.d(TAG, "Sending question to service (${question.length} chars, mode=$modeType)")
        val intent = Intent(this, WinatraService::class.java).apply {
            action = WinatraService.ACTION_CLIPBOARD_RESULT
            putExtra(EXTRA_QUESTION, question)
            putExtra(EXTRA_MODE_TYPE, modeType)
        }
        startService(intent)
        finish()
    }

    private fun showToast(msg: String) {
        try {
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.w(TAG, "Error showing toast: ${e.message}")
        }
    }
}