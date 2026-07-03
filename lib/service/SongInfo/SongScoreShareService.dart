import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_first_flutter_app/utils/CoverUtil.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/ColorUtil.dart';

/// 徽章颜色数据
class _BadgeColors {
  final Color bg;
  final Color fg;
  final String label;
  const _BadgeColors({required this.bg, required this.fg, required this.label});
}

/// 单曲成绩分享卡片服务
/// 将歌曲信息和玩家最佳成绩渲染为精美的分享图片
class SongScoreShareService {
  /// 导出为图片的主方法
  static Future<File?> convertToImage(
    BuildContext context, {
    required String songId,
    required String songTitle,
    required String artist,
    required String songType,
    required int levelIndex,
    required String levelStr,
    required double ds,
    required String genre,
    required int bpm,
    required double achievements,
    required int ra,
    required int dxScore,
    required int maxDxScore,
    required String fc,
    required String fs,
    required String rawRate,
  }) async {
    OverlayEntry? overlayEntry;
    try {
      debugPrint('=== SongScoreShare: STARTING IMAGE CONVERSION ===');

      // 请求存储权限
      final status = await _requestStoragePermission();
      debugPrint('Storage permission: $status');

      // 读取用户信息
      final prefs = await SharedPreferences.getInstance();
      final userNickname = prefs.getString('userNickname') ?? '';
      final totalRating = prefs.getInt('best50TotalRA') ?? 0;
      final avatarId = prefs.getInt('selectedAvatarId') ?? 1;
      final avatarUrl = avatarId > 0
          ? 'https://assets2.lxns.net/maimai/icon/$avatarId.png'
          : null;

      // 创建GlobalKey用于截图
      GlobalKey globalKey = GlobalKey();

      // 构建分享卡片Widget
      Widget imageWidget = RepaintBoundary(
        key: globalKey,
        child: _buildShareCard(
          context: context,
          songId: songId,
          songTitle: songTitle,
          artist: artist,
          songType: songType,
          levelIndex: levelIndex,
          levelStr: levelStr,
          ds: ds,
          genre: genre,
          bpm: bpm,
          achievements: achievements,
          ra: ra,
          dxScore: dxScore,
          maxDxScore: maxDxScore,
          fc: fc,
          fs: fs,
          rawRate: rawRate,
          userNickname: userNickname,
          totalRating: totalRating,
          avatarUrl: avatarUrl,
        ),
      );

      // 创建离屏OverlayEntry
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -9999,
          top: -9999,
          width: 1200,
          child: Material(
            type: MaterialType.transparency,
            child: imageWidget,
          ),
        ),
      );

      // 插入到Overlay并等待渲染
      Overlay.of(context).insert(overlayEntry);
      await _waitForRender();

