# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`simple_media` is a Flutter plugin that exposes a queue-based audio player with background playback, lock-screen / notification controls, and a strongly-typed error pipeline. The Dart API lives in `lib/audio_player.dart`; the iOS engine is in `ios/Classes/`; the Android engine is in `android/src/main/kotlin/net/hevsoft/media/`. The runnable host app for manual testing is `example/`.

## Common commands

Plugin-level (run from repo root):
- `flutter pub get` — fetch Dart deps for the plugin
- `./full-refresh.sh` — `flutter clean && pub get` for plugin and example (use after dep upgrades or weird build cache state)

Example app (run from `example/`):
- `flutter run` — launch the demo on a connected device/simulator
- `flutter run -d <device-id>` — pick a specific target

Native iOS (run from `example/ios/`):
- `pod install` — refresh CocoaPods after editing `simple_media.podspec` or bumping `Kingfisher`

There are no Dart tests yet — `test/` and `integration_test/` are empty. Android unit tests are configured (`useJUnitPlatform`) but no test files exist.

## Architecture

### Two-stage MethodChannel handshake

The plugin supports multiple independent player instances per app. Channel topology:

1. **Creator channel** `media-comm-creator` (one per plugin engine attachment): handles `init` (with a Dart-generated UUID) and `enableLogs`. On `init`, native code constructs a per-instance wrapper and binds a second channel.
2. **Per-player channel** `media-comm-<uuid>`: every playback method (`loadPlaylist`, `play`, `pause`, `stop`, `seekTo`, `next`, `prev`, `getDuration`, `dispose`) and every native→Dart event (`progress`, `duration`, `playbackState`, `activeIndex`, `error`) flows through this channel.

When adding a new method, register it on **both** sides of the per-player channel (`AudioPlayer._handleMethodCall` in Dart, `AudioPlayerWrapper.handleMethodCall` on Android, `channel.setMethodCallHandler` block on iOS) and add a wrapper method on `AudioPlayer` in `lib/audio_player.dart`.

### `PlaybackState` is an ordinal contract

`PlaybackState` (`idle, playing, paused, loading, seeking, error`) is sent over the channel as an `int` index. The native sides hardcode these indices (see `flutterStateIdle = 0` ... `flutterStateError = 5` in `AudioPlayerWrapper.kt`, and `PlaybackState.index` in `AudioPlayer.swift`). **Reordering or inserting variants in the Dart enum will silently break native→Dart state delivery on both platforms** — update all three locations together.

### Error code mapping

`lib/error_codes.dart` defines a flat `ErrorCode` enum that combines Flutter-layer errors, Apple-specific codes (1001–1999), and the full Media3/ExoPlayer error code table (-110…7001). Native sides forward the raw platform integer; `ErrorCode.fromIntCode` dispatches by `Platform.isIOS` / `Platform.isAndroid` to the right map. When adding a native error case, add the int→enum mapping plus a human-readable string in the `errorMeaning` switch.

### iOS engine (`ios/Classes/`)

- `AudioPlayerPlugin.swift` — Flutter plugin entry point; owns `DefaultAudioPlayerRegistry` (a `ThreadSafeDictionary` of UUID → wrapper).
- `AudioPlayerWrapper.swift` — adapts the per-player MethodChannel to `AudioPlayer`'s closure-based listener API.
- `AudioPlayer.swift` — the actual engine. Built on `AVQueuePlayer`. Sets up `AVAudioSession` (`.playback`, allows AirPlay/Bluetooth), `MPRemoteCommandCenter` (lock-screen controls), `MPNowPlayingInfoCenter` (artwork via Kingfisher in `AudioPlayer+image.swift`), and observes interruptions / route changes to auto-pause.
- Track index is stored on `AVPlayerItem` via an associated-object `index` extension (Objective-C runtime), since AVQueuePlayer does not natively expose stable indices.
- `seekTo(index:)` rebuilds the queue from `index` onward (`rebuildQueueFromIndex`) when seeking backwards, since AVQueuePlayer cannot move backwards within a queue.
- iOS deployment target is **15.0**; depends on `Kingfisher ~> 8.6.0` for artwork loading.

### Android engine (`android/src/main/kotlin/net/hevsoft/media/`)

- `MediaPlugin.kt` — Flutter plugin entry point; owns `AudioPlayerRegistry`.
- `AudioPlayerWrapper.kt` — adapts the per-player MethodChannel to a `MediaController` connected to `PlaybackService`. All channel calls run on a `Dispatchers.Main` `SupervisorJob` scope (`MainDisposableScope`).
- `library/PlaybackService.kt` extends `library/DemoPlaybackService.kt` (a `MediaLibraryService`) — runs as a foreground service of type `mediaPlayback`, hosts the `ExoPlayer` and `MediaLibrarySession`, and persists the last-played item to a Proto DataStore (`src/main/proto/`, generated via `com.google.protobuf` Gradle plugin).
- `library/MediaItemTree.kt` — flat playlist exposed as a Media3 browse tree.
- `library/PluginInstallConfiguration.kt` — global singleton holding `AudioConfiguration` (notification id, channel id, host activity class). The Dart layer pushes this on `init` via `initAndroid`; the service reads it in `onCreate` and **throws `AudioConfigNotInstalledException` if the config wasn't installed first**. This is why `AudioPlayer.init` always sends `initAndroid` immediately after `init` on Android.
- Progress is polled at 100ms intervals via a `Handler` runnable while `isPlaying` is true (see `updateProgressRunnable`).
- The wrapper registers a `BecomingNoisyReceiver` that pauses playback on `ACTION_AUDIO_BECOMING_NOISY` (e.g., headphones unplugged); registration is lifecycle-tied to the playing state.
- Android: `compileSdk = 35`, `minSdk = 21`, JVM target 11, Media3 `1.8.0`, Kotlin `2.1.0`.

### Host app responsibilities (Android)

The host app's `AndroidManifest.xml` must declare `net.hevsoft.androidmedia.library.PlaybackService` as a foreground service with `android:foregroundServiceType="mediaPlayback"` and an intent filter for `androidx.media3.session.MediaSessionService`, plus the `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, and `POST_NOTIFICATIONS` permissions. See `example/android/app/src/main/AndroidManifest.xml` for the reference setup. The activity class name passed to `AudioPlayer.init(androidMainClass: ...)` must be a fully-qualified class name resolvable via `Class.forName` at runtime.

### Logging

Both platforms have an opt-in logger installed via `enableNativeLogs: true` on `AudioPlayer.init`. The Dart side has its own pluggable `Logger` enabled via `AudioPlayer(enableLogger: true)` (writes via `dart:developer`'s `log`). These three are independent — turning one on does not turn on the others.
