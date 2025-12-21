package net.hevsoft.androidmedia.library

object PluginInstallConfiguration {

    private var installedAudioConfig: AudioConfiguration? = null

    fun installAudioConfig(audioConfig: AudioConfiguration) {
        installedAudioConfig = audioConfig
    }

    fun getAudioConfig(): AudioConfiguration? {
        return installedAudioConfig
    }
}

data class AudioConfiguration(
    val notificationId: Int,
    val channelId: String,
    val intentClass: Class<*>
)

/**
 * This exception is throws when
 * [PluginInstallConfiguration.installAudioConfig] is not called before
 * [DemoPlaybackService] is created.
 */
class AudioConfigNotInstalledException : Exception()