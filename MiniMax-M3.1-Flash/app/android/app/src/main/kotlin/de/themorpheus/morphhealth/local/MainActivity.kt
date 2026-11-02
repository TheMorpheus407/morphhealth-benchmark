package de.themorpheus.morphhealth.local

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Host activity of MorphHealth.
 *
 * It offers two narrow platform channels:
 *
 *  * `de.themorpheus.morphhealth.local/keystore` – keeps the 32 byte MorphHealth
 *    master key inside the Android keystore. The key itself never leaves the
 *    keystore, only the encrypted blob is stored in the app's private
 *    preferences.
 *  * `de.themorpheus.morphhealth.local/files` – document picker (SAF) for the
 *    plain export and for the encrypted backup.
 */
class MainActivity : FlutterActivity() {

    private val keystoreChannel = "de.themorpheus.morphhealth.local/keystore"
    private val filesChannel = "de.themorpheus.morphhealth.local/files"

    private val keystoreAlias = "morphhealth.master.v1"
    private val preferencesName = "morphhealth_keystore"
    private val blobKey = "master_key_blob"

    private var pendingCreate: MethodChannel.Result? = null
    private var pendingOpen: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, keystoreChannel)
            .setMethodCallHandler { call, result -> handleKeystore(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannel)
            .setMethodCallHandler { call, result -> handleFiles(call, result) }
    }

    // ------------------------------------------------------------ keystore

    private fun handleKeystore(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getOrCreateMasterKey" -> {
                try {
                    result.success(Base64.encodeToString(masterKey(), Base64.NO_WRAP))
                } catch (error: Exception) {
                    result.error("keystore_error", error.message, null)
                }
            }
            "resetMasterKey" -> {
                try {
                    preferences().edit().remove(blobKey).apply()
                    result.success(true)
                } catch (error: Exception) {
                    result.error("keystore_error", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun preferences() =
        getSharedPreferences(preferencesName, Activity.MODE_PRIVATE)

    /** Returns the 32 byte MorphHealth master key, creating it on first use. */
    private fun masterKey(): ByteArray {
        val stored = preferences().getString(blobKey, null)
        if (stored != null) {
            try {
                return unwrap(Base64.decode(stored, Base64.NO_WRAP))
            } catch (error: Exception) {
                preferences().edit().remove(blobKey).apply()
            }
        }
        val plain = ByteArray(32)
        SecureRandom().nextBytes(plain)
        preferences().edit()
            .putString(blobKey, Base64.encodeToString(wrap(plain), Base64.NO_WRAP))
            .apply()
        return plain
    }

    private fun keystoreKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore")
        store.load(null)
        val existing = store.getKey(keystoreAlias, null) as? SecretKey
        if (existing != null) {
            return existing
        }
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                keystoreAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build()
        )
        return generator.generateKey()
    }

    /** Encrypts the master key with the non exportable keystore key. */
    private fun wrap(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keystoreKey())
        val iv = cipher.iv
        val cipherText = cipher.doFinal(plain)
        return iv + cipherText
    }

    /** Decrypts the master key blob with the keystore key. */
    private fun unwrap(blob: ByteArray): ByteArray {
        val iv = blob.copyOfRange(0, 12)
        val cipherText = blob.copyOfRange(12, blob.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, keystoreKey(), GCMParameterSpec(128, iv))
        return cipher.doFinal(cipherText)
    }

    // --------------------------------------------------------------- files

    private fun handleFiles(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createDocument" -> {
                val name = call.argument<String>("suggestedName") ?: "morphhealth.txt"
                val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (pendingCreate != null) {
                    result.error("busy", "Another document request is running", null)
                    return
                }
                pendingCreate = result
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mime
                    putExtra(Intent.EXTRA_TITLE, name)
                }
                startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
            }
            "openDocument" -> {
                val mime = call.argument<String>("mimeType") ?: "*/*"
                if (pendingOpen != null) {
                    result.error("busy", "Another document request is running", null)
                    return
                }
                pendingOpen = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mime
                }
                startActivityForResult(intent, REQUEST_OPEN_DOCUMENT)
            }
            "writeFile" -> {
                val uriString = call.argument<String>("uri")
                val bytes = call.argument<ByteArray>("bytes")
                if (uriString == null || bytes == null) {
                    result.error("bad_arguments", "uri and bytes are required", null)
                    return
                }
                try {
                    contentResolver.openOutputStream(Uri.parse(uriString))?.use { stream ->
                        stream.write(bytes)
                    }
                    result.success(true)
                } catch (error: Exception) {
                    result.error("write_failed", error.message, null)
                }
            }
            "readFile" -> {
                val uriString = call.argument<String>("uri")
                if (uriString == null) {
                    result.error("bad_arguments", "uri is required", null)
                    return
                }
                try {
                    val bytes = contentResolver.openInputStream(Uri.parse(uriString))?.use { stream ->
                        stream.readBytes()
                    }
                    if (bytes == null) {
                        result.error("read_failed", "Could not read the file", null)
                    } else {
                        result.success(bytes)
                    }
                } catch (error: Exception) {
                    result.error("read_failed", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val uri: Uri? = data?.data
        when (requestCode) {
            REQUEST_CREATE_DOCUMENT -> {
                val result = pendingCreate
                pendingCreate = null
                if (resultCode == Activity.RESULT_OK && uri != null) {
                    result?.success(uri.toString())
                } else {
                    result?.success(null)
                }
            }
            REQUEST_OPEN_DOCUMENT -> {
                val result = pendingOpen
                pendingOpen = null
                if (resultCode == Activity.RESULT_OK && uri != null) {
                    result?.success(uri.toString())
                } else {
                    result?.success(null)
                }
            }
        }
    }

    companion object {
        private const val REQUEST_CREATE_DOCUMENT = 4201
        private const val REQUEST_OPEN_DOCUMENT = 4202
    }
}
