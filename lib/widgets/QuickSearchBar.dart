import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/AppTheme.dart';

/// 首页功能搜索栏 — 置于功能中心白色区域内，用于筛选首页功能按钮
class QuickSearchBar extends StatefulWidget {
  /// 搜索文本变化回调
  final ValueChanged<String> onChanged;

  const QuickSearchBar({super.key, required this.onChanged});

  @override
  State<QuickSearchBar> createState() => _QuickSearchBarState();
}

class _QuickSearchBarState extends State<QuickSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      widget.onChanged(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final hintColor = AppColors.greyHint(brightness);
    final iconColor = AppColors.primaryText(brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.primaryText(brightness),
        ),
        decoration: InputDecoration(
          hintText: '搜索功能...',
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: iconColor, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: iconColor, size: 18),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark
              ? const Color.fromARGB(60, 255, 255, 255)
              : Colors.white.withValues(alpha: 0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: iconColor.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: iconColor.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: iconColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
      ),
    );
  }
}
