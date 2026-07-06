package com.example.winatra_ai

import android.app.Activity
import android.app.AlertDialog
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
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

        window.setFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        )

        val mode = intent.getStringExtra("mode")
        if (mode == "ask") {
            showInputDialog()
        } else {
            // Beri delay agar activity siap, lalu baca clipboard dengan retry
            Handler(Looper.getMainLooper()).postDelayed({
                readClipboardWithRetry(3)
            }, 500)
        }
    }

    private fun readClipboardWithRetry(retryCount: Int) {
        var question = ""
        for (i in 1..retryCount) {
            question = readClipboard()
            if (question.isNotEmpty()) break
            if (i < retryCount) {
                Log.d(TAG, "Clipboard empty, retry $i/$retryCount")
                Thread.sleep(100)
            }
        }
        if (question.isEmpty()) {
            Log.w(TAG, "Clipboard still empty after $retryCount retries")
        }
        sendQuestionToService(question, "answer")
    }

    private fun readClipboard(): String {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        return try {
            val clip = clipboard.primaryClip
            if (clip != null && clip.itemCount > 0) {
                val text = clip.getItemAt(0).text?.toString()?.trim() ?: ""
                Log.d(TAG, "Clipboard content: '$text'")
                text
            } else {
                Log.w(TAG, "Clipboard is null or empty")
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
                        Toast.makeText(this, "Pertanyaan kosong", Toast.LENGTH_SHORT).show()
                        finish()
                    }
                }
                .setNegativeButton("Batal") { _, _ -> finish() }
                .setOnCancelListener { finish() }
                .show()
        }
    }

    private fun sendQuestionToService(question: String, modeType: String) {
        val intent = Intent(this, WinatraService::class.java).apply {
            action = WinatraService.ACTION_CLIPBOARD_RESULT
            putExtra(EXTRA_QUESTION, question)
            putExtra(EXTRA_MODE_TYPE, modeType)
        }
        startService(intent)
        finish()
    }
}