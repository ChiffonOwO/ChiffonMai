import 'package:flutter/foundation.dart';

/// MaimaiHub 结算画面识别结果
///
/// 对应 `POST /api/v1/me/ocr/recognize` 的响应（字段与 ocr-api 的 Pydantic 模型
/// `BatchRecognitionResponse` / `RecognitionItem` / `ScoreCandidate` 一一对应）：
/// ```json
/// {
///   "results": [
///     {
///       "index": 0,
///       "filename": "score.jpg",
///       "status": "ok",
///       "candidates": [
///         {"title": "METATRON", "confidence": 0.9999, "sources": ["cover", "title"]}
///       ],
///       "achievement": 100.8039,
///       "dxScore": 2575,
///       "difficulty": "master",
///       "level": "14",
///       "isDx": false,
///       "fc": null,
///       "fs": null,
///       "error": null
///     }
///   ]
/// }
/// ```
///
/// 与自家后端那套已废弃的通用 OCR 是两回事：那边返回**原始文本块**（需自行解析字段），
/// 这里返回**已解析好的结构化成绩**。所以两者的 UI 不能直接互换。
///
/// 一张图失败不影响同批其它图：逐张看 [MaimaiHubOcrItem.status]。
@immutable
class MaimaiHubOcrBatch {
  final List<MaimaiHubOcrItem> results;

  const MaimaiHubOcrBatch({required this.results});

  factory MaimaiHubOcrBatch.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    final items = <MaimaiHubOcrItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          items.add(MaimaiHubOcrItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return MaimaiHubOcrBatch(results: items);
  }

  /// 是否至少有一张识别成功
  bool get hasAnySuccess => results.any((r) => r.isOk);

  /// 识别成功的条数
  int get okCount => results.where((r) => r.isOk).length;
}

/// 单张图片的识别结果
@immutable
class MaimaiHubOcrItem {
  final int index;
  final String filename;

  /// `ok` / `unrecognized` / `error`
  final String status;

  /// 曲名候选。**服务端不保证顺序**，用 [bestCandidate] 取置信度最高的一个。
  final List<MaimaiHubOcrCandidate> candidates;

  final double? achievement;
  final int? dxScore;

  /// `basic` / `advanced` / `expert` / `master` / `remaster` / `utage`
  final String? difficulty;
  final String? level;
  final bool? isDx;

  /// Full Combo：`fc` / `fcp` / `ap` / `app`
  final String? fc;

  /// Full Sync：`fs` / `fsp` / `fdx` / `fdxp`
  final String? fs;

  /// [status] 非 `ok` 时的失败原因
  final String? error;

  const MaimaiHubOcrItem({
    required this.index,
    required this.filename,
    required this.status,
    this.candidates = const [],
    this.achievement,
    this.dxScore,
    this.difficulty,
    this.level,
    this.isDx,
    this.fc,
    this.fs,
    this.error,
  });

  factory MaimaiHubOcrItem.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'];
    final candidates = <MaimaiHubOcrCandidate>[];
    if (rawCandidates is List) {
      for (final e in rawCandidates) {
        if (e is Map) {
          candidates.add(
              MaimaiHubOcrCandidate.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return MaimaiHubOcrItem(
      index: (json['index'] as num?)?.toInt() ?? 0,
      filename: (json['filename'] ?? '').toString(),
      status: (json['status'] ?? 'error').toString(),
      candidates: candidates,
      achievement: (json['achievement'] as num?)?.toDouble(),
      dxScore: (json['dxScore'] as num?)?.toInt(),
      difficulty: json['difficulty'] as String?,
      level: json['level'] as String?,
      isDx: json['isDx'] as bool?,
      fc: json['fc'] as String?,
      fs: json['fs'] as String?,
      error: json['error'] as String?,
    );
  }

  bool get isOk => status == 'ok';

  /// 置信度最高的候选；无候选时返回 null。
  ///
  /// 服务端模型没有声明 candidates 的顺序，所以这里显式取最大值，
  /// 不依赖未文档化的排序。confidence 允许为 null，按 -1 参与比较。
  MaimaiHubOcrCandidate? get bestCandidate {
    if (candidates.isEmpty) return null;
    var best = candidates.first;
    for (final c in candidates.skip(1)) {
      if (c.confidenceOrMinusOne > best.confidenceOrMinusOne) best = c;
    }
    return best;
  }
}

/// 曲名候选项
@immutable
class MaimaiHubOcrCandidate {
  final String title;

  /// 0.0 ~ 1.0；服务端允许为 null（模型字段是 `float | None`）
  final double? confidence;

  /// 命中来源：`cover`（曲绘）/ `title`（标题）
  final List<String> sources;

  const MaimaiHubOcrCandidate({
    required this.title,
    this.confidence,
    this.sources = const [],
  });

  factory MaimaiHubOcrCandidate.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final sources = <String>[];
    if (rawSources is List) {
      for (final s in rawSources) {
        if (s != null) sources.add(s.toString());
      }
    }
    return MaimaiHubOcrCandidate(
      title: (json['title'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      sources: sources,
    );
  }

  /// 供排序用的置信度：null 视为 -1（排最后）
  double get confidenceOrMinusOne => confidence ?? -1.0;
}
