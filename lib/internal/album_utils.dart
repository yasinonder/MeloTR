import 'dart:io';
import 'package:melotube/internal/artwork_manager.dart';
import 'package:melotube/internal/models/song_item.dart';

class AlbumUtils {

  // Album Artwork Getter, if it aint available, it will be
  static Future<File> getAlbumImageFromSong(SongItem song) async {
    if (await artworkFile(song.id).exists()) {
      return artworkFile(song.id);
    } else {
      await ArtworkManager.writeArtwork(song.id);
      return artworkFile(song.id);
    }
  }

}