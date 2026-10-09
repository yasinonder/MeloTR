import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Converts authorized local or directly downloadable media to an MP3.
/// Never deletes user originals, and only deletes its temporary input after
/// Android confirms the new MP3 has been written to its MediaStore.
class Mp3ImportService {
  static const acceptedExtensions = [
    'mp4', 'm4v', 'mov', 'webm', 'mkv', 'mp3', 'm4a', 'aac', 'wav', 'ogg'
  ];

  Future<String> fromLocalVideo({
    required String path,
    required String displayName,
    required int kbps,
    required void Function(String) onStatus,
  }) async {
    final source = File(path);
    if (!await source.exists() || await source.length() == 0) {
      throw const FormatException('Seçilen dosyaya erişilemedi.');
    }
    final ext = _extension(displayName);
    if (!acceptedExtensions.contains(ext)) {
      throw const FormatException('Bu dosya türü desteklenmiyor.');
    }
    final folder = await _jobFolder();
    // File picker supplies either a user path or a cached copy. Preserve it.
    final tempInput = await source.copy(folder.path + '/source.' + ext);
    return _convert(
      input: tempInput, folder: folder,
      title: _title(displayName), kbps: kbps, onStatus: onStatus,
    );
  }

  Future<String> fromDirectUrl({
    required String url,
    required int kbps,
    required void Function(String) onStatus,
    required void Function(double) onProgress,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.host.toLowerCase() == 'localhost' ||
        InternetAddress.tryParse(uri.host) != null) {
      throw const FormatException('Doğrudan HTTPS dosya bağlantısı gerekli.');
    }
    final host = uri.host.toLowerCase();
    if (host == 'youtube.com' || host.endsWith('.youtube.com') ||
        host == 'youtu.be' || host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com')) {
      throw const FormatException(
        'YouTube izleme adresleri doğrudan video dosyası değildir.');
    }
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final ext = _extension(name);
    if (!acceptedExtensions.contains(ext)) {
      throw const FormatException(
        'Bağlantı doğrudan .mp4, .webm, .m4a vb. dosyaya ait olmalı.');
    }
    final folder = await _jobFolder();
    final tempInput = File(folder.path + '/source.' + ext);
    onStatus('Video dosyası indiriliyor…');
    final response = await Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(minutes: 8),
    )).downloadUri(
      uri, tempInput.path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
      },
    );
    final mime = response.headers.value(Headers.contentTypeHeader)
        ?.toLowerCase() ?? '';
    if (mime.contains('text/html') || mime.contains('application/json') ||
        !await tempInput.exists() || await tempInput.length() < 1024) {
      throw const FormatException('Bağlantıdan video veya ses dosyası gelmedi.');
    }
    onProgress(1.0);
    return _convert(
      input: tempInput, folder: folder,
      title: _title(name), kbps: kbps, onStatus: onStatus,
    );
  }

  Future<String> _convert({
    required File input,
    required Directory folder,
    required String title,
    required int kbps,
    required void Function(String) onStatus,
  }) async {
    if (![128, 192, 256, 320].contains(kbps)) {
      throw const FormatException('Geçersiz MP3 kalitesi.');
    }
    final name = _safeName(title) + '-' +
        DateTime.now().millisecondsSinceEpoch.toString() + '.mp3';
    final output = File(folder.path + '/' + name);
    onStatus('FFmpeg ile MP3 dönüştürülüyor…');
    final session = await FFmpegKit.executeWithArguments([
      '-hide_banner', '-nostdin', '-y',
      '-i', input.path, '-vn', '-map', '0:a:0',
      '-codec:a', 'libmp3lame', '-b:a', kbps.toString() + 'k',
      '-id3v2_version', '3', output.path,
    ]);
    if (!ReturnCode.isSuccess(await session.getReturnCode()) ||
        !await output.exists() || await output.length() < 1024) {
      throw const FormatException(
        'MP3 dönüştürülemedi; geçici video korunuyor.');
    }
    onStatus('Müzik/MeloTR klasörüne kaydediliyor…');
    final store = MediaStore();
    final saved = await store.saveFile(
      tempFilePath: output.path,
      dirType: DirType.audio,
      dirName: DirName.music,
    );
    if (saved == null ||
        !await store.isFileUriExist(uriString: saved.uri.toString())) {
      throw const FileSystemException(
        'MP3 kaydı doğrulanamadı; geçici video korunuyor.');
    }
    // Only our app-owned temporary copy is removed after a confirmed save.
    onStatus('Kayıt tamam. Geçici video siliniyor…');
    await input.delete();
    try {
      await folder.delete(recursive: true);
    } catch (_) {
      // Clean-up must not invalidate a saved MP3.
    }
    onStatus('Tamamlandı: ' + saved.name);
    return saved.name;
  }

  Future<Directory> _jobFolder() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(root.path + '/melotr_jobs/' +
        DateTime.now().microsecondsSinceEpoch.toString());
    await directory.create(recursive: true);
    return directory;
  }

  static String _extension(String value) {
    final clean = value.toLowerCase().split('?').first;
    final dot = clean.lastIndexOf('.');
    return dot < 0 ? '' : clean.substring(dot + 1);
  }

  static String _title(String value) {
    final clean = Uri.decodeComponent(value.split('?').first);
    final dot = clean.lastIndexOf('.');
    return dot > 0 ? clean.substring(0, dot) : clean;
  }

  static String _safeName(String value) {
    final name = value.replaceAll(
      RegExp(r'[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ _-]'), '_',
    ).trim();
    if (name.isEmpty) return 'MeloTR';
    return name.length > 65 ? name.substring(0, 65) : name;
  }
}
