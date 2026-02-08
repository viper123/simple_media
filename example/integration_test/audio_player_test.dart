import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media/audio_player.dart';

import 'test_data.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlayer', () {
    ///
    /// Testing scenarios:
    /// * Load playlist, check that we get active index 0,
    /// item duration, playlist property
    /// * Load playlist, play 10 seconds, pause check we got timer
    /// we got progress updates for 10seconds, check that we got
    /// active index 0, stop check that got progress 0 + active index 0;
    /// * Load playlist, play 3 seconds, next, check active index,
    /// progress, duration, prev, check active index, progress,
    /// duration
    /// * Load playlist, play, seek 10 seconds, check progress,
    /// seek +10 seconds, check progress, seek -10 seconds,
    /// check progress,
    /// * Load playlist, check loading, play, check playback state,
    /// pause, check playback state, play, seek, check seeking,
    /// stop, check playback state is idle
    late AudioPlayer player;
    setUp(() async {
      player = AudioPlayer();
      await player.init();
    });

    tearDown(() {
      player.dispose();
    });

    test('initializes correctly', () async {
      final initialized = player.isInitialized;
      expect(initialized, isTrue);
    });

    ///
    ///Load playlist, check that we get active index 0,
    /// item duration, playlist property
    test('loads playlist', () async {
      expectLater(player.activeIndexStream, emits(0));
      expectLater(
        player.durationStream,
        emits(test3ItemsPlaylistItem0Duration),
      );

      final loaded = await player.loadPlaylist(test3ItemsPlaylist);

      expect(loaded, isTrue);
      expect(player.playlist, test3ItemsPlaylist);
    });

    ///
    /// * Load playlist, play 5 seconds, pause check we got timer
    /// we got progress updates for 4, check that we got
    /// active index 0, stop check that got progress 0;
    ///
    /// This tests sometimes fails, this is due to buffering time
    /// We are expected for the player to play 4 seconds of audio in
    /// a real time of 5 seconds, and sometimes this fails due to longer
    /// buffering time.
    ///
    /// Repeat tests if failed, only if this fails consistently, further
    /// checks are needed.
    test('play, pause, stop emits progress, active index,', () async {
      expectLater(player.activeIndexStream, emits(0));
      final loaded = await player.loadPlaylist(test3ItemsPlaylist);
      expect(loaded, isTrue);

      expectLater(
        streamHasItems(
          player.progressStream.map((duration) => duration.inSeconds),
          [0, 1, 2, 3, 4],
          Duration(seconds: 5),
        ).asStream(),
        emits(true),
      );

      final played = await player.play();
      expect(played, isTrue);
      await Future.delayed(a5s());

      final paused = await player.pause();
      expect(paused, isTrue);
      expectLater(player.progressStream, emits(Duration.zero));

      await player.stop();
    });

    ///
    /// * Load playlist, play 3 seconds, next, check active index,
    /// progress, duration, prev, check active index, progress, duration
    test('next, prev', () async {
      final indexes = [];
      player.activeIndexStream.listen((index) {
        indexes.add(index);
      });

      final loaded = await player.loadPlaylist(test3ItemsPlaylist);
      expect(loaded, isTrue);

      int iterations = 0;
      Map<int, Set> progresses = {};
      player.progressStream.listen((duration) {
        if (progresses[iterations] == null) {
          progresses[iterations] = {};
        }
        progresses[iterations]?.add(duration.inSeconds);
      });

      Set durations = {};
      player.durationStream.listen((duration) {
        if (duration != null) {
          durations.add(duration.inSeconds);
        }
      });

      final played = await player.play();
      expect(played, isTrue);

      await Future.delayed(a3s());
      final next = await player.next();
      iterations = iterations + 1;
      expect(next, isTrue);
      await Future.delayed(a3s());
      final prev = await player.previous();
      iterations = iterations + 1;
      expect(prev, isTrue);
      await Future.delayed(a3s());

      expect(indexes, [0, 1, 0]);
      expect(durations, [372, 425]);
      expect(progresses, {
        0: {0, 1, 2},
        1: {0, 1, 2},
        2: {0, 1, 2},
      });
    });

    /// * Load playlist, play, seek 10 seconds, check progress,
    /// seek +10 seconds, check progress, seek -10 seconds,
    /// check progress,
    test('scrub', () async {
      final loaded = await player.loadPlaylist(test3ItemsPlaylist);
      expect(loaded, isTrue);

      List<int> progresses = [];
      player.progressStream.listen((progress) {
        progresses.add(progress.inSeconds);
      });

      final played = await player.play();
      expect(played, isTrue);
      await Future.delayed(Duration(seconds: 1));

      await player.seekTo(Duration(seconds: 10));
      await Future.delayed(Duration(seconds: 1));

      await player.seekTo(Duration(seconds: 20));
      await Future.delayed(Duration(seconds: 1));

      await player.seekTo(Duration(seconds: 10));
      await Future.delayed(Duration(seconds: 1));

      expect(progresses.contains(0), isTrue);
      expect(progresses.contains(10), isTrue);
      expect(progresses.contains(20), isTrue);
      expect(progresses.last, 10);
    });

    /// * Load playlist, check loading, play, check playback state,
    /// pause, check playback state, play, seek, check seeking,
    /// stop, check playback state is idle
    test('playback state', () async {
      List<PlaybackState> states = [];
      player.playbackStream.listen((state) {
        states.add(state);
      });

      final loaded = await player.loadPlaylist(test3ItemsPlaylist);
      expect(loaded, isTrue);

      await player.play();
      await Future.delayed(a1s());

      await player.seekTo(a3s());
      await Future.delayed(a5s());

      await player.pause();
      await Future.delayed(a1s());

      await player.stop();
      await Future.delayed(a1s());

      if (Platform.isIOS) {
        expect(states, [
          PlaybackState.loading,
          PlaybackState.idle,
          PlaybackState.playing,
          PlaybackState.seeking,
          PlaybackState.playing,
          PlaybackState.paused,
          PlaybackState.idle,
        ]);
      } else if (Platform.isAndroid) {
        expect(states, [
          PlaybackState.loading,
          PlaybackState.playing,
          PlaybackState.seeking,
          PlaybackState.loading,
          PlaybackState.playing,
          PlaybackState.paused,
          PlaybackState.idle
        ]);
      }
    });
  });
}
