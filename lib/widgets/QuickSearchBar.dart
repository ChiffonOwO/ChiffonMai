import 'dart:async';
import 'package:flutter/material.dart';

/// 功能搜索栏，可在首页或功能分类页复用。
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
    // 立即刷新清除按钮，实际筛选仍按短防抖后的值触发。
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      widget.onChanged(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hintColor = scheme.onSurfaceVariant;
    final iconColor = scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: TextStyle(
          fontSize: 14,
          color: scheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: '搜索功能...',
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: iconColor, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: iconColor, size: 18),
                  onPressed: () {
                    _debounceTimer?.cancel();
                    _controller.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: scheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: iconColor, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
      ),
    );
  }
}
