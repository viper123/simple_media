import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:simple_media/error_codes.dart';
import 'package:simple_media/logger.dart';
import 'package:uuid/uuid.dart';

export 'package:simple_media/logger.dart' show LogLevel;

class AudioPlayer {
  AudioPlayer({LogLevel logLevel = LogLevel.auto})
      : _logLevel = _resolveLogLevel(logLevel) {
    if (_logLevel.includesFlutter) {
      Log.installLogger(_AudioPlayerLogger());
    }
    Log.m("[AudioPlayer.Lifecycle] create instance");
  }

  /// Resolves [LogLevel.auto] against the current build mode. All other
  /// values pass through unchanged.
  static LogLevel _resolveLogLevel(LogLevel level) {
    if (level != LogLevel.auto) {
      return level;
    }
    return kDebugMode ? LogLevel.full : LogLevel.none;
  }

  /// Effective log level after [LogLevel.auto] has been resolved.
  final LogLevel _logLevel;

  bool _initialized = false;
  bool _disposed = false;

  bool get isInitialized => _initialized;

  MethodChannel? _mc;

  final List<AudioItem> _audioSource = [];

  List<AudioItem> get playlist => _audioSource;

  final _activeIndexController = StreamController<int>.broadcast();

  Stream<int> get activeIndexStream => _activeIndexController.stream;

  int activeIndex = invalidActiveIndex;

  final _errorController = StreamController<Error>.broadcast();

  Stream<Error> get errorStream => _errorController.stream;

  final _playbackController = StreamController<PlaybackState>.broadcast();

  Stream<PlaybackState> get playbackStream => _playbackController.stream;

  final _progressController = StreamController<Duration>.broadcast();

  Stream<Duration> get progressStream => _progressController.stream;

  final _durationController = StreamController<Duration?>.broadcast();

  Stream<Duration?> get durationStream => _durationController.stream;
  
  String? _id;

