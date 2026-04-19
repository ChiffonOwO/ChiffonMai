import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/page/HomePage.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/CollectionsManager.dart';
import 'package:my_first_flutter_app/manager/LuoXueSongsManager.dart';
import 'package:my_first_flutter_app/service/RecommendByTagsService.dart';

// 程序入口：运行Flutter应用，根组件为MyApp
Future<void> main() async {
  runApp(const MyApp());
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
}

/// 应用根组件：无状态组件，配置MaterialApp基础属性
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 隐藏右上角调试横幅
      home: const HomePage(), // 应用首页为HomePage组件
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
    );
  }
}
