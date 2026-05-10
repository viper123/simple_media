import 'dart:io';

import 'package:simple_media/audio_player.dart';
import 'package:simple_media/constants.dart';

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


final _androidNativeErrorMap = {
  0: ErrorCode.androidUnknownError,
  -2: ErrorCode.androidInvalidState,
  -3: ErrorCode.androidBadValue,
  -4: ErrorCode.androidPermissionDenied,
  -6: ErrorCode.androidNotSupported,
  -100: ErrorCode.androidDisconnected,
  -102: ErrorCode.androidAuthenticationExpired,
  -103: ErrorCode.androidPremiumAccountRequired,
  -104: ErrorCode.androidConcurrentStreamLimit,
  -105: ErrorCode.androidParentalControlRestricted,
  -106: ErrorCode.androidNotAvailableInRegion,
  -107: ErrorCode.androidSkipLimitReached,
  -108: ErrorCode.androidSetupRequired,
  -109: ErrorCode.androidEndOfPlaylist,
  -110: ErrorCode.androidContentAlreadyPlaying,
  1000: ErrorCode.androidUnspecified,
  1001: ErrorCode.androidRemoteError,
  1002: ErrorCode.androidBehindLiveWindow,
  1003: ErrorCode.androidTimeout,
  1004: ErrorCode.androidFailedRuntimeCheck,
  2000: ErrorCode.androidIOUnspecified,
  2001: ErrorCode.androidIONetworkConnectionFailed,
  2002: ErrorCode.androidIONetworkConnectionTimeout,
  2003: ErrorCode.androidIOInvalidHTTPContentType,
  2004: ErrorCode.androidIOBadHttpStatus,
  2005: ErrorCode.androidIOFileNotFound,
  2006: ErrorCode.androidIONoPermission,
  2007: ErrorCode.androidIOCleartextNotPermitted,
  2008: ErrorCode.androidIOReadPositionOutOfRange,
  3001: ErrorCode.androidParsingContainerMalformed,
  3002: ErrorCode.androidParsingManifestMalformed,
  3003: ErrorCode.androidParsingContainerUnsupported,
  3004: ErrorCode.androidParsingManifestUnsupported,
  4001: ErrorCode.androidDecoderInitFailed,
  4002: ErrorCode.androidDecoderQueryFailed,
  4003: ErrorCode.androidDecodingFailed,
  4004: ErrorCode.androidDecodingFormatExceedsCapabilities,
  4005: ErrorCode.androidDecodingFormatUnsupported,
  4006: ErrorCode.androidDecodingResourcesReclaimed,
  5001: ErrorCode.androidAudioTrackInitFailed,
  5002: ErrorCode.androidAudioTrackWriteFailed,
  5003: ErrorCode.androidAudioTrackOffloadWriteFailed,
  5004: ErrorCode.androidAudioTrackOffloadInitFailed,
  6000: ErrorCode.androidDrmUnspecified,
  6001: ErrorCode.androidDrmSchemeUnsupported,
  6002: ErrorCode.androidDrmProvisioningFailed,
  6003: ErrorCode.androidDrmContentError,
  6004: ErrorCode.androidDrmLicenseAcquisitionFailed,
  6005: ErrorCode.androidDrmDisallowedOperation,
  6006: ErrorCode.androidDrmSystemError,
  6007: ErrorCode.androidDrmDeviceRevoked,
  6008: ErrorCode.androidDrmLicenseExpired,
  7000: ErrorCode.androidVideoFrameProcessorInitFailed,
  7001: ErrorCode.androidVideoFrameProcessingFailed,
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
  methodExecutedWhileNoMethodChannel,
  //Apple Native specific error codes
  appleAudioSessionSetupFailed,
  applePlaylistLoadFailed,
  applePlaybackFailed,
  appleSeekFailed,
  appleNetworkError,
  appleInvalidPlaylist,
  applePlayerItemFailed,
  appleUnknownError,
  // Android Native specific error codes
  androidUnknownError,
  androidInvalidState,
  androidBadValue,
  androidPermissionDenied,
  androidNotSupported,
  androidDisconnected,
  androidAuthenticationExpired,
  androidPremiumAccountRequired,
  androidConcurrentStreamLimit,
  androidParentalControlRestricted,
  androidNotAvailableInRegion,
  androidSkipLimitReached,
  androidSetupRequired,
  androidEndOfPlaylist,
  androidContentAlreadyPlaying,
  androidUnspecified,
  androidRemoteError,
  androidBehindLiveWindow,
  androidTimeout,
  androidFailedRuntimeCheck,
  androidIOUnspecified,
  androidIONetworkConnectionFailed,
  androidIONetworkConnectionTimeout,
  androidIOInvalidHTTPContentType,
  androidIOBadHttpStatus,
  androidIOFileNotFound,
  androidIONoPermission,
  androidIOCleartextNotPermitted,
  androidIOReadPositionOutOfRange,
  androidParsingContainerMalformed,
  androidParsingManifestMalformed,
  androidParsingContainerUnsupported,
  androidParsingManifestUnsupported,
  androidDecoderInitFailed,
  androidDecoderQueryFailed,
  androidDecodingFailed,
  androidDecodingFormatExceedsCapabilities,
  androidDecodingFormatUnsupported,
  androidDecodingResourcesReclaimed,
  androidAudioTrackInitFailed,
  androidAudioTrackWriteFailed,
  androidAudioTrackOffloadWriteFailed,
  androidAudioTrackOffloadInitFailed,
  androidDrmUnspecified,
  androidDrmSchemeUnsupported,
  androidDrmProvisioningFailed,
  androidDrmContentError,
  androidDrmLicenseAcquisitionFailed,
  androidDrmDisallowedOperation,
  androidDrmSystemError,
  androidDrmDeviceRevoked,
  androidDrmLicenseExpired,
  androidVideoFrameProcessorInitFailed,
  androidVideoFrameProcessingFailed;

  static fromIntCode(int code) {
    if (Platform.isIOS) {
      if (_appleNativeErrorMap.containsKey(code)) {
        return _appleNativeErrorMap[code];
      } else {
        return ErrorCode.appleUnknownError;
      }
    } else if (Platform.isAndroid) {
      if (_androidNativeErrorMap.containsKey(code)) {
        return _androidNativeErrorMap[code];
      } else {
        return ErrorCode.androidUnknownError;
      }
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
  String get errorMeaning =>
      switch (code) {
        ErrorCode.unknownError =>
        "Flutter Layer received an unrecognizable error code "
            "which defaulted to unknown error",
        ErrorCode.incorrectPlatformReturnType =>
        "Incorrect platform return type${message.isNotEmpty
            ? ", $message"
            : message}",
        ErrorCode.invalidPlaybackStateIndex =>
        "Invalid playback state index, index received "
            "from native should be in the range 0 ${PlaybackState.values
            .length} as "
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
        ErrorCode
            .methodExecutedWhileNoMethodChannel =>
        "Player method is executed while the main communication channel is null",
        ErrorCode.appleAudioSessionSetupFailed => "Audio session setup failed",
        ErrorCode.applePlaylistLoadFailed => "Playlist load failed",
        ErrorCode.applePlaybackFailed => "Playback failed",
        ErrorCode.appleSeekFailed => "Seek failed",
        ErrorCode.appleNetworkError => "Network error",
        ErrorCode.appleInvalidPlaylist => "Invalid playlist",
        ErrorCode.applePlayerItemFailed => "Player item failed",
        ErrorCode.appleUnknownError => "iOS Platform Unknown error",
        ErrorCode.androidUnknownError => "Android Platform Unknown error",
        ErrorCode
            .androidInvalidState => "Caused by a command that cannot be completed because the current state is not valid",
        ErrorCode.androidBadValue => "Caused by an argument that is illegal",
        ErrorCode
            .androidPermissionDenied => "Caused by a command that is not allowed",
        ErrorCode
            .androidNotSupported => "Caused by a command that is not supported",
        ErrorCode.androidDisconnected => "Caused by a disconnected component",
        ErrorCode
            .androidAuthenticationExpired => "Caused by expired authentication",
        ErrorCode
            .androidPremiumAccountRequired => "Caused by a premium account that is required but the user is not subscribed",
        ErrorCode
            .androidConcurrentStreamLimit => "Caused by too many concurrent streams",
        ErrorCode
            .androidParentalControlRestricted => "Caused by the content being blocked due to parental controls",
        ErrorCode
            .androidNotAvailableInRegion => "Caused by the content being blocked due to being regionally unavailable",
        ErrorCode
            .androidSkipLimitReached => "Caused by the skip limit that is exhausted",
        ErrorCode
            .androidSetupRequired => "Caused by playback that needs manual user intervention",
        ErrorCode
            .androidEndOfPlaylist => "Caused by navigation that failed because the playlist was exhausted",
        ErrorCode
            .androidContentAlreadyPlaying => "Caused by a request for content that was already playing",
        ErrorCode
            .androidUnspecified => "Caused by an error whose cause could not be identified",
        ErrorCode
            .androidRemoteError => "Caused by an unidentified error in a remote Player, which is a Player that runs on a different host or process",
        ErrorCode
            .androidBehindLiveWindow => "Caused by the loading position falling behind the sliding window of available live content",
        ErrorCode.androidTimeout => "Caused by a generic timeout",
        ErrorCode
            .androidFailedRuntimeCheck => "Caused by a failed runtime check",
        ErrorCode
            .androidIOUnspecified => "Caused by an Input/Output error which could not be identified",
        ErrorCode
            .androidIONetworkConnectionFailed => "Caused by a network connection failure",
        ErrorCode
            .androidIONetworkConnectionTimeout => "Caused by a network timeout, meaning the server is taking too long to fulfill a request",
        ErrorCode
            .androidIOInvalidHTTPContentType => "Caused by a server returning a resource with an invalid 'Content-Type' HTTP header value",
        ErrorCode
            .androidIOBadHttpStatus => "Caused by an HTTP server returning an unexpected HTTP response status code",
        ErrorCode.androidIOFileNotFound => "Caused by a non-existent file",
        ErrorCode
            .androidIONoPermission => "Caused by lack of permission to perform an IO operation",
        ErrorCode
            .androidIOCleartextNotPermitted => "Caused by the player trying to access cleartext HTTP traffic",
        ErrorCode
            .androidIOReadPositionOutOfRange => "Caused by reading data out of the data bound",
        ErrorCode
            .androidParsingContainerMalformed => "Caused by a parsing error associated with a media container format bitstream",
        ErrorCode
            .androidParsingManifestMalformed => "Caused by a parsing error associated with a media manifest",
        ErrorCode
            .androidParsingContainerUnsupported => "Caused by attempting to extract a file with an unsupported media container format, or an unsupported media container feature",
        ErrorCode
            .androidParsingManifestUnsupported => "Caused by an unsupported feature in a media manifest",
        ErrorCode
            .androidDecoderInitFailed => "Caused by a decoder initialization failure",
        ErrorCode
            .androidDecoderQueryFailed => "Caused by a decoder query failure",
        ErrorCode
            .androidDecodingFailed => "Caused by a failure while trying to decode media samples",
        ErrorCode
            .androidDecodingFormatExceedsCapabilities => "Caused by trying to decode content whose format exceeds the capabilities of the device",
        ErrorCode
            .androidDecodingFormatUnsupported => "Caused by trying to decode content whose format is not supported",
        ErrorCode
            .androidDecodingResourcesReclaimed => "Caused by higher priority task reclaiming resources needed for decoding",
        ErrorCode
            .androidAudioTrackInitFailed => "Caused by an AudioTrack initialization failure",
        ErrorCode
            .androidAudioTrackWriteFailed => "Caused by an AudioTrack write operation failure",
        ErrorCode
            .androidAudioTrackOffloadWriteFailed => "Caused by an AudioTrack write operation failure in offload mode",
        ErrorCode
            .androidAudioTrackOffloadInitFailed => "Caused by an AudioTrack init operation failure in offload mode",
        ErrorCode
            .androidDrmUnspecified => "Caused by an unspecified error related to DRM protection",
        ErrorCode
            .androidDrmSchemeUnsupported => "Caused by a chosen DRM protection scheme not being supported by the device",
        ErrorCode
            .androidDrmProvisioningFailed => "Caused by a failure while provisioning the device",
        ErrorCode
            .androidDrmContentError => "Caused by attempting to play incompatible DRM-protected content",
        ErrorCode
            .androidDrmLicenseAcquisitionFailed => "Caused by a failure while trying to obtain a license",
        ErrorCode
            .androidDrmDisallowedOperation => "Caused by an operation being disallowed by a license policy",
        ErrorCode
            .androidDrmSystemError => "Caused by an error in the DRM system",
        ErrorCode
            .androidDrmDeviceRevoked => "Caused by the device having revoked DRM privileges",
        ErrorCode
            .androidDrmLicenseExpired => "Caused by an expired DRM license being loaded into an open DRM session",
        ErrorCode
            .androidVideoFrameProcessorInitFailed => "Caused by a failure when initializing a VideoFrameProcessor",
        ErrorCode
            .androidVideoFrameProcessingFailed => "Caused by a failure when processing a video frame",
      };
}
