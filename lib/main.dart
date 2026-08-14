import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_first_flutter_app/page/HomePage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/ThemeManager.dart';
import 'package:my_first_flutter_app/service/ConnectivityService.dart';
import 'package:my_first_flutter_app/utils/SwipeBackDetector.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(MyApp());
}

/// 应用根组件：有状态组件，配置MaterialApp基础属性并管理初始化
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _fontsLoaded = false;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _initTheme();
    ConnectivityService().start();
  }

  Future<void> _initTheme() async {
    await ThemeManager().loadThemePreference();
    // 预加载背景图片到图像缓存，避免首帧缺失导致闪烁
    await _precacheBackgroundImages();
    if (mounted) {
      setState(() => _themeLoaded = true);
    }
  }

  /// 预加载全屏背景图片到 Flutter 图像缓存
  Future<void> _precacheBackgroundImages() async {
    try {
      await Future.wait([
        precacheImage(const AssetImage('assets/background.png'), context),
        precacheImage(const AssetImage('assets/chiffon2.png'), context),
      ]);
    } catch (e) {
      debugPrint('预加载背景图片失败: $e');
    }
  }

  void _loadFonts() {
    if (!_fontsLoaded) {
      setState(() {
        _fontsLoaded = true;
      });
      debugPrint('📦 开始加载网络字体...');
    }
  }

  /// 构建包含字体配置的 ThemeData
  ThemeData _buildThemeWithFonts(ThemeData base) {
    if (!_fontsLoaded) return base;
    return base.copyWith(
      textTheme: GoogleFonts.notoSansScTextTheme(
        base.textTheme,
      ),
      primaryTextTheme: GoogleFonts.notoSansScTextTheme(
        base.primaryTextTheme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([ThemeManager().notifier, ThemeManager().pureBlackNotifier]),
      builder: (context, _) {
        final themeMode = ThemeManager().themeMode;
        final pureBlack = ThemeManager().pureBlackEnabled;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          home: HomePage(onFirstFrameRendered: _loadFonts),
          theme: _buildThemeWithFonts(AppTheme.lightTheme()),
          darkTheme: _buildThemeWithFonts(
            pureBlack ? AppTheme.pureBlackTheme() : AppTheme.darkTheme(),
          ),
          themeMode: themeMode,
          builder: (context, child) {
            return SwipeBackDetector(
              navigatorKey: _navigatorKey,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                child: DefaultTextStyle(
                  style: _fontsLoaded
                      ? GoogleFonts.notoSansSc()
                      : const TextStyle(),
                  child: child!,
                ),
              ),
            );
          },
        );
      },
    );
  }
}