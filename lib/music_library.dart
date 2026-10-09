import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

String readableArtist(String? value) {
  if (value == null || value.trim().isEmpty || value == '<unknown>') {
    return 'Bilinmeyen sanatçı';
  }
  return value;
}

String readableAlbum(String? value) {
  if (value == null || value.trim().isEmpty || value == '<unknown>') {
    return 'Bilinmeyen albüm';
  }
  return value;
}

String fmtDuration(Duration? value) {
  final total = value?.inSeconds ?? 0;
  final minutes = (total ~/ 60).toString();
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class MusicLibrary extends ChangeNotifier {
  MusicLibrary();

  final OnAudioQuery query = OnAudioQuery();
  final AudioPlayer player = AudioPlayer();
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  final List<StreamSubscription<dynamic>> _subs = [];

  List<SongModel> songs = [];
  List<SongModel> queue = [];
  Set<int> favorites = {};
  List<int> recentIds = [];
  Map<String, List<int>> playlists = {};
  bool initialized = false;
  bool permissionGranted = false;
  bool loading = false;
  bool introSeen = false;
  String? error;
  int accentIndex = 0;
  int? _lastRecordedId;

  SongModel? get currentSong {
    final index = player.currentIndex;
    if (index == null || index < 0 || index >= queue.length) return null;
    return queue[index];
  }

  List<SongModel> get favoriteSongs =>
      songs.where((s) => favorites.contains(s.id)).toList();

  List<SongModel> get recentSongs {
    final byId = {for (final song in songs) song.id: song};
    return recentIds.map((id) => byId[id]).whereType<SongModel>().toList();
  }

  List<SongModel> tracksInPlaylist(String name) {
    final ids = playlists[name] ?? [];
    final byId = {for (final song in songs) song.id: song};
    return ids.map((id) => byId[id]).whereType<SongModel>().toList();
  }

  Future<void> init() async {
    try {
      introSeen = (await _prefs.getBool('intro_seen')) ?? false;
      accentIndex = (await _prefs.getInt('accent')) ?? 0;
      favorites = ((await _prefs.getStringList('favorites')) ?? [])
          .map(int.tryParse).whereType<int>().toSet();
      recentIds = ((await _prefs.getStringList('recent')) ?? [])
          .map(int.tryParse).whereType<int>().toList();
      final saved = await _prefs.getString('playlists');
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is Map) {
          playlists = decoded.map<String, List<int>>((key, value) =>
              MapEntry(key.toString(), (value as List)
                  .map((id) => int.tryParse(id.toString()))
                  .whereType<int>().toList()));
        }
      }
      _subs.add(player.currentIndexStream.listen((_) {
        final song = currentSong;
        if (song != null && song.id != _lastRecordedId) {
          _lastRecordedId = song.id;
          unawaited(_recordRecent(song.id));
        }
        notifyListeners();
      }));
      _subs.add(player.playingStream.listen((_) => notifyListeners()));
      _subs.add(player.loopModeStream.listen((_) => notifyListeners()));
      _subs.add(player.shuffleModeEnabledStream.listen((_) => notifyListeners()));
      _subs.add(player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          notifyListeners();
        }
      }));
      if (introSeen) await refresh();
    } catch (e) {
      error = 'Müzik kütüphanesi açılamadı: $e';
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      permissionGranted = await query.checkAndRequest();
      if (permissionGranted) {
        final found = await query.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
        );
        songs = found.where((s) => s.isMusic != false).toList();
      } else {
        songs = [];
      }
    } catch (e) {
      error = 'Müzikler taranırken hata oluştu: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> completeIntro() async {
    introSeen = true;
    notifyListeners();
    await _prefs.setBool('intro_seen', true);
    await refresh();
  }

  Future<void> playSongs(List<SongModel> selected, int start) async {
    if (selected.isEmpty || start < 0 || start >= selected.length) return;
    final valid = selected.where((s) =>
        (s.uri != null && s.uri!.isNotEmpty) || s.data.isNotEmpty).toList();
    if (valid.isEmpty) {
      error = 'Oynatılabilir müzik dosyası bulunamadı.';
      notifyListeners();
      return;
    }
    final chosenId = selected[start].id;
    final startIndex = valid.indexWhere((s) => s.id == chosenId);
    if (startIndex == -1) return;
    try {
      queue = valid;
      _lastRecordedId = null;
      notifyListeners();
      final sources = valid.map((song) {
        final mediaUri = (song.uri != null && song.uri!.isNotEmpty)
            ? Uri.parse(song.uri!)
            : Uri.file(song.data);
        return AudioSource.uri(mediaUri, tag: MediaItem(
          id: song.id.toString(),
          title: song.title,
          artist: readableArtist(song.artist),
          album: readableAlbum(song.album),
          duration: song.duration == null
              ? null : Duration(milliseconds: song.duration!),
        ));
      }).toList();
      await player.setAudioSources(sources, initialIndex: startIndex);
      unawaited(player.play());
    } catch (e) {
      error = 'Şarkı açılamadı: $e';
      notifyListeners();
    }
  }

  Future<void> playOrPause() async {
    if (player.playing) {
      await player.pause();
    } else if (currentSong != null) {
      unawaited(player.play());
    } else if (songs.isNotEmpty) {
      await playSongs(songs, 0);
    }
  }

  Future<void> next() async {
    if (player.hasNext) await player.seekToNext();
  }

  Future<void> previous() async {
    if (player.position.inSeconds > 4) {
      await player.seek(Duration.zero);
    } else if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      await player.seek(Duration.zero);
    }
  }

  Future<void> toggleShuffle() async {
    final enable = !player.shuffleModeEnabled;
    if (enable) await player.shuffle();
    await player.setShuffleModeEnabled(enable);
  }

  Future<void> cycleRepeat() async {
    final next = switch (player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await player.setLoopMode(next);
  }

  Future<void> toggleFavorite(int id) async {
    if (!favorites.add(id)) favorites.remove(id);
    notifyListeners();
    await _prefs.setStringList('favorites', favorites.map((e) => '$e').toList());
  }

  Future<void> _recordRecent(int id) async {
    recentIds.remove(id);
    recentIds.insert(0, id);
    if (recentIds.length > 40) recentIds.removeRange(40, recentIds.length);
    notifyListeners();
    await _prefs.setStringList('recent', recentIds.map((e) => '$e').toList());
  }

  Future<void> savePlaylist(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || playlists.containsKey(clean)) return;
    playlists[clean] = [];
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String name) async {
    playlists.remove(name);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> toggleInPlaylist(String name, int id) async {
    final entries = playlists[name];
    if (entries == null) return;
    if (!entries.contains(id)) {
      entries.add(id);
    } else {
      entries.remove(id);
    }
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> _savePlaylists() => _prefs.setString('playlists', jsonEncode(playlists));

  Future<void> changeAccent(int index) async {
    accentIndex = index;
    notifyListeners();
    await _prefs.setInt('accent', index);
  }

  @override
  void dispose() {
    for (final sub in _subs) { sub.cancel(); }
    player.dispose();
    super.dispose();
  }
}
