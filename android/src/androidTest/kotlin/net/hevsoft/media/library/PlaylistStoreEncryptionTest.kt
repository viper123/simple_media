package net.hevsoft.androidmedia.library

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import com.google.protobuf.ByteString
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.security.KeyStore

/** Runs against the real Android Keystore, which Robolectric doesn't provide. */
@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 23) // Headers are not persisted below API 23.
class PlaylistStoreEncryptionTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    private val token = "Bearer secret-token-1234"
    private val item = AudioItem(
        id = "1",
        uri = "https://example.com/1.mp3",
        artUri = "https://example.com/1.png",
        title = "One",
        album = "Album",
        extra = mapOf("artist" to "Artist"),
        uriHeaders = mapOf("Authorization" to token),
        artHeaders = mapOf("Authorization" to "$token-art"),
        persistUriHeaders = true,
        persistArtHeaders = true,
    )

    @Before
    fun deleteKey() {
        androidKeyStore().deleteEntry(PlaylistStore.KEY_ALIAS)
    }

    @Test
    fun headersSurviveEncryptionRoundTrip() {
        val playlist = listOf(item, item.copy(id = "2", persistArtHeaders = false))

        val decrypted = PlaylistStore.decryptHeaders(PlaylistStore.encryptHeaders(playlist))

        assertEquals(PlaylistStore.headersToPersist(playlist).itemsMap, decrypted)
    }

    @Test
    fun ciphertextDoesNotContainTheHeaders() {
        val encrypted = PlaylistStore.encryptHeaders(listOf(item))

        assertFalse(encrypted.isEmpty)
        assertFalse(encrypted.toByteArray().containsSequence(token.toByteArray()))
    }

    @Test
    fun everyEncryptionUsesAFreshIv() {
        assertNotEquals(
            PlaylistStore.encryptHeaders(listOf(item)),
            PlaylistStore.encryptHeaders(listOf(item)),
        )
    }

    @Test
    fun tamperedDataDecryptsToNoHeaders() {
        val bytes = PlaylistStore.encryptHeaders(listOf(item)).toByteArray()
        bytes[bytes.lastIndex] = (bytes.last() + 1).toByte()

        assertEquals(emptyMap<String, Any>(), PlaylistStore.decryptHeaders(ByteString.copyFrom(bytes)))
    }

    @Test
    fun lostKeyDecryptsToNoHeaders() {
        val encrypted = PlaylistStore.encryptHeaders(listOf(item))
        androidKeyStore().deleteEntry(PlaylistStore.KEY_ALIAS)

        assertEquals(emptyMap<String, Any>(), PlaylistStore.decryptHeaders(encrypted))
    }

    @Test
    fun savedPlaylistIsRestoredWithHeadersFromDisk() = runBlocking {
        PlaylistStore.save(context, listOf(item))

        val preferences = DemoPlaybackService.PreferenceDataStore.get(context).data.first()
        val restored = PlaylistStore.restore(
            preferences,
            PlaylistStore.decryptHeaders(preferences.encryptedHeaders),
        )

        assertEquals(listOf(item), restored)
    }

    @Test
    fun savedFileIsExcludedFromBackupAndHoldsNoPlainHeaders() = runBlocking {
        PlaylistStore.save(context, listOf(item))

        val file = File(context.noBackupFilesDir, "simple_media_preferences.pb")
        assertTrue(file.exists())
        assertFalse(file.readBytes().containsSequence(token.toByteArray()))
    }

    private fun androidKeyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun ByteArray.containsSequence(needle: ByteArray): Boolean =
        (0..size - needle.size).any { start -> needle.indices.all { this[start + it] == needle[it] } }
}