      // 捕获为图片
      final boundary = globalKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('SongScoreShare: RenderRepaintBoundary not found');
        overlayEntry.remove();
        return null;
      }

      ui.Image image;
      try {
        image = await boundary.toImage(pixelRatio: 3.0);
      } catch (e) {
        debugPrint('SongScoreShare: First capture failed: $e');
        await Future.delayed(Duration(milliseconds: 200));
        image = await boundary.toImage(pixelRatio: 3.0);
      }

      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('SongScoreShare: ByteData is null');
        overlayEntry.remove();
        image.dispose();
        return null;
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();
      image.dispose();
      overlayEntry.remove();

      // 保存图片
      return await _saveImage(pngBytes, songTitle, status.isGranted);
    } catch (e) {
      debugPrint('SongScoreShare: Error: $e');
      overlayEntry?.remove();
      return null;
    }
  }

  /// 构建分享卡片Widget
  static Widget _buildShareCard({
    required BuildContext context,
    required String songId,
    required String songTitle,
    required String artist,
    required String songType,
    required int levelIndex,
    required String levelStr,
    required double ds,
    required String genre,
    required int bpm,
    required double achievements,
    required int ra,
    required int dxScore,
    required int maxDxScore,
    required String fc,
    required String fs,
    required String rawRate,
    required String userNickname,
    required int totalRating,
    String? avatarUrl,
  }) {
    // UTAGE 宴会場检测（6位数ID的歌曲使用粉色主题）
    final bool isUtage = songId.length == 6;

    // 获取主题色（与 SongInfoPage 保持一致）
    final accentColor = isUtage ? Color(0xFFFF69B4) : ColorUtil.getCardColor(levelIndex);
    final bgGradientStart = isUtage ? Color(0xFFFFF0F5) : _getBgStartColor(levelIndex);
    final bgGradientEnd = isUtage ? Color(0xFFFFD6E8) : _getBgEndColor(levelIndex);

    // 达成率百分比
    final achievementPercent = achievements;
    // 评级直接使用 API 返回的 rate 字段（与 userPlayDataManager 缓存一致）
    final rateDisplay = StringUtil.formatRate(rawRate);
    final typeLabel = StringUtil.formatSongType(songType);
    final dxScorePercent = maxDxScore > 0 ? (dxScore / maxDxScore * 100).toStringAsFixed(2) : '0.00';

    // 难度名称（UTAGE 歌曲显示 "UTAGE"，与 SongInfoPage 保持一致）
    final diffNames = ['Basic', 'Advanced', 'Expert', 'Master', 'Re:Master'];
    final diffName = isUtage ? 'UTAGE' : diffNames[levelIndex.clamp(0, 4)];

    // 星星等级（与 SongInfoPage._calculateStars 保持一致：带空格格式 "✦ 6"）
    final scoreRate = maxDxScore > 0 ? dxScore / maxDxScore : 0.0;
    final String starDisplay = _calcStars(scoreRate);
    // 星星 bonus（与 SongInfoPage._calculateStarsBonus 保持一致："✦ 6 +123"）
    final String starBonus = _calcStarsBonus(scoreRate, dxScore, maxDxScore);
    final Color starColor = _getStarColor(starDisplay);

    // FC/FS 颜色（与 SongInfoPage._buildBadge 保持一致）
    final fcColors = _getBadgeColors(fc);
    final fsColors = _getBadgeColors(fs);

    return Container(
      width: 1200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgGradientStart, bgGradientEnd],
        ),
      ),
      child: Stack(
        children: [
          // 装饰性背景元素
          ..._buildDecorativeElements(accentColor),

          // 主内容
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                // 顶部：封面 + 歌曲信息
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 曲绘封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          border: Border.all(color: accentColor, width: 4),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: accentColor.withAlpha(80), blurRadius: 20, offset: Offset(0, 8)),
                          ],
                        ),
                        child: CoverUtil.buildCoverWidgetWithContext(context, songId, 260),
                      ),
                    ),
                    SizedBox(width: 40),

                    // 歌曲信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16),
                          // 歌曲标题
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(songTitle,
                                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50), height: 1.2),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          // 艺术家
                          Text(artist,
                            style: TextStyle(fontSize: 28, color: Color(0xFF546161).withAlpha(200), fontWeight: FontWeight.w500)),
                          SizedBox(height: 16),
                          // 歌曲元信息标签行（ST/DX/UTAGE 类型放在第一个）
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              _buildInfoChip(isUtage ? 'UTAGE' : typeLabel,
                                isUtage ? Color(0xFFFF6B8B) : (songType == 'SD' ? Colors.blue : Colors.orange), filled: true),
                              _buildInfoChip('$diffName $levelStr', accentColor, filled: true),
                              _buildInfoChip('定数 ${ds.toStringAsFixed(1)}', accentColor),
                              _buildInfoChip('BPM $bpm', Color(0xFF546161)),
                              _buildInfoChip(genre, Color(0xFF546161)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 36),

                // 中部：用户信息 + 达成率（并排）
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 左侧：用户信息
                    if (userNickname.isNotEmpty || totalRating > 0)
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(140),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 15, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (avatarUrl != null)
                              Container(
                                width: 72,
                                height: 72,
                                margin: EdgeInsets.only(right: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accentColor, width: 3),
                                  image: DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover),
                                ),
                              ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (userNickname.isNotEmpty)
                                  Text(userNickname,
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                                if (totalRating > 0)
                                  Text('总 Rating: $totalRating',
                                    style: TextStyle(fontSize: 22, color: accentColor, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),

                    if (userNickname.isNotEmpty || totalRating > 0)
                      SizedBox(width: 28),

                    // 右侧：达成率（核心数据，大字体突出）
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 28, horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(180),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 15, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text('单曲达成率',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600,
                                color: Color(0xFF546161).withAlpha(180), letterSpacing: 4)),
                            SizedBox(height: 6),
                            Text('${achievementPercent.toStringAsFixed(4)}%',
                              style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50), letterSpacing: 2)),
                            SizedBox(height: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [accentColor, accentColor.withAlpha(200)]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(rateDisplay,
                                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 28),

                // 底部：统计数据网格
                Container(
                  padding: EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 15, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Rating
                      _buildStatItem(
                        icon: Icons.star,
                        label: 'Rating',
                        value: ra.toString(),
                        accentColor: accentColor,
                      ),
                      _buildStatDivider(),
                      // DX Score
                      _buildStatItem(
                        icon: Icons.score,
                        label: 'DX分数',
                        value: '$dxScore / $maxDxScore',
                        subtitle: '$dxScorePercent%',
                        accentColor: accentColor,
                      ),
                      _buildStatDivider(),
                      // FC
                      _buildStatItem(
                        icon: Icons.music_note,
                        label: 'FC',
                        value: fcColors.label,
                        accentColor: accentColor,
                        valueColor: fcColors.fg,
                      ),
                      _buildStatDivider(),
                      // FS
                      _buildStatItem(
                        icon: Icons.auto_awesome,
                        label: 'FS',
                        value: fsColors.label,
                        accentColor: accentColor,
                        valueColor: fsColors.fg,
                      ),
                      _buildStatDivider(),
                      // 星星等级（带 bonus 差值）
                      _buildStatItem(
                        icon: Icons.stars,
                        label: '星星',
                        value: starDisplay,
                        subtitle: starBonus,
                        accentColor: accentColor,
                        valueColor: starColor,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40),

                // 底部署名
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note_rounded,
                        size: 22, color: accentColor.withAlpha(150)),
                    SizedBox(width: 8),
                    Text(
                      'ChiffonMai',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: accentColor.withAlpha(150),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建信息标签
  static Widget _buildInfoChip(String text, Color color, {bool filled = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        border: filled ? null : Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
          color: filled ? Colors.white : color)),
    );
  }

  /// 构建统计项
  static Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color accentColor,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: accentColor.withAlpha(180)),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 20,
              color: Color(0xFF546161).withAlpha(180),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Color(0xFF2C3E50),
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF546161).withAlpha(150),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 统计项分隔线
  static Widget _buildStatDivider() {
    return Container(
      width: 2,
      height: 80,
      color: Color(0xFF546161).withAlpha(30),
    );
  }

  /// 构建装饰性背景元素
  static List<Widget> _buildDecorativeElements(Color accentColor) {
    return [
      // 右上角大圆
      Positioned(
        right: -80,
        top: -80,
        child: Container(
          width: 400,
          height: 400,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withAlpha(15),
          ),
        ),
      ),
      // 左下角大圆
      Positioned(
        left: -60,
        bottom: -60,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withAlpha(12),
          ),
        ),
      ),
      // 左上角装饰线
      Positioned(
        left: 0,
        top: 0,
        child: Container(
          width: 1200,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withAlpha(80),
                accentColor.withAlpha(10),
              ],
            ),
          ),
        ),
      ),
      // 右下角装饰线
      Positioned(
        left: 0,
        bottom: 0,
        child: Container(
          width: 1200,
          height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withAlpha(10),
                accentColor.withAlpha(60),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  // --- 星星和徽章颜色（与 SongInfoPage 保持一致）---

  /// 计算星星等级显示字符串（与 SongInfoPage._calculateStars 一致："✦ 6"）
  static String _calcStars(double scoreRate) {
    if (scoreRate >= 0.99) return '✦ 6';
    if (scoreRate >= 0.98) return '✦ 5.5';
    if (scoreRate >= 0.97) return '✦ 5';
    if (scoreRate >= 0.95) return '✦ 4';
    if (scoreRate >= 0.93) return '✦ 3';
    if (scoreRate >= 0.90) return '✦ 2';
    if (scoreRate >= 0.85) return '✦ 1';
    return '✦ 0';
  }

  /// 计算星星 bonus 差值（与 SongInfoPage._calculateStarsBonus 一致："✦ 6 +123"）
  static String _calcStarsBonus(double scoreRate, int score, int maxScore) {
    double starLevel = 0, minRate = 0.0;
    if (scoreRate >= 0.99) { starLevel = 6; minRate = 0.99; }
    else if (scoreRate >= 0.98) { starLevel = 5.5; minRate = 0.98; }
    else if (scoreRate >= 0.97) { starLevel = 5; minRate = 0.97; }
    else if (scoreRate >= 0.95) { starLevel = 4; minRate = 0.95; }
    else if (scoreRate >= 0.93) { starLevel = 3; minRate = 0.93; }
    else if (scoreRate >= 0.90) { starLevel = 2; minRate = 0.90; }
    else if (scoreRate >= 0.85) { starLevel = 1; minRate = 0.85; }
    else { starLevel = 0; minRate = 0.85; }

    int minScore = (maxScore * minRate).ceil();
    int difference = score - minScore;
    String symbol = difference >= 0 ? '+' : '';
    dynamic displayLevel = starLevel == 0 ? 1 : starLevel;
    final levelStr2 = displayLevel == displayLevel.roundToDouble()
        ? displayLevel.toInt().toString()
        : displayLevel.toString();
    return '✦ $levelStr2 $symbol$difference';
  }

  /// 获取星星颜色（与 SongInfoPage._getStarsColor 一致）
  static Color _getStarColor(String stars) {
    if (stars.startsWith('✦ 6') || stars.startsWith('✦ 5.5') || stars.startsWith('✦ 5')) return Colors.yellow;
    if (stars.startsWith('✦ 4') || stars.startsWith('✦ 3')) return Colors.orange;
    if (stars.startsWith('✦ 2') || stars.startsWith('✦ 1')) return Colors.green.shade300;
    if (stars.startsWith('✦ 0')) return Colors.grey;
    return Colors.white;
  }

  /// 获取徽章颜色（与 SongInfoPage._buildBadge 一致）
  static _BadgeColors _getBadgeColors(String text) {
    switch (text) {
      case 'app': return _BadgeColors(bg: Color(0xFFFFF3E0), fg: Color(0xFFF57C00), label: 'AP+');
      case 'ap':  return _BadgeColors(bg: Color(0xFFFFF3E0), fg: Color(0xFFF57C00), label: 'AP');
      case 'fcp': return _BadgeColors(bg: Color(0xFFD4F4DD), fg: Color(0xFF2E7D32), label: 'FC+');
      case 'fc':  return _BadgeColors(bg: Color(0xFFD4F4DD), fg: Color(0xFF2E7D32), label: 'FC');
      case 'fsp': return _BadgeColors(bg: Color.fromARGB(255, 224, 244, 255), fg: Color.fromARGB(255, 0, 135, 245), label: 'FS+');
      case 'fs':  return _BadgeColors(bg: Color.fromARGB(255, 224, 244, 255), fg: Color.fromARGB(255, 0, 135, 245), label: 'FS');
      case 'sync': return _BadgeColors(bg: Color.fromARGB(255, 224, 244, 255), fg: Color.fromARGB(255, 0, 135, 245), label: 'SC');
      case 'fsd': return _BadgeColors(bg: Color(0xFFFFF3E0), fg: Color(0xFFF57C00), label: 'FDX');
      case 'fsdp': return _BadgeColors(bg: Color(0xFFFFF3E0), fg: Color(0xFFF57C00), label: 'FDX+');
      default: return _BadgeColors(bg: Colors.grey.shade200, fg: Colors.grey, label: '-');
    }
  }

  // --- 颜色辅助（与 SongInfoPage 一致）---

  /// 获取背景渐变起始色
  static Color _getBgStartColor(int levelIndex) {
    switch (levelIndex) {
      case 0:
        return Color(0xFFF0F8F0);
      case 1:
        return Color(0xFFFFF8F0);
      case 2:
        return Color(0xFFFFF0F4);
      case 3:
        return Color(0xFFF8F0FF);
      case 4:
        return Color(0xFFFCF0FF);
      default:
        return Color(0xFFF8F0FF);
    }
  }

  /// 获取背景渐变结束色
  static Color _getBgEndColor(int levelIndex) {
    switch (levelIndex) {
      case 0:
        return Color(0xFFE0F0E0);
      case 1:
        return Color(0xFFFFE8D0);
      case 2:
        return Color(0xFFFFE0E8);
      case 3:
        return Color(0xFFEDE0FF);
      case 4:
        return Color(0xFFF8E0FF);
      default:
        return Color(0xFFEDE0FF);
    }
  }

  // --- 权限和保存逻辑（复用现有模式）---

  static Future<PermissionStatus> _requestStoragePermission() async {
    final status = await Permission.storage.status;
    final photoStatus = await Permission.photos.status;
    final videoStatus = await Permission.videos.status;

    if (status.isGranted || photoStatus.isGranted || videoStatus.isGranted) {
      return status.isGranted ? status : photoStatus;
    }

    final results = await [
      Permission.storage,
      Permission.photos,
      Permission.videos,
    ].request();

    return results[Permission.storage] ?? PermissionStatus.denied;
  }

  static Future<File?> _saveImage(
    Uint8List pngBytes,
    String songTitle,
    bool hasPermission,
  ) async {
    Directory? directory;

    if (hasPermission) {
      try {
        String picturesPath = '/storage/emulated/0/Pictures';
        directory = Directory(picturesPath);
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        bool canWrite = await _checkDirectoryWritable(directory);
        if (!canWrite) {
          directory = null;
        }
      } catch (e) {
        debugPrint('SongScoreShare: Pictures dir error: $e');
        directory = null;
      }
    }

    if (directory == null) {
      try {
        directory = await getApplicationDocumentsDirectory();
      } catch (e) {
        try {
          directory = await getExternalStorageDirectory();
        } catch (e2) {
          debugPrint('SongScoreShare: No storage dir found');
          return null;
        }
      }
    }

    if (directory == null) return null;

    // Android: 尝试 MediaStore API
    if (Platform.isAndroid && hasPermission) {
      String? galleryPath = await _saveImageToGallery(
        pngBytes,
        'chiffonmai_${_sanitizeFileName(songTitle)}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (galleryPath != null) {
        await _notifySystemGallery(galleryPath);
        return File(galleryPath);
      }
    }

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final file = File(
      '${directory.path}/chiffonmai_${_sanitizeFileName(songTitle)}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes);

    if (Platform.isAndroid) {
      await _notifySystemGallery(file.path);
    }

    return file;
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(' ', '_');
  }

  static Future<String?> _saveImageToGallery(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_store');
      final String? result = await channel.invokeMethod('saveImage', {
        'imageBytes': imageBytes,
        'fileName': fileName,
      });
      return result;
    } catch (e) {
      debugPrint('SongScoreShare: MediaStore error: $e');
      return null;
    }
  }

  static Future<void> _notifySystemGallery(String filePath) async {
    try {
      await MediaScanner.loadMedia(path: filePath);
    } catch (e) {
      debugPrint('SongScoreShare: MediaScanner error: $e');
    }
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_scan');
      await channel.invokeMethod('scanFile', {'path': filePath});
    } catch (e) {
      debugPrint('SongScoreShare: scanFile error: $e');
    }
    try {
      const MethodChannel channel = MethodChannel('com.example.app/media_scan');
      await channel.invokeMethod('scanImage', {'path': filePath});
    } catch (e) {
      debugPrint('SongScoreShare: scanImage error: $e');
    }
  }

  static Future<bool> _checkDirectoryWritable(Directory directory) async {
    try {
      String testFileName =
          'test_write_${DateTime.now().millisecondsSinceEpoch}.tmp';
      File testFile = File('${directory.path}/$testFileName');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _waitForRender() async {
    Completer<void> completer1 = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer1.complete());
    await completer1.future;

    Completer<void> completer2 = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer2.complete());
    await completer2.future;

    await Future.delayed(Duration(milliseconds: 500));
  }
}