  Future<bool> init({
    required String androidChannelId,
    required int androidNotificationId,
    required String androidMainClass,
  }) async {
    assert(androidNotificationId != 0, "Notification Id must not be 0");
    if (_initialized) {
      return true;
    }

    final cc = const MethodChannel('media-comm-creator');
    final id = Uuid().v4();
    _id = id;

    if (_logLevel.includesNative) {
      await cc.invokeMethod('enableLogs');
    }

    final initialized = await cc.invokeMethod("init", id);

    _initialized = initialized;

    Log.m("[AudioPlayer.Lifecycle] init $id");

    _mc = MethodChannel('media-comm-$id');

    _mc?.setMethodCallHandler(_handleMethodCall);

    if (Platform.isAndroid) {
      _mc?.invokeMethod("initAndroid", {
        "channelId": androidChannelId,
        "notificationId": androidNotificationId,
        "mainActivityClass": androidMainClass,
      });
    }

    return initialized;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "activeIndex":
        {
          final safeArgument = call.arguments;
          if (safeArgument is int) {
            if (safeArgument < 0 || safeArgument >= _audioSource.length) {
              activeIndex = invalidActiveIndex;
              _activeIndexController.add(invalidActiveIndex);
              return;
            }
            activeIndex = safeArgument;
            _activeIndexController.add(safeArgument);
          } else {
            Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
          }
          break;
        }
      case "error":
        {
          final safeArgument = call.arguments;
          if (safeArgument is int) {
            final error = Error.fromCode(ErrorCode.fromIntCode(safeArgument));
            _errorController.add(error);
          } else {
            Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
          }
          break;
        }
      case "playbackState":
        {
          final safeArgument = call.arguments;
          if (safeArgument is int) {
            if (safeArgument >= 0 &&
                safeArgument < PlaybackState.values.length) {
              Log.m("Received playbackState update of $safeArgument");
              _playbackController.add(PlaybackState.values[safeArgument]);
            } else {
              Log.e(Error.fromCode(ErrorCode.invalidPlaybackStateIndex));
            }
          } else {
            Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
          }
          break;
        }
      case "progress":
        {
          final safeArgument = call.arguments;
          if (safeArgument is double) {
            if (safeArgument >= 0) {
              _progressController.add(
                Duration(milliseconds: safeArgument.toInt()),
              );
            } else {
              Log.e(Error.fromCode(ErrorCode.invalidProgressMsValue));
            }
          } else {
            Log.e(
              errorContext: "progress",
              Error.fromCode(ErrorCode.incorrectPlatformReturnType),
            );
          }
          break;
        }
      case "duration":
        {
          final safeArgument = call.arguments;
          if (safeArgument is double) {
            if (safeArgument >= 0) {
              _durationController.add(
                Duration(milliseconds: safeArgument.toInt()),
              );
            } else {
              Log.e(Error.fromCode(ErrorCode.invalidDurationMsValue));
            }
          } else {
            Log.e(
              errorContext: "duration",
              Error.fromCode(ErrorCode.incorrectPlatformReturnType),
            );
          }
          break;
        }
      case "nativeDispose":
        {
          dispose();
        }
    }
  }

  Future<Duration?> getDuration() async {
    final ms = await _mc?.safeInvokeMethod("getDuration");
    if (ms == null) {
      return null;
    }
    if (ms is double) {
      if (ms >= 0) {
        return Duration(milliseconds: ms.toInt());
      } else {
        Log.e(Error.fromCode(ErrorCode.invalidDurationMsValue));
      }
    } else {
      Log.e(
        errorContext: "getDuration",
        Error.fromCode(ErrorCode.incorrectPlatformReturnType),
      );
    }
    return null;
  }

  Future<bool> loadPlaylist(List<AudioItem> items) async {
    final List<Map<String, dynamic>> playlistMaps = items.map((item) {
      return {
        'id': item.id,
        'uri': item.uri.toString(),
        'artUri': item.artUri.toString(),
        'title': item.title,
        'album': item.album,
        'extra': item.extra,
        'uriHeaders': item.uriHeaders,
        'artHeaders': item.artHeaders,
        'persistUriHeaders': item.persistUriHeaders,
        'persistArtHeaders': item.persistArtHeaders,
      };
    }).toList();

    _audioSource.clear();
    _audioSource.addAll(items);

    bool? updated = await _mc?.safeInvokeMethod('loadPlaylist', playlistMaps);

    if (!(updated ?? false)) {
      _audioSource.clear();
      Log.e(Error.fromCode(ErrorCode.playlistNotUpdatedOnNative));
    }

    return updated == true;
  }

  Future<bool> play() async {
    if (_mc == null) {
      Log.e(Error.fromCode(ErrorCode.methodExecutedWhileNoMethodChannel));
      return false;
    }
    final processed = await _mc?.safeInvokeMethod('play');
    if (processed is bool) {
      if (!processed) {
        Log.e(
          Error.fromCodeAndMessage(
            ErrorCode.playbackMethodNotExecutedOnNative,
            'play',
          ),
        );
      }

      return processed;
    } else {
      Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
      return false;
    }
  }

  Future<bool> pause() async {
    if (_mc == null) {
      Log.e(Error.fromCode(ErrorCode.methodExecutedWhileNoMethodChannel));
      return false;
    }
    final processed = await _mc?.safeInvokeMethod('pause');
    if (processed is bool) {
      if (!processed) {
        Log.e(
          Error.fromCodeAndMessage(
            ErrorCode.playbackMethodNotExecutedOnNative,
            'pause',
          ),
        );
      }

      return processed;
    } else {
      Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
      return false;
    }
  }

  Future<void> stop({bool clearNativeNotif = false}) async {
    if (_mc == null) {
      Log.e(Error.fromCode(ErrorCode.methodExecutedWhileNoMethodChannel));
      return;
    }
    final processed = await _mc?.safeInvokeMethod('stop', {'clearNotif' : clearNativeNotif});
    if (processed is bool) {
      if (!processed) {
        Log.e(
          Error.fromCodeAndMessage(
            ErrorCode.playbackMethodNotExecutedOnNative,
            'stop',
          ),
        );
      }
    } else {
      Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
    }
  }

  Future<bool> seekTo(Duration position, {int? index}) async {
    if (_mc == null) {
      Log.e(Error.fromCode(ErrorCode.methodExecutedWhileNoMethodChannel));
      return false;
    }
    final processed = await _mc?.safeInvokeMethod('seekTo', {
      'position': position.inMilliseconds,
      'index': index,
    });
    if (processed is bool) {
      if (!processed) {
        Log.e(
          Error.fromCodeAndMessage(
            ErrorCode.playbackMethodNotExecutedOnNative,
            'seekTo',
          ),
        );
      }
      return processed;
    } else {
      Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
      return false;
    }
  }

  Future<bool> next() async {
    if (_mc == null) {
      Log.e(Error.fromCode(ErrorCode.methodExecutedWhileNoMethodChannel));
      return false;
    }
    return await _mc?.safeInvokeMethod('next');
  }

  Future<bool> previous() async {
    if (_mc == null) {
      Log.e(Error.fromCode(ErrorCode.methodExecutedWhileNoMethodChannel));
      return false;
    }
    return await _mc?.safeInvokeMethod('prev');
  }

  Future<void> dispose() async {
    Log.m("[AudioPlayer.Lifecycle] dispose id:$_id initialized: $_initialized disposed: $_disposed");
    if (!isInitialized) {
      Log.m(
          "Invoked dispose on a player that was not initialized, skip execution");
      return;
    }

    if (_disposed) {
      Log.m("AudioPlayer already disposed");
      return;
    }
    
    ///Mark as disposed so when native disposed is executed
    ///and will call back the dispose method, that thread
    ///does not create a recursive call stack issue.
    _disposed = true;
    try {
      await _mc?.invokeMethod('dispose');
    } catch (e) {
      Log.e(Error.fromCode(ErrorCode.playbackMethodNotExecutedOnNative));
    }
    _mc?.setMethodCallHandler(null);

    _mc = null;
    await _activeIndexController.close();
    await _errorController.close();
    await _playbackController.close();
    await _progressController.close();
    await _durationController.close();
  }
}

