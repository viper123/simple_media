package net.hevsoft.media

import net.hevsoft.androidmedia.library.AudioLibLog
import java.util.concurrent.ConcurrentHashMap

class AudioPlayerRegistry {

    val tag = "AudioPlayerRegistry"
    private val players = ConcurrentHashMap<String, AudioPlayerWrapper>()

    fun registerAudioPlayer(id: String, player: AudioPlayerWrapper) {
        AudioLibLog.m(tag, "registerAudioPlayer $id")
        if (players.contains(id)) {
            AudioLibLog.m(tag, "Audio player with id $id already registered")
            return
        }
        players[id] = player
    }

    fun unregisterAudioPlayer(id: String) {
        AudioLibLog.m(tag, "unregisterAudioPlayer $id")
        if (players.containsKey(id)) {
            players.remove(id)
        } else {
            AudioLibLog.m(tag, "Audio player with id $id not found")
        }
    }

    fun getAudioPlayer(id: String): AudioPlayerWrapper? {
        AudioLibLog.m(tag, "getAudioPlayer $id")
        if (players.contains(id)) {
            return players[id]
        } else {
            AudioLibLog.m(tag, "Audio player with id $id not found")
            return null
        }
    }

    fun isEmpty(): Boolean = players.isEmpty()

    fun dispose() {
        AudioLibLog.m(tag, "dispose")
        printRegistryContent()
        players.forEach { (_, player) ->
            player.dispose(fromControllerCallback = false)
        }
        players.clear()
    }

    private fun printRegistryContent() {
        var tmp = "["
        players.forEach { (t, u) -> tmp += "{$t: ${u}} " }
        tmp += "]"
        AudioLibLog.m(tag, "printRegistryContent: $tmp")
    }
}