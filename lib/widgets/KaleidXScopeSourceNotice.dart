import 'package:flutter/material.dart';
import '../utils/ExternalLaunchUtil.dart';

/// KALEIDXSCOPE 门页统一的数据来源说明。
class KaleidXScopeSourceNotice extends StatelessWidget
    implements PreferredSizeWidget {
  static final Uri sourceUri =
      Uri.parse('https://kaleidxscope.awmc.team/index.html');

  const KaleidXScopeSourceNotice({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(30);

  Future<void> _openSource(BuildContext context) async {
    final opened = await ExternalLaunchUtil.open(sourceUri);
    if (!opened && context.mounted) {
      await ExternalLaunchUtil.copyFallback(context, sourceUri.toString(),
          message: '无法打开攻略来源，链接已复制到剪贴板');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: preferredSize.height,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openSource(context),
            borderRadius: BorderRadius.circular(7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: color),
                const SizedBox(width: 5),
                Text(
                  '数据来源：AWMC KALEIDXSCOPE',
                  style: TextStyle(fontSize: 11, color: color),
                ),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new, size: 12, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
