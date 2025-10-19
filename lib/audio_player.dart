import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:media/error_codes.dart';
import 'package:media/logger.dart';
import 'package:uuid/uuid.dart';

class AudioPlayer {
  AudioPlayer() {
    Log.installLogger(_AudioPlayerLogger());
  }

  bool _initialized = false;

  bool get isInitialized => _initialized;

  late MethodChannel _mc;

  final List<AudioItem> _audioSource = [];

  List<AudioItem> get playlist => _audioSource;

  final _activeIndexController = StreamController<int>.broadcast();

  Stream<int> get activeIndex => _activeIndexController.stream;

  final _errorController = StreamController<Error>.broadcast();

  Stream<Error> get errorStream => _errorController.stream;

  final _playbackController = StreamController<PlaybackState>.broadcast();

  Stream<PlaybackState> get playbackStream => _playbackController.stream;

  final _progressController = StreamController<Duration>.broadcast();

  Stream<Duration> get progressStream => _progressController.stream;

  final _durationController = StreamController<Duration?>.broadcast();

  Stream<Duration?> get durationStream => _durationController.stream;

  Future<bool> init({bool enableNativeLogs = false}) async {
    if (_initialized) {
      return true;
    }

    final cc = const MethodChannel('media-comm-creator');
    final id = Uuid().v4();

    if (enableNativeLogs) {
      await cc.invokeMethod('enableLogs');
    }

    final initialized = await cc.invokeMethod("init", id);

    _initialized = initialized;

    _mc = MethodChannel('media-comm-$id');

    _mc.setMethodCallHandler(_handleMethodCall);

    return initialized;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "activeIndex":
        {
          final safeArgument = call.arguments;
          if (safeArgument is int) {
            if (safeArgument < 0 || safeArgument >= _audioSource.length) {
              _activeIndexController.add(invalidActiveIndex);
              return;
            }
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
    }
  }

  Future<Duration?> getDuration() async {
    final ms = await _mc.safeInvokeMethod("getDuration");
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
      };
    }).toList();

    _audioSource.clear();
    _audioSource.addAll(items);

    bool? updated = await _mc.safeInvokeMethod('loadPlaylist', playlistMaps);

    if (!(updated ?? false)) {
      _audioSource.clear();
      Log.e(Error.fromCode(ErrorCode.playlistNotUpdatedOnNative));
    }

    return updated == true;
  }

  Future<void> play() async {
    final processed = await _mc.safeInvokeMethod('play');
    if (processed is bool) {
      if (!processed) {
        Log.e(
          Error.fromCodeAndMessage(
            ErrorCode.playbackMethodNotExecutedOnNative,
            'play',
          ),
        );
      }
    } else {
      Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
    }
  }

  Future<void> pause() async {
    final processed = await _mc.safeInvokeMethod('pause');
    if (processed is bool) {
      if (!processed) {
        Log.e(
          Error.fromCodeAndMessage(
            ErrorCode.playbackMethodNotExecutedOnNative,
            'pause',
          ),
        );
      }
    } else {
      Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
    }
  }

  Future<void> stop() async {
    final processed = await _mc.safeInvokeMethod('stop');
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

  Future<void> seekTo(Duration position, {int? index}) async {
    final processed = await _mc.safeInvokeMethod('seekTo', {
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
    } else {
      Log.e(Error.fromCode(ErrorCode.incorrectPlatformReturnType));
    }
  }

  void dispose() {
    try {
      _mc.invokeMethod('dispose');
    } catch (e) {
      Log.e(Error.fromCode(ErrorCode.playbackMethodNotExecutedOnNative));
    }
    _mc.setMethodCallHandler(null);
    _activeIndexController.close();
    _errorController.close();
    _playbackController.close();
    _progressController.close();
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
    this.extra,
    this.uriHeaders,
    this.artHeaders,
  });

  final String id;
  final Uri uri;
  final Map<String, String>? extra;
  final Uri artUri;
  final String title;
  final String album;
  final Map<String, String>? uriHeaders;
  final Map<String, String>? artHeaders;
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
