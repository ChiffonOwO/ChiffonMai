import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/page/HomePage.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/CollectionsManager.dart';
import 'package:my_first_flutter_app/manager/LuoXueSongsManager.dart';
import 'package:my_first_flutter_app/manager/KnowledgeManager.dart';
import 'package:my_first_flutter_app/service/RecommendByTagsService.dart';
import 'package:my_first_flutter_app/constant/LoadingTipsConstant.dart';

// 程序入口：运行Flutter应用，根组件为MyApp
void main() {
  runApp(
    MyApp()
  );
}

/// 应用根组件：有状态组件，配置MaterialApp基础属性并管理初始化
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 初始化歌曲别名管理器
      await SongAliasManager.instance.init();
      // 从API获取并更新音乐数据
      await MaimaiMusicDataManager().fetchAndUpdateMusicData();
      // 从API获取并更新难度数据
      await DiffMusicDataManager().fetchAndUpdateDiffData();
      // 初始化标签数据
      await RecommendByTagsService.initializeTags();
      // 初始化收藏品数据
      final collectionsManager = CollectionsManager();
      await collectionsManager.fetchTrophiesCollections();
      await collectionsManager.fetchIconsCollections();
      await collectionsManager.fetchPlatesCollections();
      await collectionsManager.fetchFramesCollections();

      // 初始化落雪歌曲数据
      final luoXueSongsManager = LuoXueSongsManager();
      await luoXueSongsManager.getLuoXueSongs();
      // 建立落雪歌曲与缓存歌曲的映射
      final maimaiMusicManager = MaimaiMusicDataManager();
      if (await maimaiMusicManager.hasCachedData()) {
        final cachedSongs = await maimaiMusicManager.getCachedSongs();
        luoXueSongsManager.mapLuoXueSongsToCachedSongs(cachedSongs ?? []);
      }

      // 初始化知识数据
      await KnowledgeManager().getKnowledgeData();
    } catch (e) {
      print('初始化失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // 允许系统处理返回手势
      onPopInvoked: (didPop) {
        // 处理返回手势
        if (didPop) {
          // 可以在这里添加额外的返回处理逻辑
          // 例如清理资源、保存状态等
        }
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false, // 隐藏右上角调试横幅
        home: _isInitialized ? const HomePage() : _buildLoadingScreen(), // 应用首页为HomePage组件
        theme: ThemeData(
          // 全局默认字体
          fontFamily: "Source Han Sans",
          textTheme: TextTheme(
            bodyLarge: TextStyle(fontFamily: "Source Han Sans"),
            bodyMedium: TextStyle(fontFamily: "Source Han Sans"),
            bodySmall: TextStyle(fontFamily: "Source Han Sans"),
            displayLarge: TextStyle(fontFamily: "Source Han Sans"),
            displayMedium: TextStyle(fontFamily: "Source Han Sans"),
            displaySmall: TextStyle(fontFamily: "Source Han Sans"),
            headlineLarge: TextStyle(fontFamily: "Source Han Sans"),
            headlineMedium: TextStyle(fontFamily: "Source Han Sans"),
            headlineSmall: TextStyle(fontFamily: "Source Han Sans"),
            titleLarge: TextStyle(fontFamily: "Source Han Sans"),
            titleMedium: TextStyle(fontFamily: "Source Han Sans"),
            titleSmall: TextStyle(fontFamily: "Source Han Sans"),
          ),
        ),

        builder: (context, child) {
          // 强制文字不跟随系统缩放
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child!,
          );
        },
      ),
    );
  }

  // 构建加载屏幕
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('初始化各项数据中,请稍等(^ ^)...'),
            SizedBox(height: 10),
            Text(LoadingTipsConstant.getRandomLoadingTip()),
          ],
        ),
      ),
    );
  }
}