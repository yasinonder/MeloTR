import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'music_library.dart';
import 'youtube_music_service.dart';

class YoutubeMusicSearch extends StatefulWidget {
  const YoutubeMusicSearch({super.key, required this.library});
  final MusicLibrary library;
  @override
  State<YoutubeMusicSearch> createState() => _YoutubeMusicSearchState();
}

class _YoutubeMusicSearchState extends State<YoutubeMusicSearch> {
  final field = TextEditingController();
  final service = YoutubeMusicService();
  List<Video> results = <Video>[];
  bool searching = false;
  bool downloading = false;
  String? selectedVideo;
  String? error;
  String status = '';
  double? progress;
  int kbps = 192;
  Video? lastAttempt;
  DateTime lastProgressUi = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    field.dispose();
    service.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (searching || downloading || field.text.trim().isEmpty) return;
    setState(() { searching = true; error = null; results = <Video>[]; });
    try {
      final found = await service.search(field.text.trim());
      if (mounted) setState(() => results = found);
    } catch (e) {
      if (mounted) setState(() => error = 'YouTube arama hatası: $e');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> selectVideo(Video video) async {
    if (searching || downloading) return;
    setState(() {
      lastAttempt = video;
      selectedVideo = video.id.value;
      downloading = true;
      error = null;
      status = 'İndirme başlıyor…';
      progress = null;
    });
    try {
      final filename = await service.saveMp3(video,
        kbps: kbps,
        onStatus: (message) {
          if (mounted) setState(() => status = message);
        },
        onProgress: (value) {
          if (!mounted) return;
          final now = DateTime.now();
          if (value >= 1.0 ||
              now.difference(lastProgressUi).inMilliseconds >= 350) {
            lastProgressUi = now;
            setState(() => progress = value);
          }
        },
      );
      // The MP3 has already been persisted to MediaStore at this point.
      // A slow media permission query must not leave the download UI spinning.
      var refreshed = true;
      try {
        await widget.library.refresh().timeout(const Duration(seconds:20));
      } on TimeoutException {
        refreshed = false;
      }
      if (mounted) {
        setState(() => status = refreshed
            ? filename + ' kütüphaneye eklendi.'
            : filename + ' kaydedildi. Kütüphaneyi yeniden tarayın.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status)));
      }
    } catch (e) {
      if (mounted) setState(() {
        error = e is TimeoutException
            ? 'İndirme yanıt vermedi: ${e.message ?? e.toString()}'
            : 'MP3 indirme/dönüştürme hatası: $e';
        status = 'İşlem durduruldu; başka bir video deneyin.';
        progress = null;
      });
    } finally {
      if (mounted) setState(() {
        selectedVideo = null;
        downloading = false;
      });
    }
  }

  String duration(Duration? value) {
    if (value == null) return '';
    return value.inMinutes.toString() + ':' +
        value.inSeconds.remainder(60).toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 8),
      child: TextField(
        controller: field,
        onSubmitted: (_) => unawaited(search()),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: 'YouTube’da şarkı veya video ara',
          hintText: 'Şarkı adı, sanatçı ya da YouTube bağlantısı',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: 'Ara',
            onPressed: searching || downloading ? null : () => unawaited(search()),
            icon: const Icon(Icons.arrow_forward_rounded)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 19),
      child: Row(children: [
        const Icon(Icons.music_note, size: 18),
        const SizedBox(width: 8),
        const Text('MP3 kalitesi'),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: kbps,
          items: [128, 192, 256, 320].map((rate) =>
              DropdownMenuItem(value: rate, child: Text(rate.toString() + ' kbps'))).toList(),
          onChanged: downloading ? null : (value) {
            if (value != null) setState(() => kbps = value);
          }),
        const Spacer(),
        if (results.isNotEmpty)
          Text(results.length.toString() + ' sonuç',
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
    ),
    const Padding(
      padding: EdgeInsets.fromLTRB(19, 0, 19, 10),
      child: Text('Kapak resmine dokun → MP3 → MeloTR kütüphanesi. '
          'Yalnızca indirme hakkın olan içerikleri seç. '
          'YouTube bu yöntemi engelleyebilir.',
          style: TextStyle(fontSize: 11, color: Colors.white60)),
    ),
    if (downloading || status.isNotEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(19, 0, 19, 8),
        child: Column(children: [
          if (downloading) LinearProgressIndicator(value: progress),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: Text(status, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12))),
            if (downloading && progress != null)
              Text('${(progress! * 100).round()}%',
                  style: const TextStyle(fontSize: 12)),
          ]),
        ]),
      ),
    if (error != null)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(error!, style: const TextStyle(
              fontSize: 12, color: Colors.redAccent)),
          if (lastAttempt != null && !downloading)
            TextButton.icon(
              onPressed: () => unawaited(selectVideo(lastAttempt!)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
        ]),
      ),
    if (searching)
      const Padding(padding: EdgeInsets.only(top: 25),
          child: CircularProgressIndicator()),
    Expanded(
      child: results.isEmpty
          ? Center(child: Text(
              searching ? 'Videolar aranıyor…' :
                'Ara, ilgili videolar burada resimleriyle görünsün.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60)))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 30),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final video = results[index];
                final busy = selectedVideo == video.id.value;
                return InkWell(
                  onTap: downloading ? null : () => unawaited(selectVideo(video)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(video.thumbnails.mediumResUrl,
                          width: 124, height: 72, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 124, height: 72,
                            alignment: Alignment.center,
                            color: const Color(0xFF24293B),
                            child: const Icon(Icons.music_video))),
                      ),
                      const SizedBox(width: 11),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(video.title, maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 5),
                          Text(video.author,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                          Text(duration(video.duration),
                            style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                        ],
                      )),
                      const SizedBox(width: 5),
                      if (busy)
                        const SizedBox(width: 25, height: 25,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        const Icon(Icons.download_for_offline_rounded,
                            color: Color(0xFFF1377E)),
                    ]),
                  ),
                );
              },
            ),
    ),
  ]);
}
