package com.example.winatra_ai

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Native Android Speech-to-Text and Text-to-Speech service.
 * Uses Android's built-in SpeechRecognizer for STT.
 * TTS is handled by Flutter's flutter_tts package.
 */
class WinatraSpeechService {
    companion object {
        private const val TAG = "WinatraSpeechService"
        private const val SPEECH_CHANNEL = "winatra/speech"

        private var speechRecognizer: SpeechRecognizer? = null
        private var methodChannel: MethodChannel? = null
        private var isListening = false

        /**
         * Initialize the speech service with the FlutterEngine.
         */
        fun initialize(engine: FlutterEngine) {
            methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
            Log.i(TAG, "WinatraSpeechService initialized")
        }

        /**
         * Start listening for speech input.
         * Sends results back to Flutter via MethodChannel.
         */
        fun startListening(context: android.content.Context) {
            if (isListening) {
                Log.w(TAG, "Already listening, stopping first")
                stopListening()
            }

            try {
                if (speechRecognizer == null) {
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
                }

                val recognizer = speechRecognizer ?: return

                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        Log.d(TAG, "onReadyForSpeech")
                        methodChannel?.invokeMethod("onListeningStarted", null)
                    }

                    override fun onBeginningOfSpeech() {
                        Log.d(TAG, "onBeginningOfSpeech")
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        // Volume level (0.0 to 1.0 normalized)
                        val normalizedVolume = (rmsdB / 10.0f).coerceIn(0.0f, 1.0f)
                        methodChannel?.invokeMethod("onVolumeChanged", normalizedVolume.toDouble())
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {
                        // Not used
                    }

                    override fun onEndOfSpeech() {
                        Log.d(TAG, "onEndOfSpeech")
                        isListening = false
                    }

                    override fun onError(error: Int) {
                        Log.e(TAG, "SpeechRecognizer error: $error")
                        isListening = false
                        val errorMsg = when (error) {
                            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                            SpeechRecognizer.ERROR_CLIENT -> "Client side error"
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                            SpeechRecognizer.ERROR_NETWORK -> "Network error"
                            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                            SpeechRecognizer.ERROR_NO_MATCH -> "No speech matched"
                            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
                            SpeechRecognizer.ERROR_SERVER -> "Server error"
                            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
                            else -> "Unknown error: $error"
                        }
                        Log.d(TAG, "Sending onError: $errorMsg")
                        methodChannel?.invokeMethod("onError", errorMsg)
                        methodChannel?.invokeMethod("onListeningStopped", null)
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (matches != null && matches.isNotEmpty()) {
                            val text = matches[0]
                            Log.d(TAG, "STT result: $text")
                            methodChannel?.invokeMethod("onFinalResult", text)
                        } else {
                            Log.w(TAG, "No recognition results")
                            methodChannel?.invokeMethod("onFinalResult", "")
                        }
                        isListening = false
                        methodChannel?.invokeMethod("onListeningStopped", null)
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (matches != null && matches.isNotEmpty()) {
                            val partialText = matches[0]
                            methodChannel?.invokeMethod("onPartialResult", partialText)
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {
                        Log.d(TAG, "onEvent: $eventType")
                    }
                })

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id-ID")
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "id-ID")
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 2000)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000)
                    putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000)
                }

                isListening = true
                recognizer.startListening(intent)
                Log.i(TAG, "Started listening for speech...")

            } catch (e: Exception) {
                Log.e(TAG, "Failed to start listening: ${e.message}", e)
                isListening = false
                methodChannel?.invokeMethod("onError", "Failed to start: ${e.message}")
                methodChannel?.invokeMethod("onListeningStopped", null)
            }
        }

        /**
         * Stop listening for speech input.
         */
        fun stopListening() {
            try {
                speechRecognizer?.stopListening()
                speechRecognizer?.destroy()
                speechRecognizer = null
                isListening = false
                Log.i(TAG, "Stopped listening")
                methodChannel?.invokeMethod("onListeningStopped", null)
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping listening: ${e.message}")
                speechRecognizer = null
                isListening = false
            }
        }

        /**
         * Cancel current speech recognition without getting result.
         */
        fun cancelListening() {
            try {
                speechRecognizer?.cancel()
                speechRecognizer?.destroy()
                speechRecognizer = null
                isListening = false
                Log.i(TAG, "Cancelled listening")
                methodChannel?.invokeMethod("onListeningStopped", null)
            } catch (e: Exception) {
                Log.e(TAG, "Error cancelling listening: ${e.message}")
                speechRecognizer = null
                isListening = false
            }
        }

        /**
         * Check if currently listening.
         */
        fun isCurrentlyListening(): Boolean = isListening

        /**
         * Clean up resources.
         */
        fun dispose() {
            stopListening()
            methodChannel = null
        }
    }
}