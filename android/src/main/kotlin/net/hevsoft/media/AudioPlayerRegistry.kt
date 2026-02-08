package net.hevsoft.media

import net.hevsoft.androidmedia.library.AudioLibLog
import java.util.concurrent.ConcurrentHashMap

class AudioPlayerRegistry {

    val tag = "AudioPlayerRegistry"
    private val players = ConcurrentHashMap<String, AudioPlayerWrapper>()

    fun registerAudioPlayer(id: String, player: AudioPlayerWrapper) {
        if (players.contains(id)) {
            AudioLibLog.m(tag, "Audio player with id $id already registered")
            return
        }
        players[id] = player
    }

    fun unregisterAudioPlayer(id: String) {
        if (players.contains(id)) {
            players.remove(id)
        } else {
            AudioLibLog.m(tag, "Audio player with id $id not found")
        }
    }

    fun getAudioPlayer(id: String): AudioPlayerWrapper? {
        if (players.contains(id)) {
            return players[id]
        } else {
            AudioLibLog.m(tag, "Audio player with id $id not found")
            return null
        }
    }

    fun dispose() {
        players.forEach { (_, player) ->
            player.dispose()
        }
        players.clear()

    }

}