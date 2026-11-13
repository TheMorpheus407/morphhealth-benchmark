package de.themorpheus.morphhealth.local

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Keeps the 32-byte master key of the local data store.
 *
 * The master key is random. It is stored only in wrapped form: encrypted with
 * AES-256-GCM under a key that lives in the Android Keystore and cannot be
 * exported from it. The wrapped key lies in the app's private no-backup
 * directory, so it never becomes part of a cloud backup or device transfer.
 *
 * File layout of `master.key`: version (1 byte, value 1) | IV (12 bytes) |
 * ciphertext and GCM tag (48 bytes).
 */
object KeyVault {
    class KeyUnavailableException(message: String, cause: Throwable? = null) :
        Exception(message, cause)

    private const val KEYSTORE = "AndroidKeyStore"
    private const val ALIAS = "morphhealth_master_wrap_v1"
    private const val FILE_NAME = "master.key"
    private const val VERSION: Byte = 1
    private const val IV_LENGTH = 12
    private const val TAG_BITS = 128
    private const val KEY_LENGTH = 32
    private val AAD = "MorphHealth master key v1".toByteArray(Charsets.UTF_8)

    private fun wrappedFile(context: Context) = File(context.noBackupFilesDir, FILE_NAME)

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    /** Returns the master key, creating it on first use. */
    @Synchronized
    fun loadOrCreate(context: Context): ByteArray {
        val file = wrappedFile(context)
        if (file.exists()) return unwrap(file)

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        val wrappingKey = generator.generateKey()

        val master = ByteArray(KEY_LENGTH).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, wrappingKey)
        cipher.updateAAD(AAD)
        val sealed = cipher.doFinal(master)
        val iv = cipher.iv
        check(iv.size == IV_LENGTH) { "unexpected IV length" }

        val tmp = File(file.parentFile, "$FILE_NAME.tmp")
        tmp.outputStream().use { out ->
            out.write(byteArrayOf(VERSION))
            out.write(iv)
            out.write(sealed)
            out.fd.sync()
        }
        if (!tmp.renameTo(file)) {
            tmp.delete()
            throw KeyUnavailableException("The key file cannot be written.")
        }
        return master
    }

    private fun unwrap(file: File): ByteArray {
        val blob = file.readBytes()
        if (blob.size <= 1 + IV_LENGTH || blob[0] != VERSION) {
            throw KeyUnavailableException("The key file has an unknown format.")
        }
        val wrappingKey = keyStore().getKey(ALIAS, null) as? SecretKey
            ?: throw KeyUnavailableException("The key of this device is no longer available.")
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                wrappingKey,
                GCMParameterSpec(TAG_BITS, blob, 1, IV_LENGTH),
            )
            cipher.updateAAD(AAD)
            val master = cipher.doFinal(blob, 1 + IV_LENGTH, blob.size - 1 - IV_LENGTH)
            if (master.size != KEY_LENGTH) {
                throw KeyUnavailableException("The stored key has the wrong length.")
            }
            return master
        } catch (e: KeyUnavailableException) {
            throw e
        } catch (e: Exception) {
            throw KeyUnavailableException("The stored key cannot be unwrapped.", e)
        }
    }

    /** Deletes the master key. Data encrypted with it become unreadable. */
    @Synchronized
    fun reset(context: Context) {
        wrappedFile(context).delete()
        val store = keyStore()
        if (store.containsAlias(ALIAS)) store.deleteEntry(ALIAS)
    }
}
