import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_platform_interface.dart';

/// An implementation of [MediaPlatform] that uses method channels.
class MethodChannelMedia extends MediaPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('media');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
