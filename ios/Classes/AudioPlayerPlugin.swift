//
//  AudioPlayerPlugin.swift
//  Runner
//
//  Created by Elvis Rusu on 04.07.2025.
//

import Flutter
import UIKit

public class AudioPlayerPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "media-comm-creator",
            binaryMessenger: registrar.messenger()
        )
        let instance = AudioPlayerPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    let registrar: FlutterPluginRegistrar;
    
    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }
    
    private let playerRegistry: DefaultAudioPlayerRegistry = DefaultAudioPlayerRegistry()

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "init":
            guard let id = call.arguments as? String else {
                Log.log("Method init received incorrect arguments \(call.arguments ?? "nil")")
                return
            }
            let playerWrapper = AudioPlayerWrapper(id: id, messenger: registrar.messenger(), registry: playerRegistry);
            playerRegistry.registerAudioPlayer(id: id, player: playerWrapper)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

protocol AudioPlayerRegistry {
    func registerAudioPlayer(id: String, player : AudioPlayerInstance)
    func unregisterAudioPlayer(id: String)
    func getAudioPlayer(id: String) -> AudioPlayerInstance?
}

class DefaultAudioPlayerRegistry: AudioPlayerRegistry {
    
    private var players: ThreadSafeDictionary<String, AudioPlayerInstance> = ThreadSafeDictionary<String, AudioPlayerInstance>()
    
    func registerAudioPlayer(id: String, player : AudioPlayerInstance) {
        
        if (players[id] != nil) {
            Log.log("Player \(player) is already registered")
            return
        }
        players[id] = player
    }
    func unregisterAudioPlayer(id: String) {
        if (players[id] == nil) {
            Log.log("Player with id:\(id) is not registered")
            return
        }
        players[id] = nil
    }
    
    func getAudioPlayer(id: String) -> AudioPlayerInstance? {
        return players[id]
    }
}