enum PlaybackState { idle, playing, paused, loading, seeking, error }

class AudioItem {
  AudioItem({
    required this.id,
    required this.uri,
    required this.artUri,
    required this.title,
    required this.album,
    Map<String, String>? extra,
    Map<String, String>? uriHeaders,
    Map<String, String>? artHeaders,
    this.persistUriHeaders = false,
    this.persistArtHeaders = false,
  })  : extra = extra == null ? null : Map.unmodifiable(extra),
        uriHeaders =
            uriHeaders == null ? null : Map.unmodifiable(uriHeaders),
        artHeaders =
            artHeaders == null ? null : Map.unmodifiable(artHeaders);

  final String id;
  final Uri uri;
  final Map<String, String>? extra;
  final Uri artUri;
  final String title;
  final String album;
  final Map<String, String>? uriHeaders;
  final Map<String, String>? artHeaders;

  /// Android only. Opt in to saving [uriHeaders] on device (encrypted) so this item can still be
  /// played after the app process is gone (e.g. playback resumption from the system media
  /// controls). Off by default, since headers often carry credentials.
  final bool persistUriHeaders;

  /// Android only. Like [persistUriHeaders], for [artHeaders], so the artwork still loads in the
  /// system media controls after the app process is gone.
  final bool persistArtHeaders;

  static const _mapEquality = MapEquality<String, String>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioItem &&
        other.id == id &&
        other.uri == uri &&
        other.artUri == artUri &&
        other.title == title &&
        other.album == album &&
        _mapEquality.equals(other.extra, extra) &&
        _mapEquality.equals(other.uriHeaders, uriHeaders) &&
        _mapEquality.equals(other.artHeaders, artHeaders) &&
        other.persistUriHeaders == persistUriHeaders &&
        other.persistArtHeaders == persistArtHeaders;
  }

  @override
  int get hashCode => Object.hash(
    id,
    uri,
    artUri,
    title,
    album,
    _mapEquality.hash(extra),
    _mapEquality.hash(uriHeaders),
    _mapEquality.hash(artHeaders),
    persistUriHeaders,
    persistArtHeaders,
  );

  @override
  String toString() {
    return 'AudioItem('
        'id: $id, '
        'uri: $uri, '
        'extra: $extra, '
        'artUri: $artUri, '
        'title: $title, '
        'album: $album, '
        'uriHeaders: $uriHeaders, '
        'artHeaders: $artHeaders, '
        'persistUriHeaders: $persistUriHeaders, '
        'persistArtHeaders: $persistArtHeaders)';
  }
}

const invalidActiveIndex = -1;

extension SafeMethodChannel on MethodChannel {
  Future<T?> safeInvokeMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await invokeMethod<T>(method, arguments);
    } catch (e) {
      return null;
    }
  }
}

class _AudioPlayerLogger implements Logger {
  @override
  void logM(String message) {
    log("[MediaPlugin][D] $message");
  }

  @override
  void logE(Error error, String? errorContext) {
    if (errorContext != null) {
      log(
        "[MediaPlugin][E] Error context: $errorContext, "
            "Error: ${error.errorMeaning}",
      );
    } else {
      log("[MediaPlugin][E] Error: ${error.errorMeaning}");
    }
  }
}
