package net.hevsoft.androidmedia.library

import net.hevsoft.androidmedia.PlaylistHeaders
import net.hevsoft.androidmedia.Preferences
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PlaylistStoreTest {

    private val uriHeaders = mapOf("Authorization" to "Bearer uri")
    private val artHeaders = mapOf("Authorization" to "Bearer art")

    private val item = AudioItem(
        id = "1",
        uri = "https://example.com/1.mp3",
        artUri = "https://example.com/1.png",
        title = "One",
        album = "Album",
        extra = mapOf("artist" to "Artist", "genre" to "Genre"),
        uriHeaders = uriHeaders,
        artHeaders = artHeaders,
    )

    @Test
    fun `headers are not persisted unless opted in`() {
        assertEquals(0, PlaylistStore.headersToPersist(listOf(item)).itemsCount)
    }

    @Test
    fun `only uri headers are persisted when only they are opted in`() {
        val headers = PlaylistStore.headersToPersist(listOf(item.copy(persistUriHeaders = true)))

        val persisted = headers.itemsMap.getValue("1")
        assertEquals(uriHeaders, persisted.uriHeadersMap)
        assertTrue(persisted.artHeadersMap.isEmpty())
    }

    @Test
    fun `only art headers are persisted when only they are opted in`() {
        val headers = PlaylistStore.headersToPersist(listOf(item.copy(persistArtHeaders = true)))

        val persisted = headers.itemsMap.getValue("1")
        assertTrue(persisted.uriHeadersMap.isEmpty())
        assertEquals(artHeaders, persisted.artHeadersMap)
    }

    @Test
    fun `opted in item without headers is left out`() {
        val noHeaders = item.copy(
            uriHeaders = null,
            artHeaders = emptyMap(),
            persistUriHeaders = true,
            persistArtHeaders = true,
        )

        assertEquals(0, PlaylistStore.headersToPersist(listOf(noHeaders)).itemsCount)
    }

    @Test
    fun `playlist survives a save and restore round trip`() {
        val playlist = listOf(
            item.copy(persistUriHeaders = true),
            item.copy(id = "2", persistUriHeaders = true, persistArtHeaders = true),
            item.copy(id = "3", uriHeaders = null, artHeaders = null),
        )

        val restored = saveAndRestore(playlist)

        assertEquals(
            listOf(
                // Headers that were not opted in are gone after a restore.
                item.copy(artHeaders = null, persistUriHeaders = true),
                item.copy(id = "2", persistUriHeaders = true, persistArtHeaders = true),
                item.copy(id = "3", uriHeaders = null, artHeaders = null),
            ),
            restored,
        )
    }

    @Test
    fun `playlist is restored without headers when they could not be decrypted`() {
        val playlist = listOf(item.copy(persistUriHeaders = true, persistArtHeaders = true))
        val preferences = Preferences.newBuilder()
            .addAllPlaylist(playlist.map { with(PlaylistStore) { it.toProto() } })
            .build()

        val restored = PlaylistStore.restore(preferences, headers = emptyMap()).single()

        assertEquals(item.copy(uriHeaders = null, artHeaders = null), restored)
        assertFalse(restored.persistUriHeaders)
        assertFalse(restored.persistArtHeaders)
    }

    @Test
    fun `non string extra values are dropped`() {
        val restored = saveAndRestore(listOf(item.copy(extra = mapOf("artist" to "Artist", "count" to 3))))

        assertEquals(mapOf("artist" to "Artist"), restored.single().extra)
    }

    /** Serializes like the DataStore does, minus the Keystore encryption of the headers blob. */
    private fun saveAndRestore(playlist: List<AudioItem>): List<AudioItem> {
        val saved = Preferences.newBuilder()
            .addAllPlaylist(playlist.map { with(PlaylistStore) { it.toProto() } })
            .build()
            .toByteArray()
        val savedHeaders = PlaylistStore.headersToPersist(playlist).toByteArray()

        return PlaylistStore.restore(
            Preferences.parseFrom(saved),
            PlaylistHeaders.parseFrom(savedHeaders).itemsMap,
        )
    }
}
