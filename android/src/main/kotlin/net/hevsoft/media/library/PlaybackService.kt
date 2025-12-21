package net.hevsoft.androidmedia.library

import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.TaskStackBuilder

class PlaybackService : DemoPlaybackService() {

    override fun getSingleTopActivity(): PendingIntent? {
        return PendingIntent.getActivity(
            this,
            0,
            Intent(this, audioConfiguration.intentClass),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    override fun getBackStackedActivity(): PendingIntent? {
        return TaskStackBuilder.create(this).run {
            addNextIntent(Intent(this@PlaybackService, audioConfiguration.intentClass))
            addNextIntent(Intent(this@PlaybackService, audioConfiguration.intentClass))
            getPendingIntent(0, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
    }
}