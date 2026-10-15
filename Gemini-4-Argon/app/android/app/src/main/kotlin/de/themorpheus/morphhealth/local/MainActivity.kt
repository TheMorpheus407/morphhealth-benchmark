package de.themorpheus.morphhealth.local

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "de.themorpheus.morphhealth.local/platform"
    private val reqCreateDocument = 9101
    private val reqOpenDocument = 9102

    private var pendingResult: MethodChannel.Result? = null
    private var pendingWriteContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPaths" -> {
                    val dataDir = File(filesDir, "morphhealth_data").apply { mkdirs() }
                    val exportsDir = File(filesDir, "exports").apply { mkdirs() }
                    val keyFile = File(noBackupFilesDir, "morphhealth_master.key")
                    result.success(
                        mapOf(
                            "dataDir" to dataDir.absolutePath,
                            "keyFile" to keyFile.absolutePath,
                            "exportsDir" to exportsDir.absolutePath
                        )
                    )
                }
                "saveDocument" -> {
                    if (pendingResult != null) {
                        result.error("BUSY", "Another document operation is in progress", null)
                        return@setMethodCallHandler
                    }
                    val suggestedName = call.argument<String>("suggestedName") ?: "morphhealth_export.json"
                    val mimeType = call.argument<String>("mimeType") ?: "application/json"
                    val content = call.argument<String>("content") ?: ""
                    pendingResult = result
                    pendingWriteContent = content
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mimeType
                        putExtra(Intent.EXTRA_TITLE, suggestedName)
                    }
                    startActivityForResult(intent, reqCreateDocument)
                }
                "openDocument" -> {
                    if (pendingResult != null) {
                        result.error("BUSY", "Another document operation is in progress", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    startActivityForResult(intent, reqOpenDocument)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val callback = pendingResult ?: return
        val contentToWrite = pendingWriteContent
        pendingResult = null
        pendingWriteContent = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback.success(null)
            return
        }
        val uri: Uri = data.data!!
        try {
            when (requestCode) {
                reqCreateDocument -> {
                    contentResolver.openOutputStream(uri, "wt")?.use { out ->
                        out.write((contentToWrite ?: "").toByteArray(Charsets.UTF_8))
                        out.flush()
                    }
                    callback.success(uri.toString())
                }
                reqOpenDocument -> {
                    val text = contentResolver.openInputStream(uri)?.use { input ->
                        input.readBytes().toString(Charsets.UTF_8)
                    }
                    callback.success(text)
                }
                else -> callback.success(null)
            }
        } catch (e: Exception) {
            callback.error("IO_ERROR", e.message ?: "Document operation failed", null)
        }
    }
}
