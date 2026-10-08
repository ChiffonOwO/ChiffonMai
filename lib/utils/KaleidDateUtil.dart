import 'package:flutter/material.dart';
import '../service/KaleidXScope/KaleidXScopeSelectService.dart';
import 'AppTheme.dart';

/// 万花镜日期统一按 2026 年展示。接口历史上同时出现过 ISO、斜线、点号和中文格式，
/// 不能把无法解析的值静默当成 1 月 1 日，否则整页会误报当前时间段。
class KaleidDateUtil {
  static Widget currentHeader(
      BuildContext context, Iterable<dynamic> challenges) {
    final scheme = Theme.of(context).colorScheme;
    final phase = _findCurrent(challenges);
    final first = phase == null
        ? '当前时间段（2026年）：暂无进行中的挑战'
        : '当前时间段（2026年） ${range(phase.startDate as String, phase.endDate as String?).replaceAll(' - ', '-')}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(first,
            style: TextStyle(
                color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        if (phase == null)
          Text('请查看下方时间段安排', style: TextStyle(color: scheme.onPrimaryContainer))
        else
          Text.rich(
            TextSpan(
              // 富文本各字重分别指定网络字体，避免继承系统字体或错误的字体文件。
              style: AppTheme.font(color: scheme.onPrimaryContainer),
              children: [
                const TextSpan(text: '难度：'),
                TextSpan(
                  text: phase.difficulty as String,
                  style: AppTheme.font(
                    color: KaleidXScopeSelectService.getDifficultyColor(
                        phase.difficulty as String),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: phase.target == null
                      ? '　血量：${phase.lifeTarget}'
                      : '　血量：一阶段 ${phase.lifeTarget} 二阶段 ${phase.target}',
                ),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
      ]),
    );
  }

  static dynamic _findCurrent(Iterable<dynamic> challenges) {
    final today = DateTime(2026, DateTime.now().month, DateTime.now().day);
    for (final challenge in challenges) {
      for (final phase in (challenge.phases as Iterable)) {
        final start = parse(phase.startDate as String);
        final end =
            phase.endDate == null ? null : parse(phase.endDate as String);
        if (start != null &&
            !today.isBefore(start) &&
            (end == null || !today.isAfter(end))) return phase;
      }
    }
    return null;
  }

  static DateTime? parse(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    final chinese =
        RegExp(r'^(?:2026年)?\s*(\d{1,2})月\s*(\d{1,2})日').firstMatch(value);
    if (chinese != null)
      return _safe(int.parse(chinese.group(1)!), int.parse(chinese.group(2)!));
    final iso =
        RegExp(r'^(?:\d{4}[-/.])?(\d{1,2})[-/.](\d{1,2})').firstMatch(value);
    if (iso != null)
      return _safe(int.parse(iso.group(1)!), int.parse(iso.group(2)!));
    final md = RegExp(r'^(\d{1,2})\s*[月/.\-]\s*(\d{1,2})').firstMatch(value);
    if (md != null)
      return _safe(int.parse(md.group(1)!), int.parse(md.group(2)!));
    return null;
  }

  static DateTime? _safe(int month, int day) {
    final date = DateTime(2026, month, day);
    return date.year == 2026 && date.month == month && date.day == day
        ? date
        : null;
  }

  static String format(String raw) {
    final date = parse(raw);
    return date == null ? '日期待更新' : '${date.month}月${date.day}日';
  }

  static String range(String start, String? end) =>
      '${format(start)} - ${end == null || end.trim().isEmpty ? '后续' : format(end)}';
}
