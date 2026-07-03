import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entity/FavoriteFolder.dart';

/// 收藏夹服务：管理收藏夹的增删改查，数据持久化到 SharedPreferences
class FavoriteFolderService {
  static final FavoriteFolderService _instance = FavoriteFolderService._internal();
  factory FavoriteFolderService() => _instance;
  FavoriteFolderService._internal();

  static const String _storageKey = 'favorite_folders_data';

  List<FavoriteFolder> _folders = [];
  bool _loaded = false;

  /// 从本地加载所有收藏夹
  Future<List<FavoriteFolder>> loadFolders() async {
    if (_loaded) return List.unmodifiable(_folders);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
        _folders = jsonList
            .map((e) => FavoriteFolder.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _folders = [];
      }
      _loaded = true;
    } catch (e) {
      debugPrint('加载收藏夹数据失败: $e');
      _folders = [];
    }
    return List.unmodifiable(_folders);
  }

  /// 保存所有收藏夹到本地
  Future<void> _saveFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_folders.map((f) => f.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('保存收藏夹数据失败: $e');
    }
  }

  /// 获取所有收藏夹
  Future<List<FavoriteFolder>> getFolders() async {
    if (!_loaded) {
      await loadFolders();
    }
    return List.unmodifiable(_folders);
  }

  /// 根据ID获取收藏夹
  Future<FavoriteFolder?> getFolderById(String id) async {
    if (!_loaded) await loadFolders();
    try {
      return _folders.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 创建收藏夹
  Future<FavoriteFolder> createFolder(String name) async {
    if (!_loaded) await loadFolders();
    final folder = FavoriteFolder(name: name);
    _folders.add(folder);
    await _saveFolders();
    return folder;
  }

  /// 重命名收藏夹
  Future<bool> renameFolder(String id, String newName) async {
    if (!_loaded) await loadFolders();
    try {
      final folder = _folders.firstWhere((f) => f.id == id);
      folder.name = newName;
      folder.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await _saveFolders();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 删除收藏夹
  Future<bool> deleteFolder(String id) async {
    if (!_loaded) await loadFolders();
    final before = _folders.length;
    _folders.removeWhere((f) => f.id == id);
    if (_folders.length < before) {
      await _saveFolders();
      return true;
    }
    return false;
  }

  /// 向收藏夹中添加谱面
  /// [folderId] 收藏夹ID
  /// [chart] 要添加的谱面
  /// 返回 true 表示添加成功，false 表示该谱面已在收藏夹中
  Future<bool> addChartToFolder(String folderId, FavoriteChart chart) async {
    if (!_loaded) await loadFolders();
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      // 检查是否已存在
      final exists = folder.charts.any((c) => c.uniqueKey == chart.uniqueKey);
      if (exists) return false;
      folder.charts.add(chart);
      folder.updatedAt = DateTime.now().millisecondsSinceEpoch;
      await _saveFolders();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 从收藏夹中移除谱面
  Future<bool> removeChartFromFolder(String folderId, String uniqueKey) async {
    if (!_loaded) await loadFolders();
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final before = folder.charts.length;
      folder.charts.removeWhere((c) => c.uniqueKey == uniqueKey);
      if (folder.charts.length < before) {
        folder.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await _saveFolders();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 将谱面同时添加到多个收藏夹
  /// 返回成功添加到的收藏夹数量
  Future<int> addChartToMultipleFolders(
      List<String> folderIds, FavoriteChart chart) async {
    if (!_loaded) await loadFolders();
    int successCount = 0;
    for (final folderId in folderIds) {
      final added = await addChartToFolder(folderId, chart);
      if (added) successCount++;
    }
    return successCount;
  }

  /// 查找某个谱面存在于哪些收藏夹中
  /// 返回收藏夹ID列表
  Future<List<String>> findFoldersContainingChart(String uniqueKey) async {
    if (!_loaded) await loadFolders();
    final List<String> result = [];
    for (final folder in _folders) {
      final exists = folder.charts.any((c) => c.uniqueKey == uniqueKey);
      if (exists) {
        result.add(folder.id);
      }
    }
    return result;
  }

  /// 获取某个收藏夹中的所有谱面
  Future<List<FavoriteChart>> getChartsInFolder(String folderId) async {
    if (!_loaded) await loadFolders();
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      return List.unmodifiable(folder.charts);
    } catch (_) {
      return [];
    }
  }

  /// 批量从收藏夹中移除谱面
  /// 返回实际移除的数量
  Future<int> removeChartsFromFolder(
      String folderId, List<String> uniqueKeys) async {
    if (!_loaded) await loadFolders();
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final before = folder.charts.length;
      folder.charts.removeWhere((c) => uniqueKeys.contains(c.uniqueKey));
      final removed = before - folder.charts.length;
      if (removed > 0) {
        folder.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await _saveFolders();
      }
      return removed;
    } catch (_) {
      return 0;
    }
  }

  /// 批量将谱面从一个收藏夹移动到另一个
  /// 返回成功移动的数量
  Future<int> moveChartsBetweenFolders(
      String sourceId, String targetId, List<String> uniqueKeys) async {
    if (!_loaded) await loadFolders();
    if (sourceId == targetId) return 0;
    try {
      final source = _folders.firstWhere((f) => f.id == sourceId);
      final target = _folders.firstWhere((f) => f.id == targetId);
      int moved = 0;
      final chartsToMove = source.charts
          .where((c) => uniqueKeys.contains(c.uniqueKey))
          .toList();
      for (final chart in chartsToMove) {
        final exists = target.charts.any((c) => c.uniqueKey == chart.uniqueKey);
        if (!exists) {
          target.charts.add(chart);
          moved++;
        }
      }
      if (moved > 0) {
        source.charts.removeWhere((c) => uniqueKeys.contains(c.uniqueKey));
        source.updatedAt = DateTime.now().millisecondsSinceEpoch;
        target.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await _saveFolders();
      }
      return moved;
    } catch (_) {
      return 0;
    }
  }

  /// 更新收藏夹中谱面的成绩信息
  Future<void> updateChartAchievement(
      String folderId, String uniqueKey, double? achievement, int? playCount) async {
    if (!_loaded) await loadFolders();
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final idx = folder.charts.indexWhere((c) => c.uniqueKey == uniqueKey);
      if (idx >= 0) {
        folder.charts[idx] = folder.charts[idx].copyWith(
          achievement: achievement,
          playCount: playCount,
        );
        folder.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await _saveFolders();
      }
    } catch (_) {
      // 静默失败
    }
  }

  /// 对谱面列表排序
  List<FavoriteChart> sortCharts(
      List<FavoriteChart> charts, FavoriteSortOption sortBy) {
    final sorted = List<FavoriteChart>.from(charts);
    switch (sortBy) {
      case FavoriteSortOption.byDsDesc:
        sorted.sort((a, b) => b.ds.compareTo(a.ds));
        break;
      case FavoriteSortOption.byDsAsc:
        sorted.sort((a, b) => a.ds.compareTo(b.ds));
        break;
      case FavoriteSortOption.byDateNewest:
        sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case FavoriteSortOption.byDateOldest:
        sorted.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      case FavoriteSortOption.byTitle:
        sorted.sort((a, b) => a.songTitle
            .toLowerCase()
            .compareTo(b.songTitle.toLowerCase()));
        break;
    }
    return sorted;
  }

  /// 清除所有数据
  Future<void> clearAll() async {
    _folders = [];
    _loaded = true;
    await _saveFolders();
  }
}