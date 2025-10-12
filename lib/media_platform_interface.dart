import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'media_method_channel.dart';

abstract class MediaPlatform extends PlatformInterface {
  /// Constructs a MediaPlatform.
  MediaPlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaPlatform _instance = MethodChannelMedia();

  /// The default instance of [MediaPlatform] to use.
  ///
  /// Defaults to [MethodChannelMedia].
  static MediaPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MediaPlatform] when
  /// they register themselves.
  static set instance(MediaPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
