
import 'package:simple_media/audio_player.dart';

final List<AudioItem> test3ItemsPlaylist = [
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

//0:06:12.715000
final test3ItemsPlaylistItem0Duration = Duration(minutes: 6, seconds: 12, microseconds: 715000);