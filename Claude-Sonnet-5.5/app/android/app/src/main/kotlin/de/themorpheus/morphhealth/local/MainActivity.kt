package de.themorpheus.morphhealth.local

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Schmale Brücke zwischen Flutter und Android. Sie stellt nur bereit, was Flutter
 * selbst nicht kann:
 *  - den privaten Dateiordner der App,
 *  - einen nicht exportierbaren Schlüssel im Android Keystore, der den Hauptschlüssel
 *    der lokalen Datenbank umhüllt,
 *  - die System-Dokumentenauswahl (CREATE_DOCUMENT / OPEN_DOCUMENT) für Export,
 *    Import und Sicherungen,
 *  - optional FLAG_SECURE (Bildschirmaufnahmen und App-Vorschau sperren).
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "de.themorpheus.morphhealth/platform"
        private const val KEY_ALIAS = "morphhealth_master_wrap_v1"
        private const val REQUEST_SAVE = 4711
        private const val REQUEST_OPEN = 4712
        private const val MAX_READ_BYTES = 64 * 1024 * 1024
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (e: Exception) {
                result.error("platform_error", e.message ?: e.javaClass.simpleName, null)
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "filesDir" -> result.success(filesDir.absolutePath)
            "keyWrap" -> result.success(wrap(call.arguments as ByteArray))
            "keyUnwrap" -> result.success(unwrap(call.arguments as ByteArray))
            "keyDelete" -> {
                val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                if (ks.containsAlias(KEY_ALIAS)) ks.deleteEntry(KEY_ALIAS)
                result.success(null)
            }
            "setSecure" -> {
                val on = call.arguments as Boolean
                if (on) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
            "saveDocument" -> {
                if (pendingResult != null) {
                    result.error("busy", "Es läuft bereits eine Dateiauswahl", null)
                    return
                }
                val name = call.argument<String>("name") ?: "morphhealth.json"
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                pendingResult = result
                pendingBytes = bytes
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mime
                    putExtra(Intent.EXTRA_TITLE, name)
                }
                startActivityForResult(intent, REQUEST_SAVE)
            }
            "openDocument" -> {
                if (pendingResult != null) {
                    result.error("busy", "Es läuft bereits eine Dateiauswahl", null)
                    return
                }
                pendingResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                startActivityForResult(intent, REQUEST_OPEN)
            }
            else -> result.notImplemented()
        }
    }

    // -- Keystore -------------------------------------------------------------

    private fun wrapKey(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    /** Ergebnis: Nonce (12 Byte) gefolgt von Chiffretext und Tag. */
    private fun wrap(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, wrapKey())
        val iv = cipher.iv
        return iv + cipher.doFinal(plain)
    }

    private fun unwrap(blob: ByteArray): ByteArray {
        require(blob.size > 12 + 16) { "Umhüllter Schlüssel ist zu kurz" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, wrapKey(), GCMParameterSpec(128, blob.copyOfRange(0, 12)))
        return cipher.doFinal(blob, 12, blob.size - 12)
    }

    // -- Dokumentenauswahl ------------------------------------------------------

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_OPEN) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingResult
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        if (result == null) return
        val uri: Uri? = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                if (requestCode == REQUEST_SAVE) {
                    contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes ?: ByteArray(0)) }
                    runOnUiThread { result.success(displayName(uri) ?: "") }
                } else {
                    val content = contentResolver.openInputStream(uri)!!.use { it.readNBytes(MAX_READ_BYTES + 1) }
                    if (content.size > MAX_READ_BYTES) {
                        runOnUiThread { result.error("too_large", "Die Datei ist zu groß", null) }
                    } else {
                        val reply = mapOf("name" to (displayName(uri) ?: ""), "bytes" to content)
                        runOnUiThread { result.success(reply) }
                    }
                }
            } catch (e: Exception) {
                runOnUiThread { result.error("io_error", e.message ?: e.javaClass.simpleName, null) }
            }
        }.start()
    }

    private fun displayName(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) return c.getString(0)
        }
        return null
    }
}
