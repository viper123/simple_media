package net.hevsoft.androidmedia.library

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import androidx.annotation.OptIn
import androidx.annotation.RequiresPermission
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.os.bundleOf
import androidx.datastore.core.DataStore
import androidx.datastore.core.DataStoreFactory
import androidx.datastore.core.Serializer
import androidx.media3.common.AudioAttributes
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSourceBitmapLoader
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.upstream.CmcdConfiguration
import androidx.media3.exoplayer.util.EventLogger
import androidx.media3.extractor.text.SubtitleParser
import androidx.media3.session.CacheBitmapLoader
import androidx.media3.session.MediaConstants
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession
import com.google.protobuf.ByteString
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch
import net.hevsoft.androidmedia.Preferences
import net.hevsoft.media.R
import java.io.File
import java.io.InputStream
import java.io.OutputStream

/**
 * Further improvements:
 * - Use coroutines scopes that are canceled when the service is
 * destroyed.
 * - Rename File
 */

open class DemoPlaybackService : MediaLibraryService() {

    private lateinit var mediaLibrarySession: MediaLibrarySession

    protected lateinit var audioConfiguration: AudioConfiguration

    @OptIn(UnstableApi::class) // MediaSessionService.setListener
    override fun onCreate() {
        super.onCreate()

        audioConfiguration =
            PluginInstallConfiguration.getAudioConfig()
                ?: PersistentInstallConfiguration.getAudioConfig(this)
                    ?.also { PluginInstallConfiguration.installAudioConfig(it) }
                ?: PersistentInstallConfiguration.getDefaultAudioConfig(this)
                ?: throw AudioConfigNotInstalledException()

        initializeSessionAndPlayer()
        setListener(MediaSessionServiceListener())
    }

    @OptIn(UnstableApi::class)
    override fun onDestroy() {
        getBackStackedActivity()?.let { mediaLibrarySession.setSessionActivity(it) }
        mediaLibrarySession.release()
        mediaLibrarySession.player.release()
        clearListener()

        super.onDestroy()
    }

    @OptIn(UnstableApi::class) // Player.listen
    private fun initializeSessionAndPlayer() {
        val player =
            ExoPlayer.Builder(this)
                .setMediaSourceFactory(HeadersMediaSourceFactory(this))
                .setAudioAttributes(AudioAttributes.DEFAULT, /* handleAudioFocus= */ true)
                .build()
        player.addAnalyticsListener(EventLogger())
        CoroutineScope(Dispatchers.Unconfined).launch {
            player.listen { events ->
                if (
                    events.containsAny(
                        Player.EVENT_IS_PLAYING_CHANGED,
                        Player.EVENT_MEDIA_ITEM_TRANSITION
                    )
                ) {
                    storeCurrentMediaItem()
                }
            }
        }

        mediaLibrarySession =
            MediaLibrarySession.Builder(this, player, createLibrarySessionCallback())
                .setBitmapLoader(createArtworkBitmapLoader())
                .also { builder -> getSingleTopActivity()?.let { builder.setSessionActivity(it) } }
                .build()
                .also { mediaLibrarySession ->
                    // The media session always supports skip, except at the start and end of the playlist.
                    // Reserve the space for the skip action in these cases to avoid custom actions jumping
                    // around when the user skips.
                    mediaLibrarySession.sessionExtras =
                        bundleOf(
                            MediaConstants.EXTRAS_KEY_SLOT_RESERVATION_SEEK_TO_PREV to true,
                            MediaConstants.EXTRAS_KEY_SLOT_RESERVATION_SEEK_TO_NEXT to true,
                        )
                }
    }

    @OptIn(UnstableApi::class)
    private fun createArtworkBitmapLoader(): CacheBitmapLoader {
        val dataSourceFactory =
            ResolvingDataSource.Factory(DefaultDataSource.Factory(this)) { dataSpec ->
                MediaItemTree.artHeaders(dataSpec.uri)?.let { dataSpec.withAdditionalHeaders(it) }
                    ?: dataSpec
            }
        return CacheBitmapLoader(
            DataSourceBitmapLoader(
                DataSourceBitmapLoader.DEFAULT_EXECUTOR_SERVICE.get(),
                dataSourceFactory
            )
        )
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        stopSelf()
    }

