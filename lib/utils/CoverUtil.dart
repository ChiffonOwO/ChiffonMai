/**
 * 曲绘路径工具类
 *
 * 负责构建曲绘（封面图）的本地 assets 路径、网络 URL，以及带多级 fallback 的 Widget。
 *
 * 本地路径构建规则（基于歌曲 ID 位数）：
 *   - <5 位：直接使用 `assets/cover/{songId}.webp`
 *   - 5 位：剔除第一个 '1' 及其后面连续的 '0'，直到遇到第一个非 '0' 数字
 *           例: 11312 → 1312, 10125 → 125, 10025 → 25
 *   - 6 位（方法1）：同 5 位规则
 *   - 6 位（方法2）：先剔除第一个 '1'，再应用 5 位规则
 *           例: 111234 → 方法1→11234, 方法2→1234
 */
import 'package:flutter/material.dart';

class CoverUtil {
  // ===========================================================================
  // 基础路径构建
  // ===========================================================================

  /// 构建曲绘 assets 路径（最基础方法）
  /// [coverId] 曲绘 ID，为 null 时使用 '0'
  static String buildCoverPath(String? coverId) =>
      'assets/cover/${coverId ?? '0'}.webp';

  // ===========================================================================
  // 内部辅助
  // ===========================================================================

  /// 剔除开头的第一个 '1' 及其后面连续的 '0'，直到遇到第一个非 '0' 数字。
  /// 若剔除后为空串则返回 '0'。
  ///
  /// 例: 11312→1312, 10125→125, 10025→25, 10000→0
  static String _stripLeadingOneAndZeros(String id) {
    if (id.isEmpty) return id;
    String result = id;
    // 剔除第一个 '1'
    if (result[0] == '1') {
      result = result.substring(1);
    }
    // 剔除后面连续的 '0'
    result = result.replaceAll(RegExp(r'^0+'), '');
    return result.isEmpty ? '0' : result;
  }

  // ===========================================================================
  // 本地曲绘路径（多级 fallback）
  // ===========================================================================

  /// 本地曲绘路径（主路径）
  ///
  /// 规则：
  /// - <5 位：直接使用 songId
  /// - 5 位：剔除第一个 '1' 及后面连续的 '0'
  /// - 6 位：同 5 位规则（方法1）
  static String getLocalCoverPath(String songId) {
    if (songId.length == 5 || songId.length == 6) {
      return buildCoverPath(_stripLeadingOneAndZeros(songId));
    }
    // <5 位：直接使用
    return buildCoverPath(songId);
  }

  /// 本地曲绘路径（备用路径1）
  ///
  /// - 6 位：方法2 — 先剔除第一个 '1'，再应用 5 位规则（即再次调用
  ///          _stripLeadingOneAndZeros），能处理更多连续 '1' 的情况
  /// - 其他位数：与 [getLocalCoverPath] 相同
  static String getLocalCoverPathRetry1(String songId) {
    if (songId.length == 6) {
      // 方法2: 先剔除第一个 '1'，再应用 5 位规则
      final afterRemoveOne =
          songId[0] == '1' ? songId.substring(1) : songId;
      return buildCoverPath(_stripLeadingOneAndZeros(afterRemoveOne));
    }
    return getLocalCoverPath(songId);
  }

  /// 本地曲绘路径（备用路径2）
  ///
  /// - 6 位：从右往左找第一个 '0'，保留其右侧内容（兼容宴会场谱面）
  /// - 其他位数：与 [getLocalCoverPath] 相同
  static String getLocalCoverPathRetry2(String songId) {
    if (songId.length == 6) {
      for (int i = songId.length - 1; i >= 0; i--) {
        if (songId[i] == '0') {
          return buildCoverPath(songId.substring(i + 1));
        }
      }
    }
    return buildCoverPath(songId);
  }

  // ===========================================================================
  // 网络曲绘 URL
  // ===========================================================================

  /// 构建网络曲绘 URL（所有本地加载均失败时的最终 fallback）
  ///
  /// 规则：
  /// - 6 位 ID：去除第一位
  /// - 不足 5 位：前面补 '0' 至 5 位
  /// - 目标 URL：https://www.diving-fish.com/covers/{coverId}.png
  static String getNetworkCoverUrl(String songId) {
    String coverId = songId;

    // 6 位数：去掉第一位
    if (coverId.length == 6) {
      coverId = coverId.substring(1);
    }
    // 不足 5 位：前面补 0 至 5 位
    if (coverId.length < 5) {
      coverId = coverId.padLeft(5, '0');
    }

    return 'https://www.diving-fish.com/covers/$coverId.png';
  }

  // ===========================================================================
  // 曲绘 Widget（带多级 fallback）
  // ===========================================================================

  /// 构建曲绘 Widget
  ///
  /// 加载顺序：
  /// 1. 原始 songId 路径
  /// 2. 本地主路径
  /// 3. 本地备用路径1
  /// 4. 本地备用路径2
  /// 5. 网络加载
  /// 6. 默认曲绘 0.webp
  static Widget buildCoverWidget(String songId, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white),
      child: Image.asset(
        buildCoverPath(songId),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            getLocalCoverPath(songId),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                getLocalCoverPathRetry1(songId),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    getLocalCoverPathRetry2(songId),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.network(
                        getNetworkCoverUrl(songId),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            buildCoverPath('0'),
                            fit: BoxFit.cover,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// 构建曲绘 Widget（带 BuildContext）
  ///
  /// 加载顺序与 [buildCoverWidget] 相同。
  static Widget buildCoverWidgetWithContext(
      BuildContext context, String songId, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white),
      child: Image.asset(
        buildCoverPath(songId),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            getLocalCoverPath(songId),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                getLocalCoverPathRetry1(songId),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    getLocalCoverPathRetry2(songId),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.network(
                        getNetworkCoverUrl(songId),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            buildCoverPath('0'),
                            fit: BoxFit.cover,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// 构建曲绘 Widget（带 BuildContext + 圆角矩形）
  static Widget buildCoverWidgetWithContextRRect(
      BuildContext context, String songId, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: buildCoverWidgetWithContext(context, songId, size),
    );
  }
}
