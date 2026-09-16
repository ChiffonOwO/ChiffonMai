import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_first_flutter_app/page/AppShell.dart';
import 'package:my_first_flutter_app/page/SplashPage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/ExportSettings.dart';
import 'package:my_first_flutter_app/utils/FavoriteFeaturesNotifier.dart';
import 'package:my_first_flutter_app/utils/FavoriteImportFlow.dart';
import 'package:my_first_flutter_app/utils/LoginStateNotifier.dart';
import 'package:my_first_flutter_app/utils/PlayerThemeScope.dart';
import 'package:my_first_flutter_app/utils/ThemeManager.dart';
import 'package:my_first_flutter_app/utils/UserProfileNotifier.dart';
import 'package:my_first_flutter_app/service/ConnectivityService.dart';

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

  /// 收藏夹「一键导入」通道，与 MainActivity.kt 中的 IMPORT_CHANNEL 对应
  static const MethodChannel _openFileChannel =
      MethodChannel('com.example.app/open_file');

  /// 正在处理导入（避免冷启动时 pending + 实时推送把同一个文件导两次）
  bool _handlingIncoming = false;
  String? _lastHandledPath;

  @override
  void initState() {
    super.initState();
    _initTheme();
    ConnectivityService().start();
    // 应用启动时一次性加载跨页面共享状态，
    // 保证首页 / 4 个 Hub 页 / 收藏管理页能立刻读到收藏列表、登录态与个人信息。
    FavoriteFeaturesNotifier.load();
    LoginStateNotifier.load();
    UserProfileNotifier.load();
    // 导出相关偏好（收藏夹自定义后缀）
    ExportSettings.load();
    _initFileOpenHandling();
  }

  /// 注册「文件管理器点开收藏夹文件」的处理。
  ///
  /// 两条来源都会汇到 [_handleIncomingFile]：
  ///   1. 冷启动：App 没在跑，MainActivity 把路径暂存，这里主动取走；
  ///   2. 热启动：App 已在后台，MainActivity 通过 onFileOpened 直接推过来。
  Future<void> _initFileOpenHandling() async {
    _openFileChannel.setMethodCallHandler((call) async {
      if (call.method == 'onFileOpened') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          await _handleIncomingFile(path);
        }
      }
      return null;
    });

    try {
      final initial =
          await _openFileChannel.invokeMethod<String>('getInitialImportPath');
      if (initial != null && initial.isNotEmpty) {
        await _handleIncomingFile(initial);
      }
    } on MissingPluginException {
      // 非 Android 平台没有这个通道，正常忽略
    } catch (e) {
      debugPrint('[open_file] 读取启动导入文件失败: $e');
    }
  }

  /// 等到 Navigator 的 Overlay 就绪，并返回它的 context。
  ///
  /// 这里刻意不用 `navigatorKey.currentContext`：那是 Navigator 自己的 context，
  /// 而 `Navigator.of` / `showDialog` 都是从**祖先**里找 NavigatorState，
  /// 拿它当 context 会找不到 Navigator。Overlay 的 context 位于 Navigator 之下，
  /// 是弹窗和导航都能正常工作的安全选择。
  Future<BuildContext?> _awaitNavigatorContext() async {
    for (var i = 0; i < 30; i++) {
      final ctx = _navigatorKey.currentState?.overlay?.context;
      if (ctx != null && ctx.mounted) return ctx;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<void> _handleIncomingFile(String path) async {
    if (_handlingIncoming || path == _lastHandledPath) return;
    _handlingIncoming = true;
    _lastHandledPath = path;

    try {
      final ctx = await _awaitNavigatorContext();
      if (ctx == null || !ctx.mounted) {
        debugPrint('[open_file] 界面还没准备好，忽略导入: $path');
        return;
      }
      await runFavoriteImportFlow(ctx, presetPath: path);
    } catch (e) {
      debugPrint('[open_file] 处理导入文件失败: $e');
    } finally {
      _handlingIncoming = false;
    }
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
      setState(() => _fontsLoaded = true);
    }
  }

  ThemeData _buildThemeWithFonts(ThemeData base) {
    if (!_fontsLoaded) return base;
    return base.copyWith(
      textTheme: GoogleFonts.notoSansScTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.notoSansScTextTheme(base.primaryTextTheme),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        home: const SplashPage(),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeManager().notifier,
        ThemeManager().pureBlackNotifier,
        ThemeManager().seedColorNotifier,
        ThemeManager().customBackgroundPathNotifier,
      ]),
      builder: (context, _) {
        final themeMode = ThemeManager().themeMode;
        final pureBlack = ThemeManager().pureBlackEnabled;
        final seedColor = ThemeManager().seedColor;
        final lightThemeData =
            _buildThemeWithFonts(AppTheme.lightTheme(seedColor: seedColor));
        final darkThemeData = _buildThemeWithFonts(
          pureBlack
              ? AppTheme.pureBlackTheme(seedColor: seedColor)
              : AppTheme.darkTheme(seedColor: seedColor),
        );
        // 播放页存活期间，在 MaterialApp 层强制深色主题（详见 PlayerThemeScope）。
        // 必须在 theme/themeMode 上强制，而不是在 builder 里包一层 Theme：
        // simai_flutter 的游玩/导出页没有自己的背景色，浅色主题下会透出后面全黑的
        // 播放器，出现「黑底 + 深色文字」看不清的情况。
        return ValueListenableBuilder<bool>(
          valueListenable: PlayerThemeScope.forceDarkTheme,
          builder: (context, forceDark, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: _navigatorKey,
              home: AppShell(onFirstFrameRendered: _loadFonts),
              theme: forceDark ? darkThemeData : lightThemeData,
              darkTheme: darkThemeData,
              themeMode: forceDark ? ThemeMode.dark : themeMode,
              // 强制深色时立即切换，避免主题渐变在播放器页面上再闪一下
              themeAnimationDuration:
                  forceDark ? Duration.zero : kThemeAnimationDuration,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                  child: DefaultTextStyle(
                    style: _fontsLoaded
                        ? GoogleFonts.notoSansSc()
                        : const TextStyle(),
                    child: child!,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
