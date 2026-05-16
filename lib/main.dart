import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_first_flutter_app/page/HomePage.dart';
import 'package:my_first_flutter_app/manager/SongAliasManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/DiffMusicDataManager.dart';
import 'package:my_first_flutter_app/manager/CollectionsManager.dart';
import 'package:my_first_flutter_app/manager/LuoXueSongsManager.dart';
import 'package:my_first_flutter_app/manager/KnowledgeManager.dart';
import 'package:my_first_flutter_app/manager/MaidataManager.dart';
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
  String _currentLoadingTip = '';

  @override
  void initState() {
    super.initState();
    _initializeLoadingTip();
    _initializeApp();
  }

  void _initializeLoadingTip() {
    // 立即设置第一条提示，避免初始空白
    setState(() {
      _currentLoadingTip = LoadingTipsConstant.getRandomLoadingTip();
    });
    LoadingTipsConstant.startAutoSwitch();
    LoadingTipsConstant.tipStream.listen((newTip) {
      if (mounted) {
        setState(() {
          _currentLoadingTip = newTip;
        });
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      // 初始化歌曲别名管理器
      await SongAliasManager.instance.init();
      
      // 初始化并获取全量maidata缓存
      final maidataManager = MaidataManager();
      await maidataManager.initialize();
      
      // 如果缓存未就绪或过期，获取全量maidata
      if (!maidataManager.isCacheReady) {
        debugPrint('Maidata缓存未就绪，开始获取全量maidata...');
        await maidataManager.fetchAndCacheFullMaidata();
      }
      
      // 获取maidata文本列表用于追加
      List<String> maidataTexts = maidataManager.getAllMaidataTexts();
      debugPrint('已获取 ${maidataTexts.length} 首歌曲的maidata');
      
      // 从API获取并更新音乐数据（包含maidata追加）
      await MaimaiMusicDataManager().fetchAndUpdateMusicData(maidataTexts: maidataTexts);
      
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
      debugPrint('初始化失败: $e');
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
          // 全局默认字体：使用 Google Fonts 的 Noto Sans SC（思源黑体替代）
          fontFamily: GoogleFonts.notoSansSc(fontWeight: FontWeight.w400).fontFamily,
          textTheme: TextTheme(
            // 大标题 - 粗体 (w700)
            displayLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            displayMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            displaySmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            headlineLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            headlineMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            headlineSmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            // 标题 - 半粗体 (w600)
            titleLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
            titleMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
            titleSmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
            // 正文 - 常规 (w400)
            bodyLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w400),
            bodyMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w400),
            bodySmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w400),
            // 标签
            labelLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
            labelMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
            labelSmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
          ),
          primaryTextTheme: TextTheme(
            displayLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            displayMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            displaySmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            headlineLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            headlineMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            headlineSmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w700),
            titleLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
            titleMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
            titleSmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
            bodyLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w400),
            bodyMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w400),
            bodySmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w400),
            labelLarge: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600),
            labelMedium: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
            labelSmall: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
          ),
        ),

        builder: (context, child) {
          // 强制文字不跟随系统缩放，并设置全局默认字体
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: DefaultTextStyle(
              style: GoogleFonts.notoSansSc(),
              child: child!,
            ),
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
            Text(_currentLoadingTip),
          ],
        ),
      ),
    );
  }
}