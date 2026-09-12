// 一次性的解压逻辑验证脚本，用 `dart run tool/extract_chart_package_test.dart` 执行。
// 刻意用 print 输出用例结果（这是脚本不是应用代码），所以整文件关掉 avoid_print。
// ignore_for_file: avoid_print

// 验证 _extractChartPackage 的挑选逻辑（两套布局 + 各种边界）。
// 这段逻辑是从 PersonalizedChartPlayConfigure.dart 原样复制过来的，
// 因为私有函数无法从外部 import。
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

// ── 以下从 PersonalizedChartPlayConfigure.dart 复制 ──
const _kChartImageExtensions = <String>['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'];
const _kChartAudioExtensions = <String>['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'];

class _ExtractedChartPackage {
  final String maidataFileName;
  final Uint8List maidataBytes;
  final String? imageFileName;
  final Uint8List? imageBytes;
  final String? audioFileName;
  final Uint8List? audioBytes;
  const _ExtractedChartPackage({
    required this.maidataFileName,
    required this.maidataBytes,
    this.imageFileName,
    this.imageBytes,
    this.audioFileName,
    this.audioBytes,
  });
}

String _extensionOf(String path) {
  final base = path.split('/').last;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}

ArchiveFile? _pickArchiveFile(List<ArchiveFile> candidates, List<String> preferredExtensions) {
  if (candidates.isEmpty) return null;
  final sorted = [...candidates]..sort((a, b) {
      final ai = preferredExtensions.indexOf(_extensionOf(a.name));
      final bi = preferredExtensions.indexOf(_extensionOf(b.name));
      final ar = ai < 0 ? preferredExtensions.length : ai;
      final br = bi < 0 ? preferredExtensions.length : bi;
      if (ar != br) return ar.compareTo(br);
      final ad = '/'.allMatches(a.name).length;
      final bd = '/'.allMatches(b.name).length;
      if (ad != bd) return ad.compareTo(bd);
      return a.name.compareTo(b.name);
    });
  return sorted.first;
}

_ExtractedChartPackage? _extractChartPackage(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return null;
  }
  final allFiles = archive.files.where((f) => f.isFile && f.name.trim().isNotEmpty).toList();
  if (allFiles.isEmpty) return null;

  ArchiveFile? maidataEntry;
  for (final f in allFiles) {
    if (f.name.split('/').last.toLowerCase() == 'maidata.txt') {
      maidataEntry = f;
      break;
    }
  }
  maidataEntry ??= () {
    for (final f in allFiles) {
      final lower = f.name.toLowerCase();
      if (lower.endsWith('.txt') && lower.split('/').last.startsWith('maidata')) {
        return f;
      }
    }
    return null;
  }();
  if (maidataEntry == null) return null;

  final maidataBytes = maidataEntry.readBytes();
  if (maidataBytes == null) return null;

  final maidataDir = maidataEntry.name.contains('/')
      ? maidataEntry.name.substring(0, maidataEntry.name.lastIndexOf('/') + 1)
      : '';

  List<ArchiveFile> siblingsIn(String dir, bool Function(String) test) => allFiles
      .where((f) =>
          f.name.startsWith(dir) &&
          !f.name.substring(dir.length).contains('/') &&
          test(f.name))
      .toList();

  List<ArchiveFile> pickFrom(bool Function(String) test) {
    final inDir = siblingsIn(maidataDir, test);
    if (inDir.isNotEmpty) return inDir;
    return allFiles.where((f) => test(f.name)).toList();
  }

  final imageEntry = _pickArchiveFile(
    pickFrom((n) => _kChartImageExtensions.contains(_extensionOf(n))),
    _kChartImageExtensions,
  );
  final audioEntry = _pickArchiveFile(
    pickFrom((n) => _kChartAudioExtensions.contains(_extensionOf(n))),
    _kChartAudioExtensions,
  );

  return _ExtractedChartPackage(
    maidataFileName: maidataEntry.name.split('/').last,
    maidataBytes: maidataBytes,
    imageFileName: imageEntry?.name.split('/').last,
    imageBytes: imageEntry?.readBytes(),
    audioFileName: audioEntry?.name.split('/').last,
    audioBytes: audioEntry?.readBytes(),
  );
}
// ── 复制结束 ──

int _pass = 0, _fail = 0;
void check(String label, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label${detail == null ? '' : '  → $detail'}');
  }
}

Uint8List zipOf(Map<String, String> entries) {
  final a = Archive();
  entries.forEach((name, content) {
    a.add(ArchiveFile.bytes(name, Uint8List.fromList(utf8.encode(content))));
  });
  return Uint8List.fromList(ZipEncoder().encode(a));
}

const maidata = '&title=テスト\n&inote_5=(160){4}1,2,3\n&inote_4=(140){4}1,2\n';

