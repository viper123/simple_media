package net.hevsoft.media

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import net.hevsoft.androidmedia.library.AudioLibLog
import net.hevsoft.androidmedia.library.DefaultLogger
import android.content.Context


/** MediaPlugin */
class MediaPlugin: FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var mainChannel : MethodChannel
    private var mainBinding : FlutterPlugin.FlutterPluginBinding? = null
    private val playerRegistry = AudioPlayerRegistry()
    private var androidContext : Context? = null;


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        mainBinding = flutterPluginBinding

        mainChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "media-comm-creator")
        mainChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when(call.method) {
            "init" -> {
                val id = call.arguments as? String

                val messenger = mainBinding?.binaryMessenger
                val appContext = mainBinding?.applicationContext


                if (id != null && messenger != null && appContext != null) {
                    val fromRegistry = playerRegistry.getAudioPlayer(id)
                    if (fromRegistry == null) {
                        val newPlayer = AudioPlayerWrapper(id, messenger, appContext,playerRegistry)
                        playerRegistry.registerAudioPlayer(id, newPlayer)
                    }
                }
                result.success(true)
            }

            "enableLogs" ->  {
                AudioLibLog.installLogger(DefaultLogger())
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        playerRegistry.dispose()

        mainBinding = null
        mainChannel.setMethodCallHandler(null)
    }
}
