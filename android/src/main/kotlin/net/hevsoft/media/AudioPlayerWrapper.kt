package net.hevsoft.media

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodCall
import net.hevsoft.androidmedia.library.AudioConfiguration
import net.hevsoft.androidmedia.library.AudioLibLog
import net.hevsoft.androidmedia.library.PluginInstallConfiguration
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import net.hevsoft.androidmedia.library.AudioItem
import net.hevsoft.androidmedia.library.MediaItemTree
import net.hevsoft.androidmedia.library.PlaybackService
import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch
import android.content.Context
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import kotlinx.coroutines.launch
import androidx.media3.common.Player
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import android.content.ComponentName
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.delay
import androidx.media3.common.PlaybackException
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import androidx.media3.session.SessionError

class AudioPlayerWrapper(private val id: String,
                         messenger: BinaryMessenger,
                         private val context : Context,
                         private val registry: AudioPlayerRegistry) : MethodCallHandler {

    val channel : MethodChannel = MethodChannel(messenger, "media-comm-$id")
    private val mainScope = MainDisposableScope()
    private var mediaController : MediaController? = null;
    private val noisyListener : () -> Unit = {
        mediaController?.pause()
    }
    private val noisyReceiver : BecomingNoisyReceiver = BecomingNoisyReceiver().also {
        it.noisyListener = noisyListener
    }
    private val noisyIntentFilter : IntentFilter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
    private val currentPosition = MutableStateFlow(0L)
    private val duration : MutableStateFlow<Long?> = MutableStateFlow(null)
    private val progressHandler = Handler(Looper.getMainLooper())
    private var currentItemIndex : Int? = null
    private val updateProgressRunnable = object : Runnable {
        override fun run() {
            if (mediaController?.isPlaying == true) {
                val currentPositionMs = mediaController?.currentPosition
                val durationMs = mediaController?.duration

                AudioLibLog.m(tag, "updateProgressRunnable duration:${mediaController?.duration}")
                duration.value = durationMs ?: 0
                currentPosition.value = currentPositionMs ?: 0

                progressHandler.postDelayed(this, 100)
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)

        mainScope.launch {
            currentPosition.collect { pos ->
                sendProgressToFlutter(pos)
            }
        }

        mainScope.launch {
            duration.collect { duration ->
                AudioLibLog.m(tag, "collecting duration: $duration")
                if (duration != null) {
                    sendDurationToFlutter(duration)
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        AudioLibLog.m(tag, "onMethodCall: $call")

        mainScope.launch {
            handleMethodCall(call, result)
        }
    }

    private suspend fun handleMethodCall(call: MethodCall, result: Result) {
        AudioLibLog.m(tag, "handleMethodCall: $call")

        when (call.method) {
            "initAndroid" -> {
                AudioLibLog.m(tag, "start initing Android config")

                val mainActivityClassName = call.argument<String>("mainActivityClass")
                val notificationId = call.argument<Int>("notificationId")
                val channelId = call.argument<String>("channelId")

                if (mainActivityClassName == null || notificationId == null || channelId == null) {
                    result.error("Invalid arguments", "Invalid arguments", null)
                    return
                }

                val mainActivityClass = Class.forName(mainActivityClassName)

                val configuration = AudioConfiguration(notificationId, channelId, mainActivityClass)
                PluginInstallConfiguration.installAudioConfig(configuration)
                AudioLibLog.m(tag, "Android config fully initialized")
            }
            "loadPlaylist" -> {
                try {
                    val playlistMaps = call.arguments as? List<Map<String, Any?>>

                    if (playlistMaps == null) {
                        result.success(false)
                        return
                    }
                    val playlist = parsePlaylist(playlistMaps)

                    MediaItemTree.setAudioItems(playlist)


                    withController { controller ->
                        controller.setMediaItems(MediaItemTree.getChildren(MediaItemTree.getRootItem().mediaId))
                        controller.prepare()
                        controller.removeListener(playerListener)
                        controller.addListener(playerListener)

                        sendCurrentItemIndexToFlutter(MediaItemTree.indexOf(controller.currentMediaItem))

                        result.success(true)
                    }


                } catch (e : Exception) {
                    AudioLibLog.e(tag, "Error loading playlist", e)
                    result.success(false)
                }
            }
            "play" -> {
                try {
                    withController { controller ->
                        controller.play()
                        result.success(true)
                    }
                } catch (e : Exception) {
                    AudioLibLog.e(tag, "Error while playing", e)
                    result.success(false)
                }
            }
            "pause" -> {
                try {
                    withController { controller ->
                        controller.pause()
                        result.success(true)
                    }
                } catch (e : Exception) {
                    AudioLibLog.e(tag, "Error while pausing", e)
                    result.success(false)
                }
            }
            "stop" -> {
                try {
                    withController { controller ->
                        controller.stop()
                        controller.seekTo(0, 0)
                        result.success(true)
                    }
                } catch (e : Exception) {
                    AudioLibLog.e(tag, "Error while stopping", e)
                    result.success(false)
                }
            }
            "seekTo" -> {
                try {
                    val index = call.argument<Int?>("index")
                    val position = call.argument<Int?>("position")

                    AudioLibLog.m("arguments $index $position")
                    val res = seekTo(index, position)
                    result.success(res)
                } catch (e : Exception) {
                    AudioLibLog.e(tag, "Error while executing seekTo", e)
                    result.success(false)
                }
            }
            "next" -> {
                try {
                    withController { controller ->
                        controller.seekToNextMediaItem()
                        result.success(true)
                    }
                } catch (e : Exception) {
                    AudioLibLog.e(tag, "Error while executing next", e)
                    result.success(false)
                }
            }
            "prev" -> {
                try {
                    withController { controller ->
                        controller.seekToPreviousMediaItem()
                        result.success(true)
                    }
                } catch (e : Exception) {
                    AudioLibLog.e(tag, "Error while executing prev", e)
                    result.success(false)
                }
            }
            "getDuration" -> {
                try {
                    withController { controller ->
                        val durationMs = controller.duration
                        result.success(durationMs)
                    }
                } catch (e : Exception) {
                    AudioLibLog.e(tag, "Error while executing getDuration", e)
                    result.success(false)
                }
            }
            "dispose" -> {
                dispose()
            }
        }
    }

    private var noisyReceiverRegistered = false

    private fun registerNoisyReceiver() {
        if (noisyReceiverRegistered) {
            AudioLibLog.m("registerNoisyReceiver: receiver already registered!")
            return
        }
        context.registerReceiver(noisyReceiver, noisyIntentFilter)
        noisyReceiverRegistered = true
    }

    private fun unregisterNoisyReceiver() {
        if (noisyReceiverRegistered == false) {
            AudioLibLog.m("unregisterNoisyReceiver: receiver already unregistered or not registered at all")
            return
        }
        context.unregisterReceiver(noisyReceiver)
        noisyReceiverRegistered = false
    }

    private val playerListener = object : Player.Listener {

        override fun onEvents(player: Player, events: Player.Events) {
            super.onEvents(player, events)

            if (events.contains(Player.EVENT_PLAYBACK_STATE_CHANGED) ||
                events.contains(Player.EVENT_IS_PLAYING_CHANGED)) {

                if (player.isPlaying) {
                    registerNoisyReceiver()
                } else if (player.playbackState == Player.STATE_IDLE ||
                    player.playbackState == Player.STATE_ENDED) {
                    unregisterNoisyReceiver()
                }

                if (!player.isPlaying && player.playbackState == Player.STATE_READY) {
                    sendPlayerStateToFlutter(flutterStatePaused)
                }
            }
        }

        override fun onIsLoadingChanged(isLoading: Boolean) {
            super.onIsLoadingChanged(isLoading)

            if (isLoading) {
                sendPlayerStateToFlutter(flutterStateLoading)
            }
            /// We don't need to concern with isLoading == false as that
            /// state will be handled by playbackStateChanged or onIsPlayingChanged
        }

        override fun onPlayerError(error: PlaybackException) {
            sendPlayerStateToFlutter(flutterStateError)
            (AudioPlayerWrapper::sendPlayerErrorToFlutter)(error)

            unregisterNoisyReceiver()
        }

        override fun onIsPlayingChanged(isPlayingValue: Boolean) {
            if (isPlayingValue) {
                progressHandler.post(updateProgressRunnable)
                sendPlayerStateToFlutter(flutterStatePlaying)
            } else {
                progressHandler.removeCallbacks(updateProgressRunnable)
            }
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            playbackStateChanged(playbackState)
            if (playbackState == Player.STATE_READY) {
                AudioLibLog.m(tag, "onPlaybackStateChanged duration: ${mediaController?.duration}")
                duration.value = mediaController?.duration ?: 0L
            }
        }

        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int
        ) {
            currentPosition.value = newPosition.positionMs
        }

        override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
            super.onMediaMetadataChanged(mediaMetadata)
        }

        override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
            sendCurrentItemIndexToFlutter(MediaItemTree.indexOf(mediaItem))

            currentPosition.value = 0L
        }
    }

    suspend fun seekTo(index : Int?, position : Int?) : Boolean {
        if (index == null && position == null) {
            return false
        }

        return withControllerReturns { controller ->
            if (index != null && position != null) {
                sendPlayerStateToFlutter(flutterStateSeeking)
                controller.seekTo(index, position.toLong())
            } else if (index != null) {
                controller.seekTo(index, 0)
            } else if (position != null) {
                sendPlayerStateToFlutter(flutterStateSeeking)
                controller.seekTo(position.toLong())
            } else {
                throw IllegalStateException("This should not happen as this case should already be " +
                        "handled at the beginning of the seekTo method.")
            }

            return@withControllerReturns true
        }
    }

    private suspend fun fadeOutAndPause(controller : MediaController, durationMs: Long = 1000) {
        val steps = 20
        val stepDelay = durationMs / steps
        val volumeDecrement = 1f / steps

        for (i in 0 until steps) {
            controller.volume = 1f - (volumeDecrement * i)
            delay(stepDelay)
        }

        controller.pause()
        controller.volume = 1f // Reset for next play
    }

    private fun sendProgressToFlutter(progress : Long) {
        channel.invokeMethod("progress", progress.toDouble(), object : SimpleMethodResult() {
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                AudioLibLog.e(tag, "pushProgressToFlutter raised $errorCode $errorMessage")
            }
        })
    }

    private fun sendDurationToFlutter(duration : Long) {
        channel.invokeMethod("duration", duration.toDouble(), object : SimpleMethodResult() {
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                AudioLibLog.e(tag, "pushProgressToFlutter raised $errorCode $errorMessage")
            }
        })
    }

    private fun sendPlayerStateToFlutter(state : Int) {
        channel.invokeMethod("playbackState", state, object : SimpleMethodResult() {
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                AudioLibLog.e(tag, "pushPlayerStateToFlutter raised $errorCode $errorMessage")
            }
        })
    }

    private fun sendPlayerErrorToFlutter(e : PlaybackException) {
        AudioLibLog.e(tag, "onPlayerError", e)

        channel.invokeMethod("error", e.errorCode, object : SimpleMethodResult() {
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                super.error(errorCode, errorMessage, errorDetails)
                AudioLibLog.e(tag, "invoking error raised $errorCode $errorMessage")
            }
        })
    }
    private fun sendCurrentItemIndexToFlutter(newIndex : Int?) {
        AudioLibLog.m("currentItemIndexChanged: $newIndex")
        if (newIndex != null && newIndex != currentItemIndex) {
            channel.invokeMethod("activeIndex", newIndex,object : SimpleMethodResult() {
                override fun success(result: Any?) {
                    AudioLibLog.m("currentItemIndexChanged flutter: $result")
                    currentItemIndex = newIndex
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    AudioLibLog.m("currentItemIndexChanged flutter error: $errorCode $errorMessage  $errorDetails")
                }
            })

        }
    }

    private fun playbackStateChanged(playbackState : Int) {
        when (playbackState) {
            Player.STATE_IDLE -> sendPlayerStateToFlutter(flutterStateIdle)
            Player.STATE_BUFFERING -> sendPlayerStateToFlutter(flutterStateLoading)
            Player.STATE_READY -> AudioLibLog.m(tag, "playbackStateChanged STATE_READY")
            Player.STATE_ENDED -> sendPlayerStateToFlutter(flutterStateIdle)
        }
    }

    private fun parsePlaylist(playlistMaps: List<Map<String, Any?>>): List<AudioItem> {
        AudioLibLog.m(tag, "parsePlaylist: $playlistMaps")

        var result = mutableListOf<AudioItem>()
        try {
            for (map in playlistMaps) {
                val id = map["id"] as? String ?: continue
                val uri = map["uri"] as? String ?: continue
                val artUri = map["artUri"] as? String ?: continue
                val title = map["title"] as? String ?: continue
                val album = map["album"] as? String ?: continue
                val extra = map["extra"] as? Map<String, *>
                val uriHeaders = map["uriHeaders"] as? Map<String, String>
                val artHeaders = map["artHeaders"] as? Map<String, String>

                val audioItem = AudioItem(
                    id = id,
                    uri = uri,
                    artUri = artUri,
                    title = title,
                    album = album,
                    extra = extra,
                    uriHeaders = uriHeaders,
                    artHeaders = artHeaders
                )

                result.add(audioItem)
            }

        } catch (e : Exception) {
            AudioLibLog.e(tag, "Error parsing playlist", e)
        }

        return result
    }

    private suspend fun createAndCacheMediaController(context: Context) : MediaController {
            val sessionToken =
                SessionToken(context, ComponentName(context, PlaybackService::class.java))
            val controllerFuture = MediaController.Builder(context, sessionToken)
                .setListener(object : MediaController.Listener {

                    @OptIn(UnstableApi::class)
                    override fun onDisconnected(controller: MediaController) {
                        super.onDisconnected(controller)
                        val ex = PlaybackException(
                            "onDisconnected",
                            Exception(), PlaybackException.ERROR_CODE_DISCONNECTED
                        )
                        sendPlayerErrorToFlutter(ex)

                        ///
                        /// This instance of AudioPlayerWrapper is unusable
                        ///
                        dispose()
                    }

                    @OptIn(UnstableApi::class)
                    override fun onError(controller: MediaController, sessionError: SessionError) {
                        super.onError(controller, sessionError)
                        val ex = PlaybackException(
                            sessionError.message + "code: ${sessionError.code}",
                            Exception(), PlaybackException.ERROR_CODE_UNSPECIFIED
                        )

                        sendPlayerErrorToFlutter(ex)
                    }
                })
                .buildAsync()

        val newController = controllerFuture.await();

        mediaController = newController;

        return newController;
    }

    suspend fun withController(block: suspend (MediaController) -> Unit) {
        val controller = mediaController ?: createAndCacheMediaController(context)
        block(controller)
    }

    suspend fun <T> withControllerReturns(block: suspend (MediaController) -> T) : T {
        val controller = mediaController ?: createAndCacheMediaController(context)
        return block(controller)
    }

    fun dispose() {
        registry.unregisterAudioPlayer(id)

        noisyReceiver.noisyListener = null
        unregisterNoisyReceiver()

        mediaController?.removeListener(playerListener)
        mediaController?.release()
        mediaController = null

        mainScope.dispose()
    }
}

