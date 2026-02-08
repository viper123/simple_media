package net.hevsoft.androidmedia.library

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import androidx.annotation.OptIn
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.os.bundleOf
import androidx.datastore.core.DataStore
import androidx.datastore.core.Serializer
import androidx.datastore.dataStore
import androidx.media3.common.AudioAttributes
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.util.EventLogger
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
import java.io.InputStream
import java.io.OutputStream
import android.content.Intent

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
            PluginInstallConfiguration.getAudioConfig() ?: throw AudioConfigNotInstalledException()

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
        val mediaID = mediaLibrarySession.player.currentMediaItem?.mediaId
        if (mediaID == null) {
            return
        }
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
        return if (preferences != Preferences.getDefaultInstance()) preferences else null
    }

    @OptIn(UnstableApi::class)
    private inner class MediaSessionServiceListener : Listener {

        /**
         * This method is only required to be implemented on Android 12 or above when an attempt is made
         * by a media controller to resume playback when the {@link MediaSessionService} is in the
         * background.
         */
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
        private val Context._dataStore: DataStore<Preferences> by
        dataStore(
            fileName = "preferences.pb",
            serializer =
                object : Serializer<Preferences> {
                    override val defaultValue: Preferences = Preferences.getDefaultInstance()

                    override suspend fun readFrom(input: InputStream): Preferences =
                        Preferences.parseFrom(input)

                    override suspend fun writeTo(t: Preferences, output: OutputStream) =
                        t.writeTo(output)
                },
        )

        fun get(context: Context) = context.applicationContext._dataStore
    }
}