import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      // 创建自定义客户端，添加超时和User-Agent
      final client = http.Client();
      try {
        final response = await client.get(
          Uri.parse(pastebinRawUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final jsonStr = response.body.trim();
          print("获取配置成功：$jsonStr");
          return jsonDecode(jsonStr);
        } else {
          print("获取配置失败，状态码：${response.statusCode}");
        }
      } on SocketException catch (e) {
        print("网络连接失败：$e");
      } on HttpException catch (e) {
        print("HTTP异常：$e");
      } on FormatException catch (e) {
        print("数据格式错误：$e");
      } catch (e) {
        print("获取配置失败：$e");
      } finally {
        client.close();
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
      
      // 如果网络请求失败，返回网络错误状态
      if (cloudConfig == null) {
        print("无法获取云端配置，可能是网络问题");
        return {
          "hasUpdate": false,
          "networkError": true, // 标记网络错误
          "message": "网络连接失败，请检查网络后重试",
        };
      }

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
          "currentBuild": localBuild,
          "latestVersion": latestVersion,
          "latestBuild": latestBuild,
          "updateLog": updateLog,
          "downloadUrl": downloadUrl,
        };
      } else {
        print("已是最新版本");
        // 返回版本信息，以便在弹窗中显示
        return {
          "hasUpdate": false,
          "currentVersion": packageInfo.version,
          "currentBuild": localBuild,
          "latestVersion": latestVersion,
          "latestBuild": latestBuild,
          "updateLog": updateLog,
        };
      }
    } catch (e) {
      print("检查更新失败：$e");
      return {
        "hasUpdate": false,
        "networkError": true,
        "message": "检查更新失败：$e",
      };
    }
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
  /// [force] 为 true 时强制显示，忽略3天内不提示的设置
  Future<void> showUpdateDialog(BuildContext context, {bool force = false}) async {
    if (!force && !await shouldShowUpdateDialog()) return;

    var info = await checkUpdate();
    
    // 如果上下文已销毁，直接返回
    if (!context.mounted) return;
    
    // 使用 Completer 确保 Future 在对话框关闭后才完成
    final completer = Completer<void>();
    
    // 如果有网络错误或其他异常，显示错误提示
    if (info["networkError"] == true) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (c) => AlertDialog(
          title: Text("检查更新失败"),
          content: Text(info["message"] ?? "无法连接到服务器，请检查网络后重试"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                completer.complete();
              },
              child: Text("确定"),
            ),
          ],
        ),
      );
      return completer.future;
    }
    
    // 如果没有更新，显示已是最新版本提示（仅在强制检查时显示）
    if (!info["hasUpdate"] && force) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (c) => AlertDialog(
          title: Text("检查更新"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("当前已是最新版本"),
              SizedBox(height: 10),
              Text("当前版本：${info["currentVersion"]} (build: ${info["currentBuild"]})"),
              Text("最新版本：${info["latestVersion"]} (build: ${info["latestBuild"]})"),
              SizedBox(height: 10),
              Container(
                constraints: BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text("最近更新：\n${info["updateLog"]}"),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                completer.complete();
              },
              child: Text("确定"),
            ),
          ],
        ),
      );
      return completer.future;
    }
    
    // 如果有更新，显示更新提示
    if (info["hasUpdate"]) {
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
                onPressed: () {
                  Navigator.pop(c);
                  completer.complete();
                },
                child: Text("稍后"),
              ),
            if (!forceUpdate)
              TextButton(
                onPressed: () async {
                  await recordDismissTime();
                  Navigator.pop(c);
                  completer.complete();
                },
                child: Text("3天内不提示"),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                completer.complete();
                openDownloadPage(info["downloadUrl"]);
              },
              child: Text("立即下载"),
            ),
          ],
        ),
      );
      return completer.future;
    }
    
    // 如果没有显示任何对话框，直接完成
    completer.complete();
    return completer.future;
  }
}