import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/DivingFish/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/LZYCheckUpdateManager.dart';
import 'package:my_first_flutter_app/manager/LuoXue/CollectionsManager.dart';
import 'package:my_first_flutter_app/manager/LuoXue/LuoXueSongsManager.dart';
import 'package:my_first_flutter_app/manager/KnowledgeManager.dart';
import 'package:my_first_flutter_app/manager/MaidataManager.dart';
import 'package:my_first_flutter_app/service/RecommendByTagsService.dart';
import 'package:my_first_flutter_app/service/ConnectivityService.dart';

/// 首页服务类：处理首页相关的数据初始化和业务逻辑
class HomeService {
  static final HomeService _instance = HomeService._internal();
  
  factory HomeService() => _instance;
  
  HomeService._internal();
  
  /// 检查更新
  Future<Map<String, dynamic>?> checkUpdate() async {
    debugPrint("首页加载时自动检查更新");
    final updateManager = LZYCheckUpdateManager();
    try {
      if (await updateManager.shouldShowUpdateDialog()) {
        var updateInfo = await updateManager.checkUpdate();
        if (updateInfo['hasUpdate']) {
          return updateInfo;
        }
      }
    } catch (e) {
      debugPrint("自动检查更新失败：$e");
    }
    return null;
  }
  
  /// 后台初始化所有数据
  /// [onProgress] 进度回调函数，参数为进度消息
  Future<HomeInitResult> initializeDataInBackground({
    required Function(String) onProgress,
  }) async {
    final startTime = DateTime.now();

    // 检查网络连接
    final isOnline = await ConnectivityService().hasConnection();
    if (!isOnline) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('离线模式：跳过后台数据初始化，使用缓存数据');
      return HomeInitResult(
        success: true,
        duration: duration,
        durationStr: '${duration.inMilliseconds}ms（离线模式）',
      );
    }

    try {
      // 第一阶段：初始化基础管理器（必须串行）
      onProgress('正在加载歌曲别名数据库...');
      await SongAliasManager.instance.init();
      
      onProgress('正在初始化Maidata管理器...');
      final maidataManager = MaidataManager();
      await maidataManager.initialize();
      
      // 如果缓存未就绪或过期，获取全量maidata
      if (!maidataManager.isCacheReady) {
        debugPrint('Maidata缓存未就绪，开始获取全量maidata...');
        onProgress('正在获取全量Maidata数据...\n（首次加载可能较慢，请耐心等待）');
        await maidataManager.fetchAndCacheFullMaidata();
      } else {
        onProgress('从缓存加载Maidata数据...');
      }
      
      // 获取maidata文本列表用于追加
      List<String> maidataTexts = maidataManager.getAllMaidataTexts();
      debugPrint('已获取 ${maidataTexts.length} 首歌曲的maidata');
      
      // 第二阶段：并行获取音乐数据和难度数据
      onProgress('正在同步歌曲信息与难度数据...');
      final maimaiMusicManager = MaimaiMusicDataManager();
      final diffMusicManager = DiffMusicDataManager();
      
      await Future.wait([
        maimaiMusicManager.fetchAndUpdateMusicData(maidataTexts: maidataTexts),
        diffMusicManager.fetchAndUpdateDiffData(),
      ]);
      
      // 第三阶段：并行初始化其他数据
      onProgress('正在加载收藏品数据...');
      final collectionsManager = CollectionsManager();
      final luoXueSongsManager = LuoXueSongsManager();
      
      await Future.wait([
        collectionsManager.fetchTrophiesCollections(),
        collectionsManager.fetchIconsCollections(),
        collectionsManager.fetchPlatesCollections(),
        collectionsManager.fetchFramesCollections(),
      ]);
      
      onProgress('正在构建智能推荐标签系统...');
      await RecommendByTagsService.initializeTags();
      
      onProgress('正在加载落雪歌曲数据...');
      await luoXueSongsManager.getLuoXueSongs();
      
      onProgress('正在加载知识库数据...');
      await KnowledgeManager().getKnowledgeData();
      
      // 建立落雪歌曲与缓存歌曲的映射
      onProgress('正在建立歌曲关联映射...');
      if (await maimaiMusicManager.hasCachedData()) {
        final cachedSongs = await maimaiMusicManager.getCachedSongs();
        luoXueSongsManager.mapLuoXueSongsToCachedSongs(cachedSongs ?? []);
      }
      
      // 计算耗时
      final duration = DateTime.now().difference(startTime);
      final durationStr = '${duration.inSeconds}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}秒';
      
      debugPrint('✅ 所有数据初始化完成，用时$durationStr');
      
      return HomeInitResult(
        success: true,
        duration: duration,
        durationStr: durationStr,
        errorMessage: null,
      );
      
    } catch (e) {
      debugPrint('❌ 后台初始化失败: $e');
      return HomeInitResult(
        success: false,
        duration: DateTime.now().difference(startTime),
        durationStr: '',
        errorMessage: e.toString(),
      );
    }
  }
}

/// 首页初始化结果
class HomeInitResult {
  final bool success;
  final Duration duration;
  final String durationStr;
  final String? errorMessage;
  
  HomeInitResult({
    required this.success,
    required this.duration,
    required this.durationStr,
    this.errorMessage,
  });
}