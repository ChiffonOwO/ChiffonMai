// 一次性的取歌名逻辑验证脚本，用 `dart run tool/maidata_title_test.dart` 执行。
// 刻意用 print 输出用例结果（这是脚本不是应用代码），所以整文件关掉 avoid_print。
// ignore_for_file: avoid_print

// 验证 MaidataDecodeUtil.quickExtractTitle 的取歌名行为。
//
// 这里**逐字符复刻**了 MaidataDecodeUtil.dart 里那段实现，包括那个
// `(.*)` 正则。之所以不用 import：库文件 import 了 flutter/material，
// 用 `dart run` 跑不起来（要 flutter test 环境），而这个项目没有 test/ 目录。
// 所以复刻 + 对照断言，改实现时两边要一起改。
import 'package:charset/charset.dart';

String? quickExtractTitle(String content) {
  final head = content.length > 1000 ? content.substring(0, 1000) : content;
  final match = RegExp(r'&title=(.*)', caseSensitive: false).firstMatch(head);
  final title = match?.group(1)?.trim();
  if (title != null && title.isNotEmpty) return title;

  // 回退分支这里简化成「整篇再找一次」，用途一致
  final m2 = RegExp(r'&title=(.*)', caseSensitive: false).firstMatch(content);
  final t2 = m2?.group(1)?.trim();
  return (t2 == null || t2.isEmpty) ? null : t2;
}

int _pass = 0, _fail = 0;
void check(String label, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
    print('  PASS  $label');
  } else {
    _fail++;
    print('  FAIL  $label${detail == null ? '' : '  → $detail'}');
  }
}

void main() {
  print('=== 1. 标准 maidata ===');
  check('日文歌名',
      quickExtractTitle('&title=テスト楽曲\n&artist=テスト\n&inote_5=(160){4}1,2\n') == 'テスト楽曲');
  check('中文歌名',
      quickExtractTitle('&title=千本桜\n&artist=黑うさP\n') == '千本桜');
  check('英文歌名',
      quickExtractTitle('&title=Grievous Lady\n') == 'Grievous Lady');

  print('\n=== 2. 大小写不敏感 ===');
  check('&TITLE=', quickExtractTitle('&TITLE=大文字\n') == '大文字');
  check('&Title=', quickExtractTitle('&Title=混合\n') == '混合');

  print('\n=== 3. CRLF 换行 ===');
  check('CRLF 行尾',
      quickExtractTitle('&title=CRLF曲\r\n&artist=x\r\n') == 'CRLF曲');

  print('\n=== 4. title 不在最前面 ===');
  check('前面有其他字段',
      quickExtractTitle('&artist=先に\n&genre=POPS\n&title=後ろの曲\n') == '後ろの曲');

  print('\n=== 5. 缺 title ===');
  check('完全没有 &title', quickExtractTitle('&artist=無し\n&inote_5=1,2\n') == null);
  check('&title= 空值', quickExtractTitle('&title=\n&artist=x\n') == null);
  check('&title=空白', quickExtractTitle('&title=   \n') == null);
  check('空内容', quickExtractTitle('') == null);

  print('\n=== 6. 歌名含特殊字符 ===');
  check('歌名含空格与斜杠',
      quickExtractTitle('&title=Re:MASTER / 改\n') == 'Re:MASTER / 改');
  check('歌名含全角括号',
      quickExtractTitle('&title=【宴】テスト\n') == '【宴】テスト');
  check('歌名含 = 号',
      quickExtractTitle('&title=A=B\n') == 'A=B');

  print('\n=== 7. 已知行为：&title=... 后还有内容时整行都被取作歌名 ===');
  final sameLine = quickExtractTitle('&title=曲名&artist=作者\n');
  print('    实际取到: "$sameLine"');
  check('整行取走（与 MaidataDecodeUtil 的 (.*) 行为一致）', sameLine == '曲名&artist=作者');
  // 说明：MaidataDecodeUtil.decode() 本身也按「一行一个 &key=value」解析，
  // 同一行塞两个 key 的非标准写法它同样认不出来，所以这里保持一致即可。

  print('\n=== 8. 歌名在 1000 字符之后（走回退分支）===');
  final padding = '&inote_5=(160){4}${'1,' * 600}\n';
  final late = '$padding&title=遅い曲\n';
  check('padding 长度确实超过 1000', padding.length > 1000, 'len=${padding.length}');
  check('回退后仍能取到', quickExtractTitle(late) == '遅い曲', '${quickExtractTitle(late)}');

  print('\n=== 9. 取第一个 title（重复 &title 时）===');
  check('取首个', quickExtractTitle('&title=一個目\n&title=二個目\n') == '一個目');

  print('\n=== 10. Shift-JIS 解码后的内容也能取到 ===');
  // "テスト" 的 Shift-JIS 字节。
  // 必须用 charset 包的 shiftJis.decode 真正解码——用 String.fromCharCodes
  // 是把每个字节当成一个码点（latin-1），得到的是乱码，测的就不是这条路径了。
  final sjisBytes = <int>[
    0x26, 0x74, 0x69, 0x74, 0x6C, 0x65, 0x3D, // &title=
    0x83, 0x65, 0x83, 0x58, 0x83, 0x67,       // テスト
    0x0A,
  ];
  final decoded = shiftJis.decode(sjisBytes);
  print('    解码结果: "$decoded"');
  check('按 Shift-JIS 解出的字符串可提取', quickExtractTitle(decoded) == 'テスト',
      '"${quickExtractTitle(decoded)}"');

  print('\n────────────────────────────');
  print('PASS: $_pass   FAIL: $_fail');
  if (_fail > 0) throw StateError('有 $_fail 项失败');
}
