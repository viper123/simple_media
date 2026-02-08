package net.hevsoft.androidmedia.library

import android.util.Log

object AudioLibLog {

    private var logger: Logger? = null

    fun installLogger(logger: Logger) {
        this.logger = logger
    }

    fun m(tag: String, message: String) {
        logger?.m(tag, message)
    }

    fun m(message: String) {
        logger?.m(message)
    }

    fun e(tag: String, message: String?, e: Throwable?) {
        logger?.e(tag, message, e)
    }

    fun e(tag : String, message : String) {
        logger?.e(tag, message, null)
    }
}

interface Logger {
    fun m(tag: String, message: String)

    fun m(message: String)

    fun e(tag: String, message: String?, e: Throwable?)
}

class DefaultLogger : Logger {
    override fun m(tag: String, message: String) {
        Log.d(tag, message)
    }

    override fun m(message: String) {
        Log.d("MediaAndroid", message)
    }

    override fun e(tag: String, message: String?, e: Throwable?) {
        Log.e(tag, message, e)
    }
}
