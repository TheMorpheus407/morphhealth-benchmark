package de.themorpheus.morphhealth.local

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Hosts the Flutter UI and offers the few platform services the app needs:
 * the private data directory, the master key (see [KeyVault]) and saving or
 * opening a document with the system file picker (Storage Access Framework).
 *
 * The file picker needs no storage permission: the user chooses the place,
 * and the app gets access to exactly that one document.
 */
class MainActivity : FlutterActivity() {
    private val io: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onMethodCall)
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "dataDirectory" ->
                result.success(File(noBackupFilesDir, "store").absolutePath)
            "loadOrCreateMasterKey" ->
                inBackground(result, "key_unavailable") {
                    KeyVault.loadOrCreate(applicationContext)
                }
            "resetMasterKey" ->
                inBackground(result, "key_unavailable") {
                    KeyVault.reset(applicationContext)
                    null
                }
            "saveDocument" -> saveDocument(call, result)
            "openDocument" -> openDocument(result)
            else -> result.notImplemented()
        }
    }

    private fun inBackground(
        result: MethodChannel.Result,
        errorCode: String,
        work: () -> Any?,
    ) {
        io.execute {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                runOnUiThread { result.error(errorCode, e.message, null) }
            }
        }
    }

    private fun saveDocument(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val mimeType = call.argument<String>("mimeType")
        val bytes = call.argument<ByteArray>("bytes")
        if (name == null || mimeType == null || bytes == null) {
            result.error("invalid_argument", "name, mimeType and bytes are required", null)
            return
        }
        if (pendingResult != null) {
            result.error("busy", "Another file dialog is open.", null)
            return
        }
        pendingResult = result
        pendingBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, name)
        }
        launch(intent, REQUEST_SAVE)
    }

    private fun openDocument(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Another file dialog is open.", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Exports and backups are recognized by their content, not by a
            // MIME type that file providers report inconsistently.
            type = "*/*"
        }
        launch(intent, REQUEST_OPEN)
    }

    private fun launch(intent: Intent, requestCode: Int) {
        try {
            startActivityForResult(intent, requestCode)
        } catch (e: Exception) {
            completePending { it.error("no_file_picker", "No file picker is available.", null) }
        }
    }

    /** Answers the pending call exactly once. */
    private fun completePending(answer: (MethodChannel.Result) -> Unit) {
        val result = pendingResult
        pendingResult = null
        pendingBytes = null
        if (result != null) answer(result)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // Cancelled by the user.
            completePending { it.success(null) }
            return
        }
        if (requestCode == REQUEST_SAVE) {
            val bytes = pendingBytes
            io.execute {
                try {
                    val stream = contentResolver.openOutputStream(uri, "wt")
                        ?: throw IllegalStateException("The document cannot be opened.")
                    stream.use {
                        it.write(bytes ?: ByteArray(0))
                        it.flush()
                    }
                    val name = displayName(uri)
                    runOnUiThread { completePending { it.success(name) } }
                } catch (e: Exception) {
                    // Do not leave an empty or half-written document behind.
                    try {
                        DocumentsContract.deleteDocument(contentResolver, uri)
                    } catch (_: Exception) {
                    }
                    runOnUiThread {
                        completePending { it.error("write_failed", e.message, null) }
                    }
                }
            }
        } else {
            io.execute {
                try {
                    val out = ByteArrayOutputStream()
                    val stream = contentResolver.openInputStream(uri)
                        ?: throw IllegalStateException("The document cannot be opened.")
                    var tooLarge = false
                    stream.use { input ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            out.write(buffer, 0, n)
                            if (out.size() > MAX_DOCUMENT_BYTES) {
                                tooLarge = true
                                break
                            }
                        }
                    }
                    if (tooLarge) {
                        runOnUiThread {
                            completePending { it.error("too_large", "The file is too large.", null) }
                        }
                    } else {
                        val answer = mapOf("name" to displayName(uri), "bytes" to out.toByteArray())
                        runOnUiThread { completePending { it.success(answer) } }
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        completePending { it.error("read_failed", e.message, null) }
                    }
                }
            }
        }
    }

    private fun displayName(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst() && !cursor.isNull(0)) return cursor.getString(0)
                }
        } catch (_: Exception) {
        }
        return uri.lastPathSegment ?: "Dokument"
    }

    private companion object {
        const val CHANNEL = "de.themorpheus.morphhealth.local/platform"
        const val REQUEST_SAVE = 4101
        const val REQUEST_OPEN = 4102
        const val MAX_DOCUMENT_BYTES = 128 * 1024 * 1024
    }
}
