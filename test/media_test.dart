import 'package:flutter_test/flutter_test.dart';
import 'package:media/media.dart';
import 'package:media/media_platform_interface.dart';
import 'package:media/media_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaPlatform
    with MockPlatformInterfaceMixin
    implements MediaPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MediaPlatform initialPlatform = MediaPlatform.instance;

  test('$MethodChannelMedia is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMedia>());
  });

  test('getPlatformVersion', () async {
    Media mediaPlugin = Media();
    MockMediaPlatform fakePlatform = MockMediaPlatform();
    MediaPlatform.instance = fakePlatform;

    expect(await mediaPlugin.getPlatformVersion(), '42');
  });
}
