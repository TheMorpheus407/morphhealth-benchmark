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
 * Keeps the 32-byte master key of the encrypted data store.
 *
 * The master key is random and stored only wrapped (AES-256-GCM) by a
 * non-exportable key inside the Android Keystore. The wrapped key lives in
 * the app's no-backup directory, so it is never part of device backups.
 */
object KeyVault {
    private const val KEYSTORE = "AndroidKeyStore"
    private const val ALIAS = "morphhealth.master.wrap.v1"
    private const val FILE_NAME = "morphhealth.masterkey.v1"
    private const val IV_LENGTH = 12
    private const val TAG_BITS = 128

    @Synchronized
    fun loadOrCreate(context: Context): ByteArray {
        val file = File(context.noBackupFilesDir, FILE_NAME)
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (file.exists()) {
            val wrappingKey = keyStore.getKey(ALIAS, null) as? SecretKey
                ?: throw IllegalStateException("key_missing")
            val sealed = file.readBytes()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                wrappingKey,
                GCMParameterSpec(TAG_BITS, sealed, 0, IV_LENGTH),
            )
            return cipher.doFinal(sealed, IV_LENGTH, sealed.size - IV_LENGTH)
        }
        val wrappingKey = (keyStore.getKey(ALIAS, null) as? SecretKey) ?: generateWrappingKey()
        val master = ByteArray(32).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, wrappingKey)
        val sealed = cipher.iv + cipher.doFinal(master)
        val temp = File(context.noBackupFilesDir, "$FILE_NAME.tmp")
        temp.outputStream().use {
            it.write(sealed)
            it.fd.sync()
        }
        if (!temp.renameTo(file)) throw IllegalStateException("Cannot store key")
        return master
    }

    /** Deletes the wrapped master key and the Keystore key (crypto-shredding). */
    @Synchronized
    fun destroy(context: Context) {
        File(context.noBackupFilesDir, FILE_NAME).delete()
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (keyStore.containsAlias(ALIAS)) keyStore.deleteEntry(ALIAS)
    }

    private fun generateWrappingKey(): SecretKey {
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }
}
