
import 'media_platform_interface.dart';

class Media {
  Future<String?> getPlatformVersion() {
    return MediaPlatform.instance.getPlatformVersion();
  }
}
