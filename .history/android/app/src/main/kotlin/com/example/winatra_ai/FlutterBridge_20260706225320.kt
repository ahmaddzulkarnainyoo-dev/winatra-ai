package com.example.winatra_ai

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Bridge for communication between native Android services (WinatraService, WinatraKeyboardService)
 * and Flutter (Dart) via MethodChannel.
 *
 * Flow:
 *   Native Service → MethodChannel.invokeMethod("getAnswer", query) → Flutter
 *   Flutter processes (RAGService + AIService) → returns result → Native Service
 */
object FlutterBridge {
    private const val TAG = "FlutterBridge"
    private const val BRIDGE_CHANNEL = "winatra/bridge"

    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val pendingRequests = ConcurrentLinkedQueue<PendingRequest>()

    data class PendingRequest(
        val id: String,
        val query: String,
        val completion: CompletableDeferred<String>
    )

    /**
     * Initialize the bridge with the FlutterEngine.
     * Called from MainActivity.configureFlutterEngine()
     */
    fun initialize(engine: FlutterEngine) {
        flutterEngine = engine
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, BRIDGE_CHANNEL)
        Log.i(TAG, "FlutterBridge initialized with channel: $BRIDGE_CHANNEL")
    }

    /**
     * Send a query to Flutter to get an AI answer with context from The Brain.
     * Returns the answer string, or an error message if it fails.
     */
    suspend fun getAnswer(query: String): String {
        val channel = methodChannel
        if (channel == null) {
            Log.e(TAG, "FlutterBridge not initialized! Cannot get answer.")
            return "Error: Bridge not initialized"
        }

        return withContext(Dispatchers.Main) {
            try {
                val result = CompletableDeferred<String>()
                val requestId = "req_${System.currentTimeMillis()}"

                Log.i(TAG, "Sending query to Flutter: ${query.take(50)}...")

                channel.invokeMethod("getAnswer", query, object : MethodChannel.Result {
                    override fun success(response: Any?) {
                        val answer = response?.toString() ?: ""
                        Log.i(TAG, "Got answer from Flutter: ${answer.take(50)}...")
                        result.complete(answer)
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e(TAG, "Flutter error: $errorCode - $errorMessage")
                        result.complete("Error: $errorMessage")
                    }

                    override fun notImplemented() {
                        Log.e(TAG, "getAnswer not implemented in Flutter!")
                        result.complete("Error: Method not implemented in Flutter")
                    }
                })

                result.await()
            } catch (e: Exception) {
                Log.e(TAG, "Exception in getAnswer: ${e.message}", e)
                "Error: ${e.message}"
            }
        }
    }

    /**
     * Get context from The Brain for a query (without generating answer).
     */
    suspend fun getBrainContext(query: String): String {
        val channel = methodChannel
        if (channel == null) {
            Log.e(TAG, "FlutterBridge not initialized!")
            return ""
        }

        return withContext(Dispatchers.Main) {
            try {
                val result = CompletableDeferred<String>()

                channel.invokeMethod("getBrainContext", query, object : MethodChannel.Result {
                    override fun success(response: Any?) {
                        result.complete(response?.toString() ?: "")
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        result.complete("")
                    }

                    override fun notImplemented() {
                        result.complete("")
                    }
                })

                result.await()
            } catch (e: Exception) {
                Log.e(TAG, "Exception in getBrainContext: ${e.message}")
                ""
            }
        }
    }

    /**
     * Check if the bridge is ready
     */
    fun isReady(): Boolean = methodChannel != null
}