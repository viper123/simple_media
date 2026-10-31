package net.hevsoft.androidmedia.library

import android.net.Uri
import android.os.Bundle

data class AudioItem(
    val id: String,
    val uri: String,
    val artUri: String,
    val title: String,
    val album: String,
    val extra: Map<String, Any?>? = null,
    val uriHeaders: Map<String, String>? = null,
    val artHeaders: Map<String, String>? = null,
    /** Opt-in to store [uriHeaders] on disk (encrypted) along with the item. */
    val persistUriHeaders: Boolean = false,
    /** Opt-in to store [artHeaders] on disk (encrypted) along with the item. */
    val persistArtHeaders: Boolean = false
)