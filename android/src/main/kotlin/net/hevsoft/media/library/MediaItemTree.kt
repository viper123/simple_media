package net.hevsoft.androidmedia.library

import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.util.UnstableApi
import com.google.common.collect.ImmutableList
import net.hevsoft.androidmedia.library.MediaItemTree.ROOT_ID

object MediaItemTree {
  private var treeNodes: MutableMap<String, MediaItemNode> = mutableMapOf()
  private var titleMap: MutableMap<String, MediaItemNode> = mutableMapOf()

  private var idMap: MutableMap<String, Int> = mutableMapOf()

  /**
   * Map of each playlist item and its id, prepared for easy access.
   */
  private var playlistMap : MutableMap<String, AudioItem> = mutableMapOf()
  private const val ROOT_ID = "[rootID]"
  private const val ITEM_PREFIX = "[item]"

  private class MediaItemNode(val item: MediaItem) {
    val searchTitle = normalizeSearchText(item.mediaMetadata.title)
    val searchText =
      StringBuilder()
        .append(searchTitle)
        .append(" ")
        .append(normalizeSearchText(item.mediaMetadata.subtitle))
        .append(" ")
        .append(normalizeSearchText(item.mediaMetadata.artist))
        .append(" ")
        .append(normalizeSearchText(item.mediaMetadata.albumArtist))
        .append(" ")
        .append(normalizeSearchText(item.mediaMetadata.albumTitle))
        .toString()

    private val children: MutableList<MediaItem> = ArrayList()

    fun addChild(childID: String) {
      this.children.add(treeNodes[childID]!!.item)
    }

    fun getChildren(): List<MediaItem> {
      return ImmutableList.copyOf(children)
    }
  }

  private fun buildMediaItem(
      title: String,
      mediaId: String,
      isPlayable: Boolean,
      isBrowsable: Boolean,
      mediaType: @MediaMetadata.MediaType Int,
      subtitleConfigurations: List<MediaItem.SubtitleConfiguration> = mutableListOf(),
      album: String? = null,
      artist: String? = null,
      genre: String? = null,
      sourceUri: Uri? = null,
      imageUri: Uri? = null
  ): MediaItem {
    val metadata =
      MediaMetadata.Builder()
        .setAlbumTitle(album)
        .setTitle(title)
        .setArtist(artist)
        .setGenre(genre)
        .setIsBrowsable(isBrowsable)
        .setIsPlayable(isPlayable)
        .setArtworkUri(imageUri)
        .setMediaType(mediaType)
        .build()

    return MediaItem.Builder()
      .setMediaId(mediaId)
      .setSubtitleConfigurations(subtitleConfigurations)
      .setMediaMetadata(metadata)
      .setUri(sourceUri)
      .build()
  }

  /**
   * This method can be used to set the audio items inside the
   * MediaItemTree.
   * Items will be children of the [ROOT_ID]
   */
  fun setAudioItems(audioItems: List<AudioItem>) {
    treeNodes.clear()
    titleMap.clear()
    idMap.clear()

    // create root node.
    treeNodes[ROOT_ID] =
      MediaItemNode(
        buildMediaItem(
          title = "Root Folder",
          mediaId = ROOT_ID,
          isPlayable = false,
          isBrowsable = true,
          mediaType = MediaMetadata.MEDIA_TYPE_FOLDER_MIXED
        )
      )


      var index = 0;
    audioItems.forEach { audioItem ->
      val id = audioItem.id
      val album = audioItem.album
      val title = audioItem.title
      val artist = audioItem.extra?.get("artist") as? String ?: EMPTY_STRING
      val genre = audioItem.extra?.get("genre") as? String ?: EMPTY_STRING
      val sourceUri = audioItem.uri.toNullableUri()
      val imageUri = audioItem.artUri.toNullableUri()
      // key of such items in tree
      val idInTree = ITEM_PREFIX + id

        idMap[idInTree] = index++

      treeNodes[idInTree] =
        MediaItemNode(
          buildMediaItem(
            title = title,
            mediaId = idInTree,
            isPlayable = true,
            isBrowsable = false,
            mediaType = MediaMetadata.MEDIA_TYPE_MUSIC,
            album = album,
            artist = artist,
            genre = genre,
            sourceUri = sourceUri,
            imageUri = imageUri
          )
        )

      titleMap[title.lowercase()] = treeNodes[idInTree]!!
      treeNodes[ROOT_ID]!!.addChild(idInTree)

      playlistMap[id] = audioItem
    }
  }

