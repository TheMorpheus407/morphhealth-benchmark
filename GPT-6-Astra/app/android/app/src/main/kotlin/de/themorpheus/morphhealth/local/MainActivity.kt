package de.themorpheus.morphhealth.local

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var exportText: String? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.themorpheus.morphhealth/documents").setMethodCallHandler { call, result ->
            if (pending != null) { result.error("busy", "A file dialog is already open", null); return@setMethodCallHandler }
            when (call.method) {
                "save" -> {
                    pending = result
                    exportText = call.argument<String>("content")
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "morphhealth.json")
                    }
                    try { startActivityForResult(intent, 7001) } catch (e: Exception) { pending = null; exportText = null; result.error("document", e.message, null) }
                }
                "open" -> {
                    pending = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type = "*/*" }
                    try { startActivityForResult(intent, 7002) } catch (e: Exception) { pending = null; result.error("document", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7001 && requestCode != 7002) return
        val callback = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { exportText = null; callback.success(null); return }
        val text = exportText
        exportText = null
        Thread {
            try {
                if (requestCode == 7001) {
                    contentResolver.openOutputStream(uri, "wt")!!.use { it.write((text ?: "").toByteArray(Charsets.UTF_8)); it.flush() }
                    runOnUiThread { callback.success(true) }
                } else {
                    val bytes = contentResolver.openInputStream(uri)!!.use { stream ->
                        val out = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = stream.read(buffer)
                            if (count < 0) break
                            if (out.size() + count > 100 * 1024 * 1024) throw IllegalArgumentException("File exceeds 100 MiB")
                            out.write(buffer, 0, count)
                        }
                        out.toByteArray()
                    }
                    runOnUiThread { callback.success(bytes.toString(Charsets.UTF_8)) }
                }
            } catch (e: Exception) { runOnUiThread { callback.error("document", e.message, null) } }
        }.start()
    }
}
