import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media/audio_player.dart';
import 'package:media/media.dart';


void main() {
  runApp(const MyApp());
}

//TODO copy already created AudioPlayer files here, implement ui to test music, update sync script
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _mediaPlugin = Media();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      //platformVersion =
      //    await _mediaPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    // setState(() {
    //   //_platformVersion = platformVersion;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PlayerPage(),
    );
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

  // Sample playlist data
  final List<AudioItem> playlist = [
    AudioItem(
      id: '1',
      uri: Uri.parse('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'),
      artUri: Uri.parse('https://picsum.photos/seed/track1/400/400'),
      title: 'Summer Breeze',
      album: 'Relaxing Moments',
    ),
    AudioItem(
      id: '2',
      uri: Uri.parse('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'),
      artUri: Uri.parse('https://picsum.photos/seed/track2/400/400'),
      title: 'Night Lights',
      album: 'Urban Dreams',
    ),
    AudioItem(
      id: '3',
      uri: Uri.parse('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'),
      artUri: Uri.parse('https://picsum.photos/seed/track3/400/400'),
      title: 'Mountain Echo',
      album: 'Nature Sounds',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _player.init().then((initialized) async {
      final loaded = await _player.loadPlaylist(playlist);
      print("Playlist loaded: $loaded");
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

  @override
  Widget build(BuildContext context) {
    final currentTrack = playlist[currentTrackIndex];

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Music Player', style: TextStyle(color: Colors.white),),
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
                      color: Colors.black.withOpacity(0.5),
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
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

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
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: playPause,
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

