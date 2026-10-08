import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../entity/Portable/PortableSong.dart';
import '../../utils/ApiClient.dart';
import '../../utils/ExportPathUtil.dart';

typedef AudioFileWriter = Future<File> Function(
    String fileName, Stream<List<int>> stream, void Function(String)? onFallback);

/// 点击下载时才请求音源；同一首歌的并发点击共用一次下载。
class PortableSongDownloadService {
  static final instance = PortableSongDownloadService();
  final Future<http.StreamedResponse> Function(Uri) _fetch;
  final AudioFileWriter _write;
  final Map<int, Future<File>> _inFlight = {};

  PortableSongDownloadService({
    Future<http.StreamedResponse> Function(Uri)? fetch,
    AudioFileWriter? write,
  }) : _fetch = fetch ?? ((uri) => ApiClient.getStream(uri)),
       _write = write ?? _writePublicFile;

  static Future<File> _writePublicFile(
      String fileName, Stream<List<int>> stream, void Function(String)? onFallback) {
    return ExportPathUtil.writeExportStream(
      fileName: fileName,
      stream: stream,
      subDir: '歌曲',
      onFallback: onFallback,
    );
  }

  Future<File> download(PortableSong song,
      {void Function(double? progress)? onProgress,
      void Function(String fallbackPath)? onFallback}) async {
    final existing = _inFlight[song.audioId];
    if (existing != null) return existing;
    final task = _download(song, onProgress, onFallback);
    _inFlight[song.audioId] = task;
    try {
      return await task;
    } finally {
      _inFlight.remove(song.audioId);
    }
  }

  Future<File> _download(PortableSong song,
      void Function(double?)? onProgress,
      void Function(String)? onFallback) async {
    // 对外保存时只使用歌名，避免把音源内部 id 和额外分隔符暴露给用户。
    final fileName = '${ExportPathUtil.sanitizeFileName(song.title)}.mp3';
    for (final url in [song.audioUrl, song.wmcAudioUrl]) {
      http.StreamedResponse response;
      onProgress?.call(null);
      try {
        response = await _fetch(Uri.parse(url));
      } catch (_) {
        if (url == song.wmcAudioUrl) {
          throw const AudioDownloadSourceException('音源连接失败，请稍后重试');
        }
        continue;
      }
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        if (url == song.wmcAudioUrl) {
          throw AudioDownloadSourceException('音源下载失败（HTTP ${response.statusCode}）');
        }
        continue;
      }
      try {
        final file = await _write(
            fileName, _audioStream(response, onProgress), onFallback);
        onProgress?.call(1);
        return file;
      } on AudioDownloadSourceException {
        if (url == song.wmcAudioUrl) rethrow;
      }
    }
    throw const AudioDownloadSourceException('暂时没有可下载的音源');
  }

  /// 防止把接口错误页保存成 mp3；同时校验声明长度与实际接收长度。
  Stream<List<int>> _audioStream(http.StreamedResponse response,
      void Function(double?)? onProgress) async* {
    final compressed = response.headers['content-encoding'];
    final total = compressed == null || compressed == 'identity'
        ? response.contentLength : null;
    final prefix = <int>[];
    var received = 0;
    var validated = false;
    try {
      await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
        received += chunk.length;
        if (!validated) {
          prefix.addAll(chunk);
          if (prefix.length < 3) continue;
          final isId3 = prefix[0] == 0x49 && prefix[1] == 0x44 && prefix[2] == 0x33;
          final isFrame = prefix[0] == 0xff && (prefix[1] & 0xe0) == 0xe0;
          if (!isId3 && !isFrame) {
            throw const AudioDownloadSourceException('音源返回了无效的音频文件');
          }
          validated = true;
          yield prefix;
        } else {
          yield chunk;
        }
        onProgress?.call(total != null && total > 0
            ? (received / total).clamp(0.0, 1.0) : null);
      }
    } on AudioDownloadSourceException {
      rethrow;
    } catch (_) {
      throw const AudioDownloadSourceException('音源下载中断，请重试');
    }
    if (!validated || (total != null && total > 0 && received != total)) {
      throw const AudioDownloadSourceException('音源文件不完整，请重试');
    }
  }
}

class AudioDownloadSourceException implements Exception {
  final String message;
  const AudioDownloadSourceException(this.message);
  @override
  String toString() => message;
}
