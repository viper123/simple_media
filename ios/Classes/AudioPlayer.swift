//
//  AudioPlayer.swift
//
//  Created by Elvis Rusu on 20.08.2025.
//

///
///  Externally Edited in AudioPlayerForge
///
import AVFoundation
import Kingfisher
import UIKit
import MediaPlayer
import Foundation

private let INVALID_INDEX: Int = -1
private let tag = "[AudioPlayer]"

class AudioPlayer : AudioPlayerInstance {
    //MARK: Properties
    private var disposed = false
    private var playlist: [AudioItem] = []
    private var innerPlayer: AVQueuePlayer = AVQueuePlayer()
    private var playbackIndex: Int = INVALID_INDEX
    private var progressTimer: Timer?
    private let progressUpdateInterval: TimeInterval = 0.1
    private var currentItem: AVPlayerItem? {
        return innerPlayer.currentItem
    }
    private var playbackProgressListener: PlaybackProgressClosure?
    private var durationListener: PlaybackDurationClosure?
    private var playerItemObserver: NSKeyValueObservation?
    private var playerRateObserver: NSKeyValueObservation?
    private var _playbackState : PlaybackState = .idle
    private var audioSessionConfigured = false
    private var audioSessionError: Error?

    init() {
        setupRemoteCommandCenter()
        setupEndOfTrackListener();

        let success = setupAudioSession()
        if !success {
            Log.log(tag: tag, "Warning: AudioPlayer initialized with audio session setup failure")
        }
    }

