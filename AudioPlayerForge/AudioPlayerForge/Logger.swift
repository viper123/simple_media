//
//  Logger.swift
//  Runner
//
//  Created by Elvis Rusu on 09.07.2025.
//

///
///  Externally Edited in AudioPlayerForge
///
protocol Logger {
    func log(_ message: String)
}

class LoggerImpl  : Logger {
    func log(_ message: String) {
        print(message)
    }
    
    private init() {}
}

class Log {
    
    private static var instance: Logger?
    
    static func installLogger(_ logger: Logger?) {
        instance = logger
    }

    
    static func log(tag : String? = nil, _ message: String) {
        if let safeTag = tag {
            instance?.log("\(safeTag) \(message)")
        } else {
            instance?.log(message)
        }
        
    }
}

class DefaultiOSLogger : Logger {
    func log(_ message: String) {
        print(message)
    }
    
}
