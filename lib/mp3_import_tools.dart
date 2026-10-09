import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'mp3_import_service.dart';
import 'music_library.dart';

class Mp3ImportTools extends StatefulWidget {
  const Mp3ImportTools({super.key, required this.library});
  final MusicLibrary library;

  @override
  State<Mp3ImportTools> createState() => _Mp3ImportToolsState();
}

class _Mp3ImportToolsState extends State<Mp3ImportTools> {
  final urlController = TextEditingController();
  final service = Mp3ImportService();
  int kbps = 192;
  bool working = false;
  double? progress;
  String status = '';
  String? error;

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  Future<void> runImport(Future<String> Function() work) async {
    if (working) return;
    setState(() {
      working = true;
      progress = null;
      status = 'Hazırlanıyor…';
      error = null;
    });
    try {
      final fileName = await work();
      if (!mounted) return;
      setState(() => status = 'MP3 kaydedildi: ' + fileName);
      await widget.library.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('MP3 kaydedildi. Müzik kütüphanesi yenilendi.'),
      ));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> selectLocal() async {
    if (working) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: Mp3ImportService.acceptedExtensions,
      allowMultiple: false, withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) {
      if (mounted) setState(() => error = 'Dosya yolu alınamadı.');
      return;
    }
    await runImport(() => service.fromLocalVideo(
      path: file.path!,
      displayName: file.name,
      kbps: kbps,
      onStatus: (message) {
        if (mounted) setState(() => status = message);
      },
    ));
  }

  Future<void> importUrl() async {
    if (working) return;
    await runImport(() => service.fromDirectUrl(
      url: urlController.text.trim(),
      kbps: kbps,
      onStatus: (message) {
        if (mounted) setState(() => status = message);
      },
      onProgress: (value) {
        if (mounted) setState(() => progress = value);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151B2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF394058)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.graphic_eq_rounded, color: Color(0xFFF1377E)),
          SizedBox(width: 10),
          Text('Video → MP3', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 9),
        const Text('İzinli video dosyasını MP3 yapıp Müzik/MeloTR '
            'klasörüne kaydet. Başarılı kayıttan sonra geçici video '
            'silinir; telefonundaki orijinal video silinmez.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9AA3BB))),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: kbps, isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'MP3 kalitesi', border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [128, 192, 256, 320].map((n) => DropdownMenuItem(
            value: n, child: Text('$n kbps'),
          )).toList(),
          onChanged: working ? null : (value) {
            if (value != null) setState(() => kbps = value);
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: working ? null : () => unawaited(selectLocal()),
          icon: const Icon(Icons.video_file_outlined),
          label: const Text('Telefondan video seç, MP3’e çevir'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: urlController, enabled: !working,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'İzinli doğrudan HTTPS dosya bağlantısı',
            hintText: 'https://ornek.com/video.mp4',
            border: OutlineInputBorder(), isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: working ? null : () => unawaited(importUrl()),
          icon: const Icon(Icons.download_rounded),
          label: const Text('İndir, MP3’e çevir, kütüphaneye ekle'),
        ),
        const SizedBox(height: 8),
        const Text('YouTube izleme sayfası bağlantısı buradan indirilemez.',
            style: TextStyle(fontSize: 11, color: Color(0xFF9AA3BB))),
        if (working || status.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (working) LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(status, style: const TextStyle(fontSize: 12)),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(
            fontSize: 12, color: Color(0xFFFF8585))),
        ],
      ]),
    );
  }
}
