package de.themorpheus.morphhealth.local

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "de.themorpheus.morphhealth.local/platform"
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALIAS = "morphhealth_master_wrap_v1"
        private const val REQ_SAVE_DOCUMENT = 4101
        private const val REQ_OPEN_DOCUMENT = 4102
    }

    private var pendingDocResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getAppPathsAndMasterKey" -> {
                            val vaultDir = File(filesDir, "vault_data")
                            if (!vaultDir.exists()) {
                                vaultDir.mkdirs()
                            }
                            val masterKey = loadOrCreateMasterKey(forceRotate = false)
                            result.success(
                                mapOf(
                                    "dataDir" to vaultDir.absolutePath,
                                    "masterKey" to masterKey
                                )
                            )
                        }
                        "rotateMasterKey" -> {
                            val masterKey = loadOrCreateMasterKey(forceRotate = true)
                            result.success(mapOf("masterKey" to masterKey))
                        }
                        "saveDocument" -> {
                            if (pendingDocResult != null) {
                                result.error("BUSY", "Another document operation is active.", null)
                                return@setMethodCallHandler
                            }
                            val fileName = call.argument<String>("fileName") ?: "morphhealth_export.json"
                            val mimeType = call.argument<String>("mimeType") ?: "application/json"
                            val bytes = call.argument<ByteArray>("bytes")
                            if (bytes == null) {
                                result.error("INVALID_ARGS", "Missing bytes.", null)
                                return@setMethodCallHandler
                            }
                            pendingDocResult = result
                            pendingSaveBytes = bytes
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = mimeType
                                putExtra(Intent.EXTRA_TITLE, fileName)
                            }
                            startActivityForResult(intent, REQ_SAVE_DOCUMENT)
                        }
                        "openDocument" -> {
                            if (pendingDocResult != null) {
                                result.error("BUSY", "Another document operation is active.", null)
                                return@setMethodCallHandler
                            }
                            pendingDocResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            startActivityForResult(intent, REQ_OPEN_DOCUMENT)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("PLATFORM_ERROR", e.message ?: e.javaClass.simpleName, null)
                }
            }
    }

    @Deprecated("Using Activity result API for direct FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_SAVE_DOCUMENT && requestCode != REQ_OPEN_DOCUMENT) {
            return
        }
        val callback = pendingDocResult
        val bytesToWrite = pendingSaveBytes
        pendingDocResult = null
        pendingSaveBytes = null
        if (callback == null) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            if (requestCode == REQ_SAVE_DOCUMENT) {
                callback.success(mapOf("saved" to false))
            } else {
                callback.success(mapOf("picked" to false))
            }
            return
        }

        val uri: Uri = data.data!!
        try {
            if (requestCode == REQ_SAVE_DOCUMENT) {
                val outBytes = bytesToWrite ?: ByteArray(0)
                contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                    stream.write(outBytes)
                    stream.flush()
                } ?: throw IllegalStateException("Unable to open output stream for selected URI.")
                callback.success(
                    mapOf(
                        "saved" to true,
                        "uri" to uri.toString(),
                        "name" to queryDisplayName(uri)
                    )
                )
            } else {
                val readBytes = contentResolver.openInputStream(uri)?.use { stream ->
                    stream.readBytes()
                } ?: throw IllegalStateException("Unable to open input stream for selected URI.")
                callback.success(
                    mapOf(
                        "picked" to true,
                        "uri" to uri.toString(),
                        "name" to queryDisplayName(uri),
                        "bytes" to readBytes
                    )
                )
            }
        } catch (e: Exception) {
            callback.error("IO_ERROR", e.message ?: "Document I/O failed.", null)
        }
    }

    private fun queryDisplayName(uri: Uri): String {
        var name = uri.lastPathSegment ?: "document"
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && !cursor.isNull(idx)) {
                    name = cursor.getString(idx)
                }
            }
        }
        return name
    }

    private fun getOrCreateKeystoreSecretKey(forceRecreate: Boolean): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        if (forceRecreate && keyStore.containsAlias(KEY_ALIAS)) {
            keyStore.deleteEntry(KEY_ALIAS)
        }
        val existing = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) {
            return existing.secretKey
        }
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    private fun loadOrCreateMasterKey(forceRotate: Boolean): ByteArray {
        val wrappedFile = File(noBackupFilesDir, "master_key.wrapped")
        if (!forceRotate && wrappedFile.exists()) {
            val blob = wrappedFile.readBytes()
            if (blob.size > 1 + 12 + 16) {
                val ivLen = blob[0].toInt() and 0xFF
                if (ivLen in 12..16 && blob.size > 1 + ivLen + 16) {
                    val iv = blob.copyOfRange(1, 1 + ivLen)
                    val cipherBytes = blob.copyOfRange(1 + ivLen, blob.size)
                    val secretKey = getOrCreateKeystoreSecretKey(forceRecreate = false)
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(128, iv))
                    val rawKey = cipher.doFinal(cipherBytes)
                    if (rawKey.size == 32) {
                        return rawKey
                    }
                }
            }
        }

        val secretKey = getOrCreateKeystoreSecretKey(forceRecreate = forceRotate)
        val rawKey = ByteArray(32)
        SecureRandom().nextBytes(rawKey)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey)
        val iv = cipher.iv
        val cipherBytes = cipher.doFinal(rawKey)

        val tmpFile = File(noBackupFilesDir, "master_key.wrapped.tmp")
        FileOutputStream(tmpFile).use { fos ->
            fos.write(byteArrayOf(iv.size.toByte()))
            fos.write(iv)
            fos.write(cipherBytes)
            fos.fd.sync()
        }
        if (!tmpFile.renameTo(wrappedFile)) {
            tmpFile.copyTo(wrappedFile, overwrite = true)
            tmpFile.delete()
        }
        return rawKey
    }
}
