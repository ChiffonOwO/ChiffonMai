import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class LZYCheckUpdateManager {
  static final LZYCheckUpdateManager _instance = LZYCheckUpdateManager._internal();
  factory LZYCheckUpdateManager() => _instance;
  LZYCheckUpdateManager._internal();

  // ==================== 检查更新配置 =====================
  final String pastebinRawUrl = ApiUrls.checkUpdateApi;
  final bool forceUpdate = false;
  // ======================================================

  /// 从 pastebin 获取在线配置
  Future<Map<String, dynamic>?> _getCloudConfig() async {
    try {
      final response = await get(Uri.parse(pastebinRawUrl));
      if (response.statusCode == 200) {
        final jsonStr = response.body.trim();
        return jsonDecode(jsonStr);
      }
    } catch (e) {
      print("获取配置失败：$e");
    }
    return null;
  }

  /// 检查更新
  Future<Map<String, dynamic>> checkUpdate() async {
    print("开始检查更新...");
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      print("当前版本：${packageInfo.version} (build: $localBuild)");

      final cloudConfig = await _getCloudConfig();
      if (cloudConfig == null) return {"hasUpdate": false};

      String latestVersion = cloudConfig["version"] ?? "";
      int latestBuild = cloudConfig["buildNumber"] ?? 0;
      String updateLog = cloudConfig["updateLog"] ?? "优化体验";
      String downloadUrl = cloudConfig["downloadUrl"] ?? "";

      print("最新版本：$latestVersion (build: $latestBuild)");

      if (latestBuild > localBuild) {
        print("发现新版本");
        return {
          "hasUpdate": true,
          "currentVersion": packageInfo.version,
          "latestVersion": latestVersion,
          "updateLog": updateLog,
          "downloadUrl": downloadUrl,
        };
      } else {
        print("已是最新版本");
      }
    } catch (e) {
      print("检查更新失败：$e");
    }
    return {"hasUpdate": false};
  }

  /// 打开下载页
  Future<void> openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> shouldShowUpdateDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDismissTime = prefs.getInt('lastUpdateDismissTime');
    if (lastDismissTime != null) {
      final threeDaysAgo = DateTime.now().subtract(Duration(days: 3)).millisecondsSinceEpoch;
      if (lastDismissTime > threeDaysAgo) return false;
    }
    return true;
  }

  Future<void> recordDismissTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastUpdateDismissTime', DateTime.now().millisecondsSinceEpoch);
  }

  /// 显示更新弹窗
  Future<void> showUpdateDialog(BuildContext context) async {
    if (!await shouldShowUpdateDialog()) return;

    var info = await checkUpdate();
    if (!info["hasUpdate"] || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (c) => AlertDialog(
        title: Text("发现新版本 ${info["latestVersion"]}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text("更新内容：\n${info["updateLog"]}"),
              ),
            ),
            SizedBox(height: 10),
            Text("当前版本：${info["currentVersion"]}"),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text("稍后"),
            ),
          if (!forceUpdate)
            TextButton(
              onPressed: () async {
                await recordDismissTime();
                Navigator.pop(c);
              },
              child: Text("3天内不提示"),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              openDownloadPage(info["downloadUrl"]);
            },
            child: Text("立即下载"),
          ),
        ],
      ),
    );
  }
}