package de.themorpheus.morphhealth.local

import android.app.Activity
import android.content.Intent
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val alias = "morphhealth-wrapping-v1"
    private var pending: MethodChannel.Result? = null
    private var output: ByteArray? = null
    private val createCode = 8101
    private val openCode = 8102

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.themorpheus.morphhealth/vault")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "vault" -> result.success(vault())
                        "resetStorage" -> {
                            File(filesDir, "morphhealth").deleteRecursively()
                            File(filesDir, "vault-key.wrapped").delete()
                            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                            if (store.containsAlias(alias)) store.deleteEntry(alias)
                            result.success(null)
                        }
                        "saveDocument" -> {
                            if (pending != null) { result.error("busy", "A document operation is active", null) }
                            else {
                                pending = result
                                output = call.argument<ByteArray>("bytes")!!
                                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = call.argument<String>("mime") ?: "application/json"
                                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                                }
                                startActivityForResult(intent, createCode)
                            }
                        }
                        "openDocument" -> {
                            if (pending != null) { result.error("busy", "A document operation is active", null) }
                            else {
                                pending = result
                                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "*/*"
                                }
                                startActivityForResult(intent, openCode)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    pending = null
                    output = null
                    result.error("storage_error", "Secure storage or document access failed", null)
                }
            }
    }

    private fun wrappingKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!store.containsAlias(alias)) {
            val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build())
            generator.generateKey()
        }
        return store.getKey(alias, null) as SecretKey
    }

    private fun vault(): Map<String, String> {
        val dir = File(filesDir, "morphhealth").apply { mkdirs() }
        val file = File(filesDir, "vault-key.wrapped")
        val key: ByteArray
        if (file.exists()) {
            val wrapped = file.readBytes()
            if (wrapped.size != 60) throw IllegalStateException("Invalid wrapped key")
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, wrappingKey(), GCMParameterSpec(128, wrapped.copyOfRange(0, 12)))
            key = cipher.doFinal(wrapped.copyOfRange(12, wrapped.size))
        } else {
            // A missing key must never silently create a new key for an existing vault.
            if (File(dir, "health.mhv").exists()) throw IllegalStateException("Missing vault key")
            key = ByteArray(32).also { SecureRandom().nextBytes(it) }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, wrappingKey())
            val temp = File(filesDir, "vault-key.wrapped.tmp")
            temp.outputStream().use { it.write(cipher.iv + cipher.doFinal(key)); it.fd.sync() }
            if (!temp.renameTo(file)) throw IllegalStateException("Cannot persist key")
        }
        return mapOf("directory" to dir.absolutePath, "key" to Base64.encodeToString(key, Base64.NO_WRAP))
    }

    @Deprecated("Legacy activity-result callback used by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createCode && requestCode != openCode) return
        val result = pending ?: return
        val bytes = output
        pending = null
        output = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == createCode) false else null)
            return
        }
        Thread {
            try {
                if (requestCode == createCode) {
                    contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes!!); it.flush() }
                    runOnUiThread { result.success(true) }
                } else {
                    val input = contentResolver.openInputStream(uri)!!.use { stream ->
                        val buffer = java.io.ByteArrayOutputStream()
                        val block = ByteArray(8192)
                        while (true) {
                            val count = stream.read(block)
                            if (count < 0) break
                            if (buffer.size() + count > 64 * 1024 * 1024) throw IllegalArgumentException("Document too large")
                            buffer.write(block, 0, count)
                        }
                        buffer.toByteArray()
                    }
                    runOnUiThread { result.success(input) }
                }
            } catch (_: Exception) {
                runOnUiThread { result.error("document_error", "Could not read or write document", null) }
            }
        }.start()
    }
}
