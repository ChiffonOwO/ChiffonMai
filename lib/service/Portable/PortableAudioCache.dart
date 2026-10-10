import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../entity/Portable/PortableSong.dart';
import '../../utils/ApiClient.dart';

typedef PortableAudioProgress = void Function(
    double? progress, double bytesPerSecond, String status);

/// 随身听音源的永久本地缓存。
///
/// 缓存放在应用文档目录，应用更新和普通缓存清理不会删除。每首歌第一次播放
/// 时才下载，后续播放直接使用本地文件，避免反复请求落雪或 AWMC 音源。
class PortableAudioCache {
  PortableAudioCache._();
  static final instance = PortableAudioCache._();

  final Map<int, Future<File>> _inFlight = <int, Future<File>>{};

  Future<File?> existing(PortableSong song) async {
    final file = await _fileFor(song);
    try {
      if (await file.exists() && await file.length() >= 1024) return file;
    } catch (_) {}
    return null;
  }

  Future<File> ensure(
    PortableSong song, {
    PortableAudioProgress? onProgress,
  }) async {
    final cached = await existing(song);
    if (cached != null) {
      onProgress?.call(1, 0, '已从本地缓存读取音频');
      return cached;
    }
    final running = _inFlight[song.audioId];
    if (running != null) return running;
    final task = _download(song, onProgress);
    _inFlight[song.audioId] = task;
    try {
      return await task;
    } finally {
      _inFlight.remove(song.audioId);
    }
  }

  Future<File> _download(
      PortableSong song, PortableAudioProgress? onProgress) async {
    Object? lastError;
    for (final url in song.audioUrls) {
      File? temporary;
      try {
        onProgress?.call(null, 0, '正在下载音频文件…');
        final response = await ApiClient.getStream(Uri.parse(url));
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }
        final contentType = response.headers['content-type']?.toLowerCase();
        if (contentType != null &&
            (contentType.contains('text/html') ||
                contentType.contains('application/json'))) {
          await response.stream.drain<void>();
          lastError = '响应不是音频文件';
          continue;
        }

        final target = await _fileFor(song);
        temporary = File('${target.path}.part');
        if (await temporary.exists()) await temporary.delete();
        final sink = temporary.openWrite();
        final compressed = response.headers['content-encoding'];
        final total = compressed == null || compressed == 'identity'
            ? response.contentLength
            : null;
        var received = 0;
        final prefix = <int>[];
        var validated = false;
        final stopwatch = Stopwatch()..start();
        try {
          await for (final chunk
              in response.stream.timeout(const Duration(seconds: 30))) {
            received += chunk.length;
            if (!validated) {
              prefix.addAll(chunk);
              if (prefix.length >= 3) {
                final isId3 = prefix[0] == 0x49 &&
                    prefix[1] == 0x44 &&
                    prefix[2] == 0x33;
                final isFrame = prefix[0] == 0xff &&
                    (prefix[1] & 0xe0) == 0xe0;
                if (!isId3 && !isFrame) {
                  throw const FormatException('音源响应不是有效的 MP3');
                }
                validated = true;
                sink.add(prefix);
              }
            } else {
              sink.add(chunk);
            }
            final elapsed = stopwatch.elapsedMicroseconds / 1000000;
            onProgress?.call(
              total != null && total > 0
                  ? (received / total).clamp(0.0, 1.0)
                  : null,
              elapsed > 0 ? received / elapsed : 0,
              '正在下载音频文件…',
            );
          }
          await sink.close();
        } catch (_) {
          await sink.close();
          rethrow;
        }
        if (!validated || received < 1024) {
          throw const FormatException('音源文件不完整');
        }
        if (await target.exists()) await target.delete();
        final saved = await temporary.rename(target.path);
        onProgress?.call(1, 0, '音频文件已缓存');
        return saved;
      } catch (e) {
        lastError = e;
        try {
          if (temporary != null && await temporary.exists()) {
            await temporary.delete();
          }
        } catch (_) {}
      }
    }
    throw Exception('音源下载失败：$lastError');
  }

  Future<File> _fileFor(PortableSong song) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDirectory = Directory('${directory.path}/portable_audio_cache');
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    return File('${cacheDirectory.path}/audio_${song.audioId}.mp3');
  }
}