    /**
     * Creates the library session callback to implement the domain logic. Can be overridden to return
     * an alternative callback, for example a subclass of [DemoMediaLibrarySessionCallback].
     *
     * This method is called when the session is built by the [DemoPlaybackService].
     */
    @OptIn(UnstableApi::class)
    protected open fun createLibrarySessionCallback(): MediaLibrarySession.Callback {
        return DemoMediaLibrarySessionCallback(this)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaLibrarySession {
        return mediaLibrarySession
    }

    /**
     * Returns the single top session activity. It is used by the notification when the app task is
     * active and an activity is in the fore or background.
     *
     * Tapping the notification then typically should trigger a single top activity. This way, the
     * user navigates to the previous activity when pressing back.
     *
     * If null is returned, [MediaSession.setSessionActivity] is not set by the demo service.
     */
    open fun getSingleTopActivity(): PendingIntent? = null

    /**
     * Returns a back stacked session activity that is used by the notification when the service is
     * running standalone as a foreground service. This is typically the case after the app has been
     * dismissed from the recent tasks, or after automatic playback resumption.
     *
     * Typically, a playback activity should be started with a stack of activities underneath. This
     * way, when pressing back, the user doesn't land on the home screen of the device, but on an
     * activity defined in the back stack.
     *
     * See [androidx.core.app.TaskStackBuilder] to construct a back stack.
     *
     * If null is returned, [MediaSession.setSessionActivity] is not set by the demo service.
     */
    open fun getBackStackedActivity(): PendingIntent? = null


    @OptIn(UnstableApi::class) // BitmapLoader
    private fun storeCurrentMediaItem() {
        val mediaID = mediaLibrarySession.player.currentMediaItem?.mediaId ?: return
        val artworkUri = mediaLibrarySession.player.currentMediaItem?.mediaMetadata?.artworkUri
        val positionMs = mediaLibrarySession.player.currentPosition
        val durationMs = mediaLibrarySession.player.duration
        CoroutineScope(Dispatchers.IO).launch {
            PreferenceDataStore.get(this@DemoPlaybackService).updateData { preferences ->
                val builder =
                    preferences
                        .toBuilder()
                        .setMediaId(mediaID)
                        .setPositionMs(positionMs)
                        .setDurationMs(durationMs)
                val artworkUriString = artworkUri?.toString() ?: EMPTY_STRING
                if (artworkUriString != preferences.artworkOriginalUri) {
                    builder.setArtworkOriginalUri(artworkUriString)
                    if (artworkUri == null) {
                        builder.setArtworkData(ByteString.EMPTY)
                    } else {
                        try {
                            val bitmap =
                                mediaLibrarySession.bitmapLoader.loadBitmap(artworkUri).await()
                            val outputStream = ByteString.newOutput()
                            bitmap.compress(
                                Bitmap.CompressFormat.PNG, /* quality= */
                                90,
                                outputStream
                            )
                            builder.setArtworkData(outputStream.toByteString())
                        } catch (e: Exception) {

                            AudioLibLog.e("DemoPlaybackService", "storeCurrentMediaItem", e)
                        }
                    }
                }
                builder.build()
            }
        }
    }

    suspend fun retrieveLastStoredMediaItem(): Preferences? {
        val preferences = PreferenceDataStore.get(this).data.first()
        return if (preferences.mediaId.isNotEmpty()) preferences else null
    }

    @OptIn(UnstableApi::class)
    private inner class MediaSessionServiceListener : Listener {

        /**
         * This method is only required to be implemented on Android 12 or above when an attempt is made
         * by a media controller to resume playback when the {@link MediaSessionService} is in the
         * background.
         */
        @RequiresPermission(Manifest.permission.POST_NOTIFICATIONS)
        override fun onForegroundServiceStartNotAllowedException() {
            if (
                Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                // Notification permission is required but not granted
                return
            }
            val notificationManagerCompat = NotificationManagerCompat.from(this@DemoPlaybackService)
            ensureNotificationChannel(notificationManagerCompat)
            val builder =
                NotificationCompat.Builder(this@DemoPlaybackService, audioConfiguration.channelId)
                    .setSmallIcon(R.drawable.media3_notification_small_icon)
                    .setContentTitle(getString(R.string.notification_content_title))
                    .setStyle(
                        NotificationCompat.BigTextStyle()
                            .bigText(getString(R.string.notification_content_text))
                    )
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setAutoCancel(true)
                    .also { builder -> getBackStackedActivity()?.let { builder.setContentIntent(it) } }
            notificationManagerCompat.notify(audioConfiguration.notificationId, builder.build())
        }
    }

    private fun ensureNotificationChannel(notificationManagerCompat: NotificationManagerCompat) {
        if (
            Build.VERSION.SDK_INT < 26 ||
            notificationManagerCompat.getNotificationChannel(audioConfiguration.channelId) != null
        ) {
            return
        }

        val channel =
            NotificationChannel(
                audioConfiguration.channelId,
                getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            )
        notificationManagerCompat.createNotificationChannel(channel)
    }

    object PreferenceDataStore {
        private var instance: DataStore<Preferences>? = null

        // Kept in noBackupFilesDir so persisted headers (often credentials) never reach Auto
        // Backup. The pre-0.2.0 `files/datastore/preferences.pb` is left alone: its generic name
        // may belong to the host app.
        @Synchronized
        fun get(context: Context): DataStore<Preferences> = instance ?: DataStoreFactory.create(
            serializer = object : Serializer<Preferences> {
                override val defaultValue: Preferences = Preferences.getDefaultInstance()

                override suspend fun readFrom(input: InputStream): Preferences =
                    Preferences.parseFrom(input)

                override suspend fun writeTo(t: Preferences, output: OutputStream) =
                    t.writeTo(output)
            },
            produceFile = {
                File(context.applicationContext.noBackupFilesDir, "simple_media_preferences.pb")
            },
        ).also { instance = it }
    }
}

/**
 * Builds each item's media source with its own data source so the item's `uriHeaders`
 * are sent on every request it makes (including HLS/DASH segments, keys, redirects).
 */
@OptIn(UnstableApi::class)
private class HeadersMediaSourceFactory(
    private val context: Context,
    private val default: DefaultMediaSourceFactory = DefaultMediaSourceFactory(context),
) : MediaSource.Factory by default {
    override fun setCmcdConfigurationFactory(cmcdConfigurationFactory: CmcdConfiguration.Factory): MediaSource.Factory {
        return default.setCmcdConfigurationFactory(cmcdConfigurationFactory)
    }

    @Deprecated("Deprecated in Java")
    @Suppress("DEPRECATION")
    // Forwards the deprecated MediaSource.Factory method as-is.
    override fun experimentalParseSubtitlesDuringExtraction(parseSubtitlesDuringExtraction: Boolean): MediaSource.Factory {
        return default.experimentalParseSubtitlesDuringExtraction(parseSubtitlesDuringExtraction)
    }

    override fun setSubtitleParserFactory(subtitleParserFactory: SubtitleParser.Factory): MediaSource.Factory {
        return default.setSubtitleParserFactory(subtitleParserFactory)
    }

    override fun experimentalSetCodecsToParseWithinGopSampleDependencies(
        codecsToParseWithinGopSampleDependencies: Int
    ): MediaSource.Factory {
        return default.experimentalSetCodecsToParseWithinGopSampleDependencies(
            codecsToParseWithinGopSampleDependencies
        )
    }

    override fun createMediaSource(mediaItem: MediaItem): MediaSource {
        @Suppress("UNCHECKED_CAST") // set by MediaItemTree.buildMediaItem
        val headers = mediaItem.localConfiguration?.tag as? Map<String, String>
            ?: return default.createMediaSource(mediaItem)
        val httpFactory = DefaultHttpDataSource.Factory().setDefaultRequestProperties(headers)
        return DefaultMediaSourceFactory(DefaultDataSource.Factory(context, httpFactory))
            .createMediaSource(mediaItem)
    }
}