private class MainDisposableScope : CoroutineScope {

    private val job = SupervisorJob()

    override val coroutineContext: CoroutineContext
        get() = Dispatchers.Main + job

    ///
    /// Cancels the coroutine scope and cleans up resources.
    /// Call this method when the scope is no longer needed.
    ///
    fun dispose() {
        coroutineContext.cancel()
    }
}

private abstract class SimpleMethodResult : MethodChannel.Result {
    override fun success(result: Any?) {}

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}

    override fun notImplemented() {}
}

private class BecomingNoisyReceiver : BroadcastReceiver() {
    var noisyListener : (() -> Unit)? = null

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
            noisyListener?.invoke()
        }
    }
}

///
/// ExoPlayer possible states:
/// @IntDef({STATE_IDLE, STATE_BUFFERING, STATE_READY, STATE_ENDED})
///
/// Flutter layer possible states:
/// enum PlaybackState { idle, playing, paused, loading, seeking, error }
private const val flutterStateIdle = 0
private const val flutterStatePlaying = 1
private const val flutterStatePaused = 2
private const val flutterStateLoading = 3
private const val flutterStateSeeking = 4
private const val flutterStateError = 5

private const val flutterUnknowError = 0

/// Class logging tag
const val tag = "AudioPlayerWrapper"