package de.themorpheus.morphhealth.local

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Hosts the Flutter UI and provides a small platform channel for the three
 * things Dart cannot do alone: the app's private data directory, the
 * Keystore-protected master key and the system document picker (SAF).
 */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "dataDirectory" -> result.success(filesDir.absolutePath)
            "loadMasterKey" -> background(result) { KeyVault.loadOrCreate(applicationContext) }
            "destroyMasterKey" -> background(result) {
                KeyVault.destroy(applicationContext)
                null
            }
            "createDocument" -> {
                if (!claimPending(result)) return
                pendingBytes = call.argument<ByteArray>("bytes")
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = call.argument<String>("mimeType") ?: "application/octet-stream"
                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "morphhealth")
                }
                startActivityForResult(intent, REQUEST_CREATE)
            }
            "openDocument" -> {
                if (!claimPending(result)) return
                val types = call.argument<List<String>>("mimeTypes") ?: listOf("*/*")
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = if (types.size == 1) types[0] else "*/*"
                    if (types.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
                }
                startActivityForResult(intent, REQUEST_OPEN)
            }
            else -> result.notImplemented()
        }
    }

    private fun claimPending(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.error("busy", "Another document request is active", null)
            return false
        }
        pendingResult = result
        return true
    }

    private fun <T> background(result: MethodChannel.Result, work: () -> T) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("platform_error", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    @Deprecated("Uses the platform activity result API supported by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CREATE && requestCode != REQUEST_OPEN) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingResult ?: return
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        val uri: Uri? = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            // Cancelled by the user.
            result.success(null)
            return
        }
        if (requestCode == REQUEST_CREATE) {
            background(result) {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes ?: ByteArray(0)) }
                    ?: throw IllegalStateException("Cannot write document")
                true
            }
        } else {
            background(result) {
                contentResolver.openInputStream(uri)?.use { input ->
                    val out = ByteArrayOutputStream()
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        total += n
                        if (total > MAX_DOCUMENT_BYTES) throw IllegalStateException("File too large")
                        out.write(buffer, 0, n)
                    }
                    out.toByteArray()
                } ?: throw IllegalStateException("Cannot read document")
            }
        }
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "de.themorpheus.morphhealth/platform"
        private const val REQUEST_CREATE = 4101
        private const val REQUEST_OPEN = 4102
        private const val MAX_DOCUMENT_BYTES = 128L * 1024 * 1024
    }
}
