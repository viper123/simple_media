//
//  AudioPlayerWrapper.swift
//  Runner
//
//  Created by Elvis Rusu on 04.07.2025.
//

import AVFoundation
import Flutter

class AudioPlayerWrapper : AudioPlayerInstance {

    private let channel: FlutterMethodChannel
    
    private let innerPlayer : AudioPlayer
    private let registry : AudioPlayerRegistry
    private let id : String
    
    
    init(id: String, messenger: FlutterBinaryMessenger, registry : AudioPlayerRegistry ) {
        channel = FlutterMethodChannel(
            name: "media-comm-\(id)",
            binaryMessenger: messenger
        )
        
        self.registry = registry
        self.id = id
        
        innerPlayer = AudioPlayer()
        
        innerPlayer.setPlaybackProgressListener { [weak self] p, d in
            guard let c = self?.channel else { return }
            c.invokeMethod("progress", arguments: p)
        }
        
        innerPlayer.setPlaybackStateListener { [weak self] s in
            guard let c = self?.channel else { return }
            
            c.invokeMethod("playbackState", arguments: s.index)
        }
        
        innerPlayer.setErrorListener { [weak self] code, msg in
            guard let c = self?.channel else { return }
            c.invokeMethod("error", arguments: code)
        }

        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "getDuration": result(self.innerPlayer.duration)
            case "loadPlaylist":
                let p = AudioPlayer.parsePlaylist(from: call.arguments)
                let success = self.innerPlayer.loadPlaylist(p)
                result(success)
            case "dispose":
                self.dispose()
                self.innerPlayer.dispose()
                result(true)
            case "play":
                self.innerPlayer.play()
                result(true)
            case "pause":
                self.innerPlayer.pause()
                result(true)
            case "stop":
                self.innerPlayer.stop()
                result(true)
            case "seekTo":
                guard let args = call.arguments as? Dictionary<String, Any> else {
                    result(false)
                    return
                }
                guard let pos = args["position"] as? Int else {
                    result(false)
                    return
                }
                guard let index = args["index"] as? Int else {
                    result(false)
                    return
                }
                let time = CMTime(milliseconds: pos)
                self.innerPlayer.seek(to: index, at: time)
                result(true)
                
            default: result(FlutterMethodNotImplemented)
            }
        }
    }

    func dispose() {
        channel.setMethodCallHandler(nil)
        innerPlayer.dispose()
        
        registry.unregisterAudioPlayer(id: id)
    }
}