void main() {
  print('=== 1. 平铺布局（.zip 通用包）===');
  var r = _extractChartPackage(zipOf({
    'maidata.txt': maidata,
    'bg.png': 'PNG',
    'track.mp3': 'MP3',
  }));
  check('解出 maidata', r?.maidataFileName == 'maidata.txt', '${r?.maidataFileName}');
  check('解出曲绘', r?.imageFileName == 'bg.png', '${r?.imageFileName}');
  check('解出音源', r?.audioFileName == 'track.mp3', '${r?.audioFileName}');
  check('maidata 内容完整', utf8.decode(r!.maidataBytes) == maidata);

  print('\n=== 2. 套一层文件夹（AstroDX .adx）===');
  r = _extractChartPackage(zipOf({
    'テスト楽曲/maidata.txt': maidata,
    'テスト楽曲/bg.png': 'PNG',
    'テスト楽曲/track.mp3': 'MP3',
  }));
  check('解出 maidata', r?.maidataFileName == 'maidata.txt', '${r?.maidataFileName}');
  check('解出曲绘', r?.imageFileName == 'bg.png', '${r?.imageFileName}');
  check('解出音源', r?.audioFileName == 'track.mp3', '${r?.audioFileName}');

  print('\n=== 3. 套两层文件夹 ===');
  r = _extractChartPackage(zipOf({
    'out/テスト/maidata.txt': maidata,
    'out/テスト/bg.jpg': 'JPG',
    'out/テスト/track.ogg': 'OGG',
  }));
  check('解出 maidata', r != null);
  check('解出曲绘', r?.imageFileName == 'bg.jpg', '${r?.imageFileName}');
  check('解出音源', r?.audioFileName == 'track.ogg', '${r?.audioFileName}');

  print('\n=== 4. 只有 maidata，没有附件（应容错）===');
  r = _extractChartPackage(zipOf({'maidata.txt': maidata}));
  check('解出 maidata', r != null);
  check('曲绘为 null', r?.imageFileName == null);
  check('音源为 null', r?.audioFileName == null);

  print('\n=== 5. 不是谱面包（没有 maidata）===');
  r = _extractChartPackage(zipOf({'readme.txt': 'hello', 'a.png': 'PNG'}));
  check('返回 null', r == null);

  print('\n=== 6. 不是 zip（乱字节）===');
  r = _extractChartPackage(Uint8List.fromList(List.generate(64, (i) => i % 256)));
  check('返回 null 而不是抛异常', r == null);

  print('\n=== 7. 附件优先级：bg.png 应优先于 cover.jpg 且优先于更深层的图 ===');
  r = _extractChartPackage(zipOf({
    'maidata.txt': maidata,
    'cover.jpg': 'JPG',
    'bg.png': 'PNG',
    'sub/deep.png': 'DEEP',
  }));
  check('选中 bg.png（png 优先级最高且最浅层）', r?.imageFileName == 'bg.png', '${r?.imageFileName}');

  print('\n=== 8. 同目录优先：根目录有附件，但 maidata 同目录也有，应取同目录 ===');
  r = _extractChartPackage(zipOf({
    'maidata.txt': maidata,
    'wrong_song/bg.png': 'SIBLING',
    'root_bg.png': 'ROOT',
  }));
  // maidata 在根目录，所以同目录就是根目录 → 应取 root_bg.png
  check('取根目录的 root_bg.png', r?.imageFileName == 'root_bg.png', '${r?.imageFileName}');

  r = _extractChartPackage(zipOf({
    'song/maidata.txt': maidata,
    'song/bg.png': 'SIBLING',
    'root_bg.png': 'ROOT',
  }));
  check('maidata 在 song/ 时取 song/bg.png', r?.imageFileName == 'bg.png', '${r?.imageFileName}');

  print('\n=== 9. maidata.txt.txt 被改坏的后缀 ===');
  r = _extractChartPackage(zipOf({'maidata.txt.txt': maidata, 'bg.png': 'PNG'}));
  check('仍能识别', r != null);

  print('\n=== 10. 目录项不应被当成文件 ===');
  r = _extractChartPackage(zipOf({
    'song/maidata.txt': maidata,
    'song/bg.png': 'PNG',
  }));
  check('正常解出', r?.imageFileName == 'bg.png');

  print('\n=== 11. Shift-JIS 编码的 maidata 字节应原样取出（解码由调用方负责）===');
  final sjisBytes = <int>[
    0x26, 0x74, 0x69, 0x74, 0x6C, 0x65, 0x3D, // &title=
    0x83, 0x65, 0x83, 0x58, 0x83, 0x67,       // "テスト" in Shift-JIS
  ];
  final a2 = Archive();
  a2.add(ArchiveFile.bytes('maidata.txt', Uint8List.fromList(sjisBytes)));
  r = _extractChartPackage(Uint8List.fromList(ZipEncoder().encode(a2)));
  check('字节未被改写', r != null && r.maidataBytes.length == sjisBytes.length,
      'len=${r?.maidataBytes.length} expected=${sjisBytes.length}');

  print('\n────────────────────────────');
  print('PASS: $_pass   FAIL: $_fail');
  if (_fail > 0) throw StateError('有 $_fail 项失败');
}
