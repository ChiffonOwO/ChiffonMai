import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/utils/MaidataDecodeUtil.dart';

void main() {
  test('多行 inote 必须完整解析物量和四种 BREAK 绝赞', () {
    const content = '''
&title=解析测试
&shortid=12015
&lv_2=10.0
&inote_2=(180){1},
1,2,1b,2hb,3bx,4b[4:1],
E
''';

    final chart = MaidataDecodeUtil.decode(content).charts.single;

    expect(chart.stats?.tap, 2);
    expect(chart.stats?.breakNote, 4);
    expect(chart.breakStats?.trueZettaiTap, 1);
    expect(chart.breakStats?.trueZettaiHold, 1);
    expect(chart.breakStats?.protectedZettai, 1);
    expect(chart.breakStats?.star, 1);
  });
}
