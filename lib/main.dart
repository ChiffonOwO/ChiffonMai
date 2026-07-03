import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_first_flutter_app/page/HomePage.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/ThemeManager.dart';
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
    if (mounted) {
      setState(() => _themeLoaded = true);
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager().notifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HomePage(onFirstFrameRendered: _loadFonts),
          theme: _buildThemeWithFonts(AppTheme.lightTheme()),
          darkTheme: _buildThemeWithFonts(AppTheme.darkTheme()),
          themeMode: themeMode,
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
  }
}