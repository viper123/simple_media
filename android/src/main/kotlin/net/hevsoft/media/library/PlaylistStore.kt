package net.hevsoft.androidmedia.library

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.annotation.RequiresApi
import com.google.protobuf.ByteString
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import net.hevsoft.androidmedia.Headers
import net.hevsoft.androidmedia.PlaylistHeaders
import net.hevsoft.androidmedia.PlaylistItem
import net.hevsoft.androidmedia.Preferences
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Persists the last playlist loaded from Flutter so the service can serve media browsers and
 * playback resumption when it is started without Flutter (e.g. after process death).
 *
 * Headers are stored only when the item opted in ([AudioItem.persistUriHeaders],
 * [AudioItem.persistArtHeaders]), encrypted with an Android Keystore key (API 23+; below that
 * they are not stored).
 */
object PlaylistStore {
    private const val TAG = "PlaylistStore"
    internal const val KEY_ALIAS = "net.hevsoft.media.playlist_headers"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_IV_LENGTH = 12
    private const val GCM_TAG_BITS = 128

    /**
     * Call from the main thread so updates are queued in call order; DataStore applies them one
     * at a time, so a later playlist is never overwritten by an earlier one.
     */
    suspend fun save(context: Context, audioItems: List<AudioItem>) {
        try {
            DemoPlaybackService.PreferenceDataStore.get(context).updateData { preferences ->
                // DataStore runs this block in the caller's context (Main) and only the file
                // write on IO; move proto building and Keystore encryption off the main thread.
                withContext(Dispatchers.IO) {
                    preferences.toBuilder()
                        .clearPlaylist()
                        .addAllPlaylist(audioItems.map { it.toProto() })
                        .setEncryptedHeaders(encryptHeaders(audioItems))
                        .build()
                }
            }
        } catch (e: Exception) {
            AudioLibLog.e(TAG, "Unable to save playlist", e)
        }
    }

    /**
     * Fills [MediaItemTree] with the saved playlist, unless a playlist was already loaded.
     * Must be called from the main thread, which owns [MediaItemTree].
     */
    suspend fun ensureLoaded(context: Context) {
        if (MediaItemTree.isLoaded) return
        val restored = try {
            withContext(Dispatchers.IO) {
                val preferences = DemoPlaybackService.PreferenceDataStore.get(context).data.first()
                restore(preferences, decryptHeaders(preferences.encryptedHeaders))
            }
        } catch (e: Exception) {
            AudioLibLog.e(TAG, "Unable to restore playlist", e)
            return
        }
        // Flutter may have loaded a playlist while we were reading.
        if (!MediaItemTree.isLoaded) {
            MediaItemTree.setAudioItems(restored)
        }
    }

    internal fun restore(preferences: Preferences, headers: Map<String, Headers>): List<AudioItem> {
        return preferences.playlistList.map { item ->
            val itemHeaders = headers[item.id]
            AudioItem(
                id = item.id,
                uri = item.uri,
                artUri = item.artUri,
                title = item.title,
                album = item.album,
                extra = item.extraMap,
                uriHeaders = itemHeaders?.uriHeadersMap?.takeIf { it.isNotEmpty() },
                artHeaders = itemHeaders?.artHeadersMap?.takeIf { it.isNotEmpty() },
                persistUriHeaders = itemHeaders?.uriHeadersCount?.let { it > 0 } ?: false,
                persistArtHeaders = itemHeaders?.artHeadersCount?.let { it > 0 } ?: false
            )
        }
    }

    internal fun AudioItem.toProto(): PlaylistItem =
        PlaylistItem.newBuilder()
            .setId(id)
            .setUri(uri)
            .setArtUri(artUri)
            .setTitle(title)
            .setAlbum(album)
            .putAllExtra(extra.orEmpty().mapNotNull { (k, v) -> (v as? String)?.let { k to it } }
                .toMap())
            .build()

    /** The headers each item opted in to persisting; items with none are left out. */
    internal fun headersToPersist(audioItems: List<AudioItem>): PlaylistHeaders {
        val headers = PlaylistHeaders.newBuilder()
        audioItems.forEach { item ->
            val uriHeaders = item.uriHeaders.orEmpty().takeIf { item.persistUriHeaders }.orEmpty()
            val artHeaders = item.artHeaders.orEmpty().takeIf { item.persistArtHeaders }.orEmpty()
            if (uriHeaders.isNotEmpty() || artHeaders.isNotEmpty()) {
                headers.putItems(
                    item.id,
                    Headers.newBuilder()
                        .putAllUriHeaders(uriHeaders)
                        .putAllArtHeaders(artHeaders)
                        .build()
                )
            }
        }
        return headers.build()
    }

    internal fun encryptHeaders(audioItems: List<AudioItem>): ByteString {
        val headers = headersToPersist(audioItems)
        if (headers.itemsCount == 0 || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return ByteString.EMPTY
        }
        return try {
            ByteString.copyFrom(encrypt(headers.toByteArray()))
        } catch (e: Exception) {
            // Keep saving the playlist; it just won't carry headers.
            AudioLibLog.e(TAG, "Unable to encrypt headers", e)
            ByteString.EMPTY
        }
    }

    internal fun decryptHeaders(data: ByteString): Map<String, Headers> {
        if (data.isEmpty || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyMap()
        return try {
            PlaylistHeaders.parseFrom(decrypt(data.toByteArray())).itemsMap
        } catch (e: Exception) {
            // E.g. the Keystore key was invalidated; restore the playlist without headers.
            AudioLibLog.e(TAG, "Unable to decrypt headers", e)
            emptyMap()
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun encrypt(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, key()) }
        return cipher.iv + cipher.doFinal(plain)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun decrypt(data: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(GCM_TAG_BITS, data, 0, GCM_IV_LENGTH))
        }
        return cipher.doFinal(data, GCM_IV_LENGTH, data.size - GCM_IV_LENGTH)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            .apply {
                init(
                    KeyGenParameterSpec.Builder(
                        KEY_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                    )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .build()
                )
            }
            .generateKey()
    }
}
