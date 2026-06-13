import 'package:safe_text/safe_text.dart';

class CommentTextValidator {
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await SafeTextFilter.init(languages: [Language.chinese, Language.english]);
      _initialized = true;
    }
  }

  // 自定义词句库：精确匹配
  static const List<String> _customExactWords = [
    '吃分推荐',
    '神曲神谱',
  ];

  // 中文缩写脏话正则（独立词边界匹配，避免误伤如technique中的cnm）
  // (?<![a-zA-Z]) 前面不是字母，(?![a-zA-Z]) 后面不是字母，大小写不敏感
  static final RegExp _abbreviationBadWordRegex = RegExp(
    r'(?<![a-zA-Z])(cnm|nmsl|sb|tmd|nmd|wcnm|qnmd|qnmlgb|nmb|cnmb|nmlgb|wsnd|nmsles|nmslwsnd|csb|dsb|ssb|zz|shabi|sb玩意|ccb)(?![a-zA-Z])',
    caseSensitive: false,
  );

  // 自定义词句库：正则匹配（xx为任意内容）
  static final List<RegExp> _customPatterns = [
    RegExp(r'.+在哪'),
    RegExp(r'.+不在哪'),
  ];

  // 校验结果（异步）
  static Future<String?> validate(String text) async {
    await _ensureInitialized();

    if (text.trim().isEmpty) {
      return '内容不能为空';
    }

    // 1. 使用 safe_text 检查敏感词
    final hasBadWord = await SafeTextFilter.containsBadWord(text: text);
    if (hasBadWord) {
      return '内容包含不合规词句，请修改后重试';
    }

    // 2. 检查是否包含电话号码
    final hasPhone = await PhoneNumberChecker.containsPhoneNumber(text: text);
    if (hasPhone) {
      return '内容包含不合规词句，请修改后重试';
    }

    // 3. 中文缩写脏话校验（cnm等，独立词边界防误伤）
    if (_abbreviationBadWordRegex.hasMatch(text)) {
      return '内容包含不合规词句，请修改后重试';
    }

    // 4. 自定义词句库精确匹配
    for (final word in _customExactWords) {
      if (text.contains(word)) {
        return '内容包含不合规词句，请修改后重试';
      }
    }

    // 5. 自定义正则模式匹配
    for (final pattern in _customPatterns) {
      if (pattern.hasMatch(text)) {
        return '内容包含不合规词句，请修改后重试';
      }
    }

    return null;
  }
}