    fun indexOf(item: MediaItem?) : Int? {

        val id = item?.mediaId
        if (id != null) {
            return idMap[id];
        }
        return null
    }

  fun getItem(id: String): MediaItem? {
    return treeNodes[id]?.item
  }

  fun expandItem(item: MediaItem): MediaItem? {
    val treeItem = getItem(item.mediaId) ?: return null
    @OptIn(UnstableApi::class) // MediaMetadata.populate
    val metadata = treeItem.mediaMetadata.buildUpon().populate(item.mediaMetadata).build()
    return item
      .buildUpon()
      .setMediaMetadata(metadata)
      .setSubtitleConfigurations(treeItem.localConfiguration?.subtitleConfigurations ?: listOf())
      .setUri(treeItem.localConfiguration?.uri)
      .build()
  }

  /**
   * Returns the media ID of the parent of the given media ID, or null if the media ID wasn't found.
   *
   * @param mediaId The media ID of which to search the parent.
   * @Param parentId The media ID of the media item to start the search from, or undefined to search
   *   from the top most node.
   */
  fun getParentId(mediaId: String, parentId: String = ROOT_ID): String? {
    for (child in treeNodes[parentId]!!.getChildren()) {
      if (child.mediaId == mediaId) {
        return parentId
      } else if (child.mediaMetadata.isBrowsable == true) {
        val nextParentId = getParentId(mediaId, child.mediaId)
        if (nextParentId != null) {
          return nextParentId
        }
      }
    }
    return null
  }

  /**
   * Returns the index of the [MediaItem] with the give media ID in the given list of items. If the
   * media ID wasn't found, 0 (zero) is returned.
   */
  fun getIndexInMediaItems(mediaId: String, mediaItems: List<MediaItem>): Int {
    for ((index, child) in mediaItems.withIndex()) {
      if (child.mediaId == mediaId) {
        return index
      }
    }
    return 0
  }

  /**
   * Tokenizes the query into a list of words with at least two letters and searches in the search
   * text of the [MediaItemNode].
   */
  fun search(query: String): List<MediaItem> {
    val matches: MutableList<MediaItem> = mutableListOf()
    val titleMatches: MutableList<MediaItem> = mutableListOf()
    val words = query.split(" ").map { it.trim().lowercase() }.filter { it.length > 1 }
    titleMap.keys.forEach { title ->
      val mediaItemNode = titleMap[title]!!
      for (word in words) {
        if (mediaItemNode.searchText.contains(word)) {
          if (mediaItemNode.searchTitle.contains(query.lowercase())) {
            titleMatches.add(mediaItemNode.item)
          } else {
            matches.add(mediaItemNode.item)
          }
          break
        }
      }
    }
    titleMatches.addAll(matches)
    return titleMatches
  }

  fun getRootItem(): MediaItem {
    return treeNodes[ROOT_ID]!!.item
  }

  fun getChildren(id: String): List<MediaItem> {
    return treeNodes[id]?.getChildren() ?: listOf()
  }

  private fun normalizeSearchText(text: CharSequence?): String {
    if (text.isNullOrEmpty() || text.trim().length == 1) {
      return EMPTY_STRING
    }
    return "$text".trim().lowercase()
  }
}

fun String.toNullableUri() : Uri? {
    try {
        return Uri.parse(this)
    } catch (e : Exception) {
        return null
    }
}