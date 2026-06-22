import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_first_flutter_app/page/HomePage.dart';

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

  @override
  void initState() {
    super.initState();
  }

  void _loadFonts() {
    if (!_fontsLoaded) {
      setState(() {
        _fontsLoaded = true;
      });
      debugPrint('📦 开始加载网络字体...');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(onFirstFrameRendered: _loadFonts),
      theme: ThemeData(
          fontFamily: _fontsLoaded 
              ? GoogleFonts.notoSansSc(fontWeight: FontWeight.w400).fontFamily 
              : null,
          textTheme: _fontsLoaded ? TextTheme(
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
          ) : null,
          primaryTextTheme: _fontsLoaded ? TextTheme(
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
          ) : null,
        ),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: DefaultTextStyle(
              style: _fontsLoaded ? GoogleFonts.notoSansSc() : const TextStyle(),
              child: child!,
            ),
          );
        },
    );
  }
}