    //MARK: Remote Command Center Setup
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Enable play command
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.play()
            return .success
        }

        // Enable pause command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pause()
            return .success
        }

        // Enable stop command
        commandCenter.stopCommand.addTarget { [weak self] event in
            self?.stop()
            return .success
        }

        // Enable next track command
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            if self?.isForwardPossible() == true {
                let movedForward = self?.moveForward()
                if (!(movedForward ?? false)) {
                    Log.log(tag: tag, "Warning: Failed to move forward in playlist")
                }
                return movedForward == true ? .success : .commandFailed
            }
            return .noActionableNowPlayingItem
        }

        // Enable previous track command
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            if self?.isBackwardsPossible() == true {
                let movedBackward = self?.moveBackward()
                if (!(movedBackward ?? false)) {
                    Log.log(tag: tag, "Warning: Failed to move backward in playlist")
                }
                return movedBackward == true ? .success : .commandFailed
            }
            return .noActionableNowPlayingItem
        }

        // Enable change playback position command
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let time = CMTime(seconds: event.positionTime, preferredTimescale: 600)
                let seeked = self?.seek(to: nil, at: time)
                if (!(seeked ?? false)) {
                    Log.log(tag: tag, "Warning: Failed to seek to new position in audio player")
                }
                return seeked == true ? .success : .commandFailed
            }
            return .commandFailed
        }

        // Configure which commands are available
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        // Disable commands we don't support
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
    }

    //MARK: Setup Audio Session
    private func setupAudioSession() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // Set the audio session category with proper options
            try audioSession.setCategory(.playback,
                                         mode: .default,
                                         options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])

            // Activate the audio session
            try audioSession.setActive(true)

            // Setup notification observers for audio session interruptions
            setupAudioSessionNotifications()

            audioSessionConfigured = true
            audioSessionError = nil
            return true

        } catch let error as NSError {
            audioSessionConfigured = false
            audioSessionError = error

            Log.log(tag: tag, "Failed to set up audio session: \(error.localizedDescription)")

            // Handle specific audio session errors
            switch error.code {
            case AVAudioSession.ErrorCode.cannotInterruptOthers.rawValue:
                Log.log(tag: tag, "Cannot interrupt other audio sessions")
            case AVAudioSession.ErrorCode.unspecified.rawValue:
                Log.log(tag: tag, "Unspecified audio session error")
            case AVAudioSession.ErrorCode.cannotStartPlaying.rawValue:
                Log.log(tag: tag, "Cannot start playing - audio session error")
            case AVAudioSession.ErrorCode.cannotStartRecording.rawValue:
                Log.log(tag: tag, "Cannot start recording - not relevant for playback")
            case AVAudioSession.ErrorCode.badParam.rawValue:
                Log.log(tag: tag, "Bad parameter passed to audio session")
            case AVAudioSession.ErrorCode.insufficientPriority.rawValue:
                Log.log(tag: tag, "Insufficient priority for audio session operation")
            default:
                Log.log(tag: tag, "Audio session error code: \(error.code)")
            }

            return false
        }
    }

    private func setupAudioSessionNotifications() {
        let notificationCenter = NotificationCenter.default

        // Handle audio interruptions (calls, alarms, etc.)
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // Handle route changes (headphones plugged/unplugged, etc.)
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue) else {
            return
        }

        switch interruptionType {
        case .began:
            // Audio interruption began (incoming call, alarm, etc.)
            Log.log(tag: tag, "Audio interruption began")
            pause()

        case .ended:
            // Audio interruption ended
            Log.log(tag: tag, "Audio interruption ended")

            // Check if we should resume playback
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {

                // Reactivate audio session and resume playback
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    play()
                } catch {
                    Log.log(tag: tag, "Failed to reactivate audio session after interruption: \(error)")
                }
            }

        @unknown default:
            Log.log(tag: tag, "Unknown interruption type")
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            Log.log(tag: tag, "Audio route changed: old device unavailable")
            pause()

        case .newDeviceAvailable:
            Log.log(tag: tag,"Audio route changed: new device available")

        case .routeConfigurationChange:
            Log.log(tag: tag, "Audio route configuration changed")

        case .categoryChange:
            Log.log(tag: tag, "Audio category changed")

        default:
            Log.log(tag: tag, "Audio route changed: \(reason.rawValue)")
        }
    }

    func isAudioSessionReady() -> Bool {
        return audioSessionConfigured
    }

    func retryAudioSessionSetup() -> Bool {
        guard !audioSessionConfigured else {
            return true // Already configured
        }

        Log.log(tag: tag, "Retrying audio session setup...")
        return setupAudioSession()
    }

    func getAudioSessionError() -> Error? {
        return audioSessionError
    }


    //MARK: Load Playlist
    var items : [AVPlayerItem] {
        return innerPlayer.items()
    }
    var playlistItems: [AudioItem] {
        return self.playlist
    }
    func loadPlaylist(_ playlist: [AudioItem]) -> Bool {
        if (disposed) {
            Log.log(tag: tag, "Impossible to loadPlaylist , player is already disposed")
            return false
        }
        updatePlaybackState(newState: .loading)
        self.playlist.removeAll()
        self.playlist.append(contentsOf: playlist)

        let playlistItems: [AVPlayerItem] = constructPlaylistItems()

        disposeQueuePlayer(player: innerPlayer)

        innerPlayer = AVQueuePlayer(items: playlistItems)
        setListenerToNewPlayer(innerPlayer)

        currentItemChanged(innerPlayer.currentItem)

        updateDuration()
        updatePlaybackState(newState: .idle)

        return true
    }

    private func constructPlaylistItems() -> [AVPlayerItem] {
        var playlistItems: [AVPlayerItem] = []
        var index = 0
        playlist.forEach { item in
            let asset: AVURLAsset
            if let headers = item.uriHeaders, !headers.isEmpty {
                let options = ["AVURLAssetHTTPHeaderFieldsKey": headers]
                asset = AVURLAsset(url: item.uri, options: options)
            } else {
                asset = AVURLAsset(url: item.uri)
            }
            let playerItem = AVPlayerItem(asset: asset)
            playerItem.index = index
            index += 1
            playlistItems.append(playerItem)
        }

        return playlistItems
    }

    static func parsePlaylist(from data: Any?) -> [AudioItem] {
        // Safely cast data to array of dictionaries
        guard let dataArray = data as? [[String: Any]] else {
            return []
        }

        return dataArray.compactMap { dict in
            // Extract required fields
            guard let id = dict["id"] as? String,
                  let uriString = dict["uri"] as? String,
                  let uri = URL(string: uriString),
                  let artUriString = dict["artUri"] as? String,
                  let artUri = URL(string: artUriString),
                  let title = dict["title"] as? String,
                  let album = dict["album"] as? String
            else {
                return nil
            }

            // Extract optional fields - handle both null and missing cases
            let extra: [String: String]? = {
                if let value = dict["extra"] {
                    return value as? [String: String]
                }
                return nil
            }()

            let uriHeaders: [String: String]? = {
                if let value = dict["uriHeaders"] {
                    return value as? [String: String]
                }
                return nil
            }()

            let artHeaders: [String: String]? = {
                if let value = dict["artHeaders"] {
                    return value as? [String: String]
                }
                return nil
            }()

            return AudioItem(
                id: id,
                uri: uri,
                artUri: artUri,
                title: title,
                album: album,
                extra: extra,
                uriHeaders: uriHeaders,
                artHeaders: artHeaders
            )
        }
    }

    private func setListenerToNewPlayer(_ player: AVQueuePlayer) {
        playerItemObserver?.invalidate()
        playerItemObserver = player.observe(\.currentItem, options: [.new, .old]) { [weak self] player, change in
            self?.currentItemChanged(player.currentItem)
        }

        playerRateObserver?.invalidate()
        playerRateObserver = player.observe(\.rate, options: [.new, .old]) {[weak self] player, change in
            Task {
                let rate = player.rate
                let playing = rate > 0
                await MainActor.run { [weak self] in
                    guard let currentState = self?._playbackState else { return }
                    if (playing) {
                        if (currentState != .playing) {
                            self?.updatePlaybackState(newState: .playing)
                        }
                    } else {
                        if (currentState == .playing) {
                            self?.updatePlaybackState(newState: .paused)
                        }
                    }
                }
            }
        }
        player.allowsExternalPlayback = true
    }

    //MARK: Active Index
    private func currentItemChanged(_ currentItem: AVPlayerItem? ) {
        guard let item = currentItem else { playbackIndex = INVALID_INDEX; return }

        let newIndex = item.index ?? INVALID_INDEX
        if (newIndex == playbackIndex) {
            return
        }

        //Reset duration to not accidently use previous item cached duration
        currentItemDuration = nil

        playbackIndex = newIndex

        if (playbackIndex != INVALID_INDEX) {
            updateMetadata(playlist[newIndex])
            activeIndexListener?(playbackIndex)
            updateDuration()
        }
    }

    //MARK: End of Track Listener
    private func setupEndOfTrackListener() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in

            guard let finishedIndex = self?.innerPlayer.currentItem?.index else {
                self?.transitionToErrorState(error: .unableToExtractIndex, msg: "Could not determine finished index")
                return
            }

            if (finishedIndex == (self?.playlist.count ?? 0) - 1) {
                self?.stop()
            }
        }
    }

    //MARK: Metadata, Rate and Duration
    private func updateMetadata(_ item: AudioItem) {
        let rate = innerPlayer.rate
        Task { [rate] in

            var nowPlayingInfo: [String: Any] = [:]

            // Basic metadata
            nowPlayingInfo[MPMediaItemPropertyTitle] = item.title
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = item.album

            // Playback info
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: rate)

            // Duration and current time
            if let duration = self.currentItemDuration {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration.seconds)
            }

            let currentTime = innerPlayer.currentTime()
            if currentTime.isValid && !currentTime.isIndefinite {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentTime.seconds)
            }

            // Track info
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = NSNumber(value: playbackIndex)
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = NSNumber(value: playlist.count)

            // Media type
            nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = NSNumber(value: MPNowPlayingInfoMediaType.audio.rawValue)

            // Artwork
            var metadataImage : UIImage? = nil
            if let image = await getArtwork(from: item.artUri, headers: item.artHeaders) {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                    boundsSize: image.size,
                    requestHandler: { (size) -> UIImage in return image }
                )
                metadataImage = image
            }

            await MainActor.run { [nowPlayingInfo, metadataImage] in
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                metadataUpdateListener?(item, metadataImage)
            }
        }
    }

    private func updateNowPlayingPlaybackRate() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: innerPlayer.rate)

        let currentTime = innerPlayer.currentTime()
        if currentTime.isValid && !currentTime.isIndefinite {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentTime.seconds)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    //MARK: Play, Pause, Stop
    func play() {
        if (disposed) {
            Log.log(tag: tag, "Impossible to play , player is already disposed")
            return
        }
        if (innerPlayer.rate > 0) {
            Log.log(tag: tag, "Player is already playing")
            return
        }
        innerPlayer.play()
        startProgressUpdates()
        updatePlaybackState(newState: .playing)
        updateNowPlayingPlaybackRate()
    }

    func pause() {
        if (disposed) {
            Log.log(tag: tag, "Impossible to pause , player is already disposed")
            return
        }
        if (innerPlayer.rate <= 0) {
            Log.log(tag: tag, "Player is already paused")
            return
        }
        innerPlayer.pause()
        stopProgressUpdates()
        updatePlaybackState(newState: .paused)
    }

    func stop() {
        pause()
        rebuildQueueFromIndex(0)
        innerPlayer.seek(to: .zero)
        updateProgress()
        updatePlaybackState(newState: .idle)
        updateNowPlayingPlaybackRate()
    }

    //MARK: Seek
    func moveForward() -> Bool {
        if (playbackIndex == INVALID_INDEX) {
            return false
        }

        if (!isForwardPossible()) {
            return false
        }

        return seek(to: playbackIndex + 1)
    }

    func isForwardPossible() -> Bool {
        if (disposed) {
            Log.log(tag: tag, "Impossible to check forward possibility , player is already disposed")
            return false
        }
        let newIndex = playbackIndex + 1
        return newIndex >= 0 && newIndex < playlist.count
    }

    func moveBackward() -> Bool {
        if (playbackIndex == INVALID_INDEX) {
            return false
        }

        if (!isBackwardsPossible()) {
            return false
        }

        return seek(to: playbackIndex - 1)
    }

    func isBackwardsPossible() -> Bool {
        if (disposed) {
            Log.log(tag: tag, "Impossible to check backward possibility , player is already disposed")
            return false
        }
        let newIndex = playbackIndex - 1
        return newIndex >= 0 && newIndex < playlist.count
    }

    func seek(to index:Int? = nil, at time:CMTime? = nil) -> Bool {

        if (disposed) {
            Log.log(tag: tag, "Impossible to seek , player is already disposed")
            return false;
        }
        if let newIndex = index {
            let currentItems = playlist

            guard newIndex >= 0 && newIndex < currentItems.count else {
                let errorMsg = "Invalid index: \(newIndex). Valid range: 0-\(currentItems.count - 1)"
                Log.log(tag: tag, errorMsg)
                return false;
            }

            let currentIndex = self.playbackIndex

            if newIndex != currentIndex {
                if newIndex > currentIndex {
                    let itemsToSkip = newIndex - currentIndex
                    for _ in 0..<itemsToSkip {
                        innerPlayer.advanceToNextItem()
                    }
                } else {
                    let wasPlaying = innerPlayer.rate != 0

                    rebuildQueueFromIndex(newIndex)

                    if (wasPlaying) {
                        innerPlayer.play()
                    }
                }
            }
        }
        if let newTime = time {
            let wasPlaying = innerPlayer.rate != 0
            updatePlaybackState(newState: .seeking)
            innerPlayer.seek(to: newTime) { [weak self] completed in
                self?.updatePlaybackState(newState: wasPlaying ? .playing : .paused)
                self?.updateNowPlayingPlaybackRate()
            }
        }

        return true;
    }

    private func rebuildQueueFromIndex(_ startIndex: Int) {
        //Execution time: 0.0060 s
        let playlistItems = constructPlaylistItems()
        let newItems = Array(playlistItems[startIndex...])
        //Execution time: 0.0035 s
        disposeQueuePlayer(player: innerPlayer)
        //Execution time: 0.0027 s
        innerPlayer = AVQueuePlayer(items: newItems)
        setListenerToNewPlayer(innerPlayer)

        currentItemChanged(innerPlayer.currentItem)
    }

    //MARK: Progress and duration
    var currentItemDuration : CMTime?

    func getDurationForCurrentItem() async throws -> CMTime? {
        guard let asset = currentItem?.asset else { return nil }
        return try await asset.load(.duration)
    }

    private func updateDuration() {
        Task {
            guard let toUpdateDuration = try await getDurationForCurrentItem() else {
                Log.log(tag: tag, "Duration is not available")
                return
            }
            currentItemDuration = toUpdateDuration

            durationListener?(toUpdateDuration.seconds * 1000)

            // Update Now Playing info with duration
            updateNowPlayingPlaybackRate()
        }
    }

    private func startProgressUpdates() {
        stopProgressUpdates()

        progressTimer = Timer.scheduledTimer(withTimeInterval: progressUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func stopProgressUpdates() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        Log.log(tag: tag, "updateProgress")
        guard let progressClosure = playbackProgressListener else {
            return
        }

        let currentTime = innerPlayer.currentTime()
        guard let currentDuration = currentItemDuration else {
            Log.log(tag: tag, "currentDuration is null")
            return
        }

        // Only update if we have valid time values
        guard currentTime.isValid && !currentTime.isIndefinite else {
            Log.log(tag: tag, "updateProgress: currentTime is invalid")
            return
        }

        let currentMs = currentTime.seconds * 1000.0
        guard let durationMs = currentDuration.isValid && currentDuration.isNumeric ? currentDuration.seconds * 1000.0 : nil else {
            Log.log(tag: tag, "Unable to extract duration")
            return
        }

        DispatchQueue.main.async {
            progressClosure(currentMs, durationMs)
        }

        // Update Now Playing elapsed time periodically
        if let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            var updatedInfo = nowPlayingInfo
            updatedInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentTime.seconds)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
        }
    }

    func setDurationListener(_ listener: PlaybackDurationClosure?) {
        if (disposed) {
            Log.log(tag: tag, "Unable to set duration listener, player disposed")
            return
        }
        self.durationListener = listener
    }

    func setPlaybackProgressListener(_ listener: PlaybackProgressClosure?) {
        if (disposed) {
            Log.log(tag: tag, "Unable to set progress listener, player disposed")
            return
        }
        self.playbackProgressListener = listener
    }

    //MARK: Playback state
    var playbackState : PlaybackState {
        return _playbackState
    }

    private func updatePlaybackState(newState : PlaybackState) {
        if (newState != _playbackState) {
            playbackStateListener?(newState)
            Log.log(tag: tag, "Playback state changed from \(_playbackState) to \(newState)")
            _playbackState = newState
        }
    }

    private var playbackStateListener : PlaybackStateChangeClosure?
    func setPlaybackStateListener(_ listener: PlaybackStateChangeClosure?) {
        self.playbackStateListener = listener
    }

    private var activeIndexListener: ActiveIndexChangeClosure?
    func setActiveIndexListener(_ listener: ActiveIndexChangeClosure?) {
        self.activeIndexListener = listener
    }

    //MARK: Metadata Updates
    private var metadataUpdateListener: UpdateMetadataClosure?
    func setUpdateMetadataListener(_ listener: UpdateMetadataClosure?) {
        self.metadataUpdateListener = listener
    }

    //MARK: Errors
    private var errorListener: AudioPlayerErrorClosure?
    func setErrorListener(_ listener: AudioPlayerErrorClosure?) {
        self.errorListener = listener
    }

    private func transitionToErrorState(error: AudioPlayerErrorCode, msg: String?) {
        errorListener?(error.rawValue, msg)
        updatePlaybackState(newState: .error)
    }

    //MARK: Dispose
    private func disposeQueuePlayer(player : AVQueuePlayer) {
        playerItemObserver?.invalidate()
        playerRateObserver?.invalidate()
        player.removeAllItems()
        player.pause()
    }

    func dispose() {
        // Clean up Now Playing info and remote commands
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)

        stopProgressUpdates()
        disposed = true
        innerPlayer.removeAllItems()
        innerPlayer.pause()

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            Log.log(tag: tag, "Failed to deactivate audio session: \(error)")
        }
    }
}

