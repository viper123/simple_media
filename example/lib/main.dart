import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:media/audio_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: PlayerPage());
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  // Player state
  bool isPlaying = false;
  int currentTrackIndex = 0;
  final AudioPlayer _player = AudioPlayer();

  // Progress state
  double currentPosition = 0.0; // in seconds
  double totalDuration = 0.0; // in seconds (3 minutes for demo)
  bool isScrubbing = false;

  // Sample playlist data
  final List<AudioItem> playlist = [
    AudioItem(
      id: '1',
      uri: Uri.parse(
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      ),
      artUri: Uri.parse('https://picsum.photos/seed/track1/400/400'),
      title: 'Summer Breeze',
      album: 'Relaxing Moments',
    ),
    AudioItem(
      id: '2',
      uri: Uri.parse(
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      ),
      artUri: Uri.parse('https://picsum.photos/seed/track2/400/400'),
      title: 'Night Lights',
      album: 'Urban Dreams',
    ),
    AudioItem(
      id: '3',
      uri: Uri.parse(
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      ),
      artUri: Uri.parse('https://picsum.photos/seed/track3/400/400'),
      title: 'Mountain Echo',
      album: 'Nature Sounds',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _player.init(enableNativeLogs: true).then((initialized) async {
      _player.durationStream.distinct().listen((duration) {
        print("flutter: Received duration: $duration");
        setState(() {
          totalDuration = duration?.inSeconds.toDouble() ?? 0.0;
        });
      });

      _player.progressStream.distinct().listen((duration) {
        setState(() {
          log("Current progress: $duration");
          currentPosition = duration.inSeconds.toDouble();
        });
      });

      _player.activeIndexStream.distinct().listen((index) {
        setState(() {
          if (index != invalidActiveIndex) {
            log("Active index changed: $index");
            currentTrackIndex = index;
          }
        });
      });

      _player.playbackStream.distinct().listen((state) {

        bool newPlayState;
        switch (state) {

          case PlaybackState.idle:
            newPlayState = false;
          case PlaybackState.playing:
            newPlayState = true;
          case PlaybackState.paused:
            newPlayState = false;
          case PlaybackState.loading:
            newPlayState = false;
          case PlaybackState.seeking:
            newPlayState = false;
          case PlaybackState.error:
            newPlayState = false;
        }

        setState(() {
          isPlaying = newPlayState;
        });
      });

      final loaded = await _player.loadPlaylist(playlist);
      log("Playlist loaded: $loaded");
    });
  }

  void playPause() {
    setState(() {
      if (isPlaying) {
        _player.pause();
      } else {
        _player.play();
      }
      isPlaying = !isPlaying;
    });
  }

  void stop() {
    setState(() {
      _player.stop();
      isPlaying = false;
    });
  }

  void nextTrack() {
    setState(() {
      if (currentTrackIndex < playlist.length - 1) {
        currentTrackIndex++;
      } else {
        currentTrackIndex = 0;
      }
      _player.seekTo(Duration.zero, index: currentTrackIndex);
    });
  }

  void previousTrack() {
    setState(() {
      if (currentTrackIndex > 0) {
        currentTrackIndex--;
      } else {
        currentTrackIndex = playlist.length - 1;
      }
      _player.seekTo(Duration.zero, index: currentTrackIndex);
    });
  }

  void onSeekStart(double value) {
    setState(() {
      isScrubbing = true;
    });
  }

  void onSeekEnd(double value) {
    setState(() {
      isScrubbing = false;
      currentPosition = value;

      _player.seekTo(Duration(seconds: value.toInt()));
    });
  }

  String formatDuration(double seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = (seconds % 60).toInt();
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = playlist[currentTrackIndex];

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Music Player'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Album Art
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(128),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    currentTrack.artUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.music_note,
                          size: 100,
                          color: Colors.white54,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Track Title
              Text(
                currentTrack.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Album Name
              Text(
                currentTrack.album,
                style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Progress Slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8.0,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16.0,
                        ),
                        activeTrackColor: Colors.blue,
                        inactiveTrackColor: Colors.grey[800],
                        thumbColor: Colors.blue,
                        overlayColor: Colors.blue.withAlpha(51),
                      ),
                      child: Slider(
                        value: currentPosition.clamp(0.0, totalDuration),
                        min: 0.0,
                        max: totalDuration,
                        onChanged: (s) {
                          /*ignored*/
                        },
                        onChangeStart: onSeekStart,
                        onChangeEnd: onSeekEnd,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(currentPosition),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          Text(
                            formatDuration(totalDuration),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Previous Button
                  IconButton(
                    onPressed: previousTrack,
                    icon: const Icon(Icons.skip_previous),
                    iconSize: 48,
                    color: Colors.white,
                  ),

                  // Stop Button
                  IconButton(
                    onPressed: stop,
                    icon: const Icon(Icons.stop),
                    iconSize: 48,
                    color: Colors.white,
                  ),

                  // Play/Pause Button
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withAlpha(102),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: playPause,
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      iconSize: 56,
                      color: Colors.white,
                    ),
                  ),

                  // Next Button
                  IconButton(
                    onPressed: nextTrack,
                    icon: const Icon(Icons.skip_next),
                    iconSize: 48,
                    color: Colors.white,
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Track Counter
              Text(
                'Track ${currentTrackIndex + 1} of ${playlist.length}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
