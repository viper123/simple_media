//
//  AudioPlayer+image.swift
//  AudioPlayerForge
//
//  Created by Elvis Rusu on 23.09.2025.
//

///
///  Externally Edited in AudioPlayerForge
///
import Kingfisher
import Foundation
import UIKit

extension AudioPlayer {
    func getArtwork(from artUri: URL, headers: [String: String]? = nil) async -> UIImage? {
        var options: KingfisherOptionsInfo = []
        
        if let headers = headers {
            let modifier = AnyModifier { request in
                var r = request
                headers.forEach { key, value in
                    r.setValue(value, forHTTPHeaderField: key)
                }
                return r
            }
            options.append(.requestModifier(modifier))
        }
        
        return await withCheckedContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: artUri, options: options) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value.image)
                case .failure(let error):
                    Log.log("Unable to load image: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

