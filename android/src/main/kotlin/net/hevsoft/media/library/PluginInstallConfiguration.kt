package net.hevsoft.androidmedia.library

import android.content.Context
import androidx.core.content.edit

object PluginInstallConfiguration {

    private var installedAudioConfig: AudioConfiguration? = null

    fun installAudioConfig(audioConfig: AudioConfiguration) {
        installedAudioConfig = audioConfig
    }

    fun getAudioConfig(): AudioConfiguration? {
        return installedAudioConfig
    }
}

object PersistentInstallConfiguration {

    private const val PREFS_NAME = "net.hevsoft.media.audio_config"
    private const val KEY_NOTIFICATION_ID = "notificationId"
    private const val KEY_CHANNEL_ID = "channelId"
    private const val KEY_INTENT_CLASS = "intentClass"

    private const val TAG = "PersistentInstallConfiguration"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun persistAudioConfig(context: Context, audioConfig: AudioConfiguration) {
        prefs(context).edit {
            putInt(KEY_NOTIFICATION_ID, audioConfig.notificationId)
                .putString(KEY_CHANNEL_ID, audioConfig.channelId)
                .putString(KEY_INTENT_CLASS, audioConfig.intentClass.name)
        }
    }

    fun getAudioConfig(context: Context): AudioConfiguration? {
        val prefs = prefs(context)
        if (!prefs.contains(KEY_NOTIFICATION_ID)) return null
        val channelId = prefs.getString(KEY_CHANNEL_ID, null) ?: return null
        val className = prefs.getString(KEY_INTENT_CLASS, null) ?: return null
        // Class may have been renamed/removed in an app update.
        val intentClass = try {
            Class.forName(className)
        } catch (e: ClassNotFoundException) {
            AudioLibLog.e(TAG, "ClassNotFoundException", e)
            return null
        }
        return AudioConfiguration(prefs.getInt(KEY_NOTIFICATION_ID, 0), channelId, intentClass)
    }

    /**
     * Used when the system starts the service (media button, SystemUI resumption, Android Auto)
     * before Flutter ever called `initAndroid`, e.g. right after install/update.
     */
    fun getDefaultAudioConfig(context: Context): AudioConfiguration? {
        val className = context.packageManager
            .getLaunchIntentForPackage(context.packageName)?.component?.className ?: return null
        return AudioConfiguration(DEFAULT_NOTIFICATION_ID, DEFAULT_CHANNEL_ID, Class.forName(className))
    }

    private const val DEFAULT_NOTIFICATION_ID = 1001
    private const val DEFAULT_CHANNEL_ID = "simple_media_playback"
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