//MARK: AudioPlayer Model objects
struct AudioItem: Identifiable, Codable {
    let id: String
    let uri: URL
    let artUri: URL
    let title: String
    let album: String
    let extra: [String: String]?
    let uriHeaders: [String: String]?
    let artHeaders: [String: String]?
}

typealias ProgressUpdateClosure = (_ currentTimeMs: Double, _ durationMs: Double?) -> Void

enum PlaybackState {
    case idle
    case playing
    case paused
    case loading
    case seeking
    case error
}

extension PlaybackState {
    var index: Int {
        switch self {
        case .idle: return 0
        case .playing: return 1
        case .paused: return 2
        case .loading: return 3
        case .seeking: return 4
        case .error: return 5
        }
    }
}

typealias PlaybackStateChangeClosure = (PlaybackState) -> Void
typealias AudioPlayerErrorClosure = (_ errorCode: Int, _ errorMessage: String?) -> Void
typealias ActiveIndexChangeClosure = (Int) -> Void
typealias PlaybackDurationClosure = (Double) -> Void
typealias PlaybackProgressClosure = (Double, Double) -> Void
typealias UpdateMetadataClosure = (AudioItem, UIImage?) -> Void

enum AudioPlayerErrorCode: Int {
    case audioSessionSetupFailed = 1001
    case playlistLoadFailed = 1002
    case playbackFailed = 1003
    case seekFailed = 1004
    case networkError = 1005
    case invalidPlaylist = 1006
    case playerItemFailed = 1007
    case unableToExtractIndex = 1008
    case unknownError = 1999
}

extension CMTime {
    init(milliseconds: Int) {
        self = CMTime(value: CMTimeValue(milliseconds), timescale: 1000)
    }
}

extension Double {
    func toMMSSString() -> String {
        // Convert to seconds
        let totalSeconds = Int(self / 1000)

        // Handle negative time
        let absSeconds = abs(totalSeconds)

        // Calculate minutes and seconds
        let minutes = absSeconds / 60
        let seconds = absSeconds % 60

        // Format as mm:ss
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

protocol AudioPlayerInstance {}

enum AudioPlayerError : Error {
    case playerIsDisposed
}

extension AVPlayerItem {
    private struct AssociatedKeys {
        nonisolated(unsafe) static var customTag: UInt8 = 0
        nonisolated(unsafe) static var userInfo: UInt8 = 0
    }

    private var customTag: Any? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.customTag)
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.customTag, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var index: Int? {
        get {
            guard let tag = customTag as? Int else { return nil }
            return tag
        }
        set {
            customTag = newValue
        }
    }
}
