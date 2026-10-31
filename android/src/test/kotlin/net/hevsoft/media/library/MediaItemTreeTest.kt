package net.hevsoft.androidmedia.library

import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(UnstableApi::class) // MediaItem.toBundle / fromBundle
@RunWith(RobolectricTestRunner::class)
class MediaItemTreeTest {

    private val uriHeaders = mapOf("Authorization" to "Bearer uri")
    private val artHeaders = mapOf("Authorization" to "Bearer art")

    private val withHeaders = AudioItem(
        id = "1",
        uri = "https://example.com/1.mp3",
        artUri = "https://example.com/1.png",
        title = "One",
        album = "Album",
        uriHeaders = uriHeaders,
        artHeaders = artHeaders,
    )
    private val withoutHeaders = AudioItem(
        id = "2",
        uri = "https://example.com/2.mp3",
        artUri = "https://example.com/2.png",
        title = "Two",
        album = "Album",
    )

    // MediaItemTree is a process-wide object, so every test starts from a known playlist.
    @Before
    fun setUp() {
        MediaItemTree.setAudioItems(listOf(withHeaders, withoutHeaders))
    }

    private fun children() = MediaItemTree.getChildren(MediaItemTree.getRootItem().mediaId)

    @Test
    fun `root lists the playlist and is kept for an empty playlist`() {
        assertEquals(listOf("[item]1", "[item]2"), children().map { it.mediaId })
        assertTrue(MediaItemTree.isLoaded)

        MediaItemTree.setAudioItems(emptyList())

        assertTrue(children().isEmpty())
    }

    @Test
    fun `uri headers are carried as the media item tag`() {
        val (first, second) = children()

        assertEquals(uriHeaders, first.localConfiguration?.tag)
        assertNull(second.localConfiguration?.tag)
    }

    @Test
    fun `tag is not sent to remote controllers`() {
        // What external controllers receive (Timeline.Window.toBundle uses MediaItem.toBundle).
        val remote = MediaItem.fromBundle(children().first().toBundle())

        assertNull(remote.localConfiguration)
    }

    @Test
    fun `expandItem restores the tag dropped by IPC`() {
        // What the session receives from a MediaController's setMediaItems.
        val overIpc = MediaItem.fromBundle(children().first().toBundleIncludeLocalConfiguration())
        assertNull(overIpc.localConfiguration?.tag)

        val expanded = MediaItemTree.expandItem(overIpc)

        assertEquals(uriHeaders, expanded?.localConfiguration?.tag)
        assertEquals(Uri.parse(withHeaders.uri), expanded?.localConfiguration?.uri)
    }

    @Test
    fun `art headers are looked up by artwork uri`() {
        assertEquals(artHeaders, MediaItemTree.artHeaders(Uri.parse(withHeaders.artUri)))
        assertNull(MediaItemTree.artHeaders(Uri.parse(withoutHeaders.artUri)))
    }

    @Test
    fun `art headers are replaced by the next playlist`() {
        MediaItemTree.setAudioItems(listOf(withoutHeaders))

        assertNull(MediaItemTree.artHeaders(Uri.parse(withHeaders.artUri)))
    }

    @Test
    fun `getParentId returns null for an unknown parent instead of crashing`() {
        assertEquals(MediaItemTree.getRootItem().mediaId, MediaItemTree.getParentId("[item]1"))
        assertNull(MediaItemTree.getParentId("[item]1", parentId = "unknown"))
    }
}
