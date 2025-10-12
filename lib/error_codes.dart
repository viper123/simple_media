import 'package:media/audio_player.dart';
import 'package:media/constants.dart';

final _appleNativeErrorMap = {
  1001: ErrorCode.appleAudioSessionSetupFailed,
  1002: ErrorCode.applePlaylistLoadFailed,
  1003: ErrorCode.applePlaybackFailed,
  1004: ErrorCode.appleSeekFailed,
  1005: ErrorCode.appleNetworkError,
  1006: ErrorCode.appleInvalidPlaylist,
  1007: ErrorCode.applePlayerItemFailed,
  1999: ErrorCode.appleUnknownError,
};

enum ErrorCode {
  unknownError, //reserved for errors that cannot be parsed from code
  incorrectPlatformReturnType,
  invalidPlaybackStateIndex,
  invalidDurationMsValue,
  invalidProgressMsValue,
  playlistNotUpdatedOnNative,
  playbackMethodNotExecutedOnNative,
  disposeNotExecutedOnNative,
  //Apple Native specific error codes
  appleAudioSessionSetupFailed,
  applePlaylistLoadFailed,
  applePlaybackFailed,
  appleSeekFailed,
  appleNetworkError,
  appleInvalidPlaylist,
  applePlayerItemFailed,
  appleUnknownError;

  static fromIntCode(int code) {
    if (code < 7) {
      //disposeNotExecutedOnNative
      return values[code];
    }
    if (code >= 1001 && code <= 1999) {
      return _appleNativeErrorMap[code];
    }
    return unknownError;
  }
}

class Error {
  final ErrorCode code;
  final String message;

  Error({required this.code, this.message = emptyString});

  factory Error.fromCode(ErrorCode code) => Error(code: code);

  factory Error.fromCodeAndMessage(ErrorCode code, String message) =>
      Error(code: code, message: message);

  @override
  bool operator ==(Object other) {
    return other is Error && other.code == code && other.message == message;
  }

  @override
  int get hashCode => code.hashCode ^ message.hashCode;
}

extension ErrorCodesMeaning on Error {
  String get errorMeaning => switch (code) {
    ErrorCode.unknownError =>
      "Flutter Layer received an unrecognizable error code "
          "which defaulted to unknown error",
    ErrorCode.incorrectPlatformReturnType =>
      "Incorrect platform return type${message.isNotEmpty ? ", $message" : message}",
    ErrorCode.invalidPlaybackStateIndex =>
      "Invalid playback state index, index received "
          "from native should be in the range 0 ${PlaybackState.values.length} as "
          "it needs to correspond to an item from PlaybackState enum",
    ErrorCode.invalidDurationMsValue =>
      "Invalid duration in milliseconds value, should be >= 0",
    ErrorCode.invalidProgressMsValue =>
      "Invalid progress in milliseconds value, should be >= 0",
    ErrorCode.playlistNotUpdatedOnNative =>
      "Playlist not updated on native side",
    ErrorCode.playbackMethodNotExecutedOnNative =>
      "Playback method not executed on native side: $message",
    ErrorCode.disposeNotExecutedOnNative =>
      "Dispose method not executed on native side",
    ErrorCode.appleAudioSessionSetupFailed => "Audio session setup failed",
    ErrorCode.applePlaylistLoadFailed => "Playlist load failed",
    ErrorCode.applePlaybackFailed => "Playback failed",
    ErrorCode.appleSeekFailed => "Seek failed",
    ErrorCode.appleNetworkError => "Network error",
    ErrorCode.appleInvalidPlaylist => "Invalid playlist",
    ErrorCode.applePlayerItemFailed => "Player item failed",
    ErrorCode.appleUnknownError => "Unknown error",
  };
}
