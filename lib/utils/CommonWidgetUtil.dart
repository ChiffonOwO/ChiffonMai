import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';
import 'package:my_first_flutter_app/utils/AppTheme.dart';
import 'package:my_first_flutter_app/utils/ThemeManager.dart';

/**
 * 通用Widget工具类
 * 所有背景、标题、按钮组件均已支持暗色模式自动切换
 */
class CommonWidgetUtil {
  /**
   * 构建通用背景Widget（主题感知 — 暗色模式自动变暗）
   * 层级1：基础背景图 - 占满整个屏幕
   */
  static Widget buildCommonBgWidget() {
    return const _ThemeAwareBgWidget();
  }

  /**
   * 构建通用装饰背景Widget（主题感知 — 暗色模式降低透明度并变暗）
   * 层级2：chiffon 装饰图 - 居中显示，轻微向上偏移
   */
  static Widget buildCommonChiffonBgWidget(BuildContext context) {
    return _ThemeAwareChiffonWidget();
  }

  /**
   * 构建通用标题Widget（主题感知）
   */
  static Widget buildCommonTitleWidget(String title) {
    return _ThemeAwareTitleWidget(title: title);
  }

  /**
   * 构建通用返回按钮Widget（主题感知）
   */
  static Widget buildCommonBackButtonWidget(BuildContext context) {
    return _ThemeAwareBackButtonWidget();
  }

  /**
   * 构建猜歌通用设置Widget
   */
  static Widget buildGuessChartSettingsWidget(
    BuildContext context,
    List<String> allVersions,
    List<String> allGenres,
    List<String> selectedVersions,
    double masterMinDx,
    double masterMaxDx,
    List<String> selectedGenres,
    int maxGuesses,
    int timeLimit,
    Function(List<String>) onVersionsChanged,
    Function(double, double) onMasterDxRangeChanged,
    Function(List<String>) onGenresChanged,
    Function(int) onMaxGuessesChanged,
    Function(int) onTimeLimitChanged,
    Function() onReset,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('选择版本（支持复选，默认全部，不选表示所有）'),
          _buildMultiSelectList(
            context,
            allVersions,
            selectedVersions,
            onVersionsChanged,
            (version) => StringUtil.formatVersion2(version),
          ),
          SizedBox(height: 20),
          _buildSectionTitle('MASTER定数范围'),
          _buildMasterDxRangeInput(
            context,
            masterMinDx,
            masterMaxDx,
            onMasterDxRangeChanged,
          ),
          SizedBox(height: 20),
          _buildSectionTitle('选择流派（支持复选，默认全部，不选表示所有）'),
          _buildMultiSelectList(
            context,
            allGenres.where((genre) => genre != '宴会場').toList(),
            selectedGenres.where((genre) => genre != '宴会場').toList(),
            onGenresChanged,
            null,
          ),
          SizedBox(height: 20),
          _buildSectionTitle('最大猜测次数（拉到最右侧为无限制）'),
          _buildSlider(
            value: maxGuesses == 0 ? 20.0 : maxGuesses.toDouble(),
            min: 1,
            max: 20,
            divisions: 20,
            label: maxGuesses == 0 || maxGuesses == 20 ? '无限制' : '$maxGuesses',
            onChanged: (value) {
              onMaxGuessesChanged(value.toInt() == 20 ? 0 : value.toInt());
            },
          ),
          SizedBox(height: 20),
          _buildSectionTitle('时间限制（拉到最右侧为无限制）'),
          _buildSlider(
            value: timeLimit == 0 ? 180.0 : timeLimit.toDouble(),
            min: 30,
            max: 180,
            divisions: 15,
            label: timeLimit == 0 || timeLimit == 180 ? '无限制' : '$timeLimit秒',
            onChanged: (value) {
              int selectedValue = value.toInt();
              int roundedValue = (selectedValue / 10).round() * 10;
              roundedValue = roundedValue.clamp(30, 180);
              onTimeLimitChanged(roundedValue == 180 ? 0 : roundedValue);
            },
          ),
        ],
      ),
    );
  }

  // ========== 以下为猜歌设置的辅助组件 ==========

  static Widget _buildSectionTitle(String title) {
    return _ThemeAwareSectionTitle(title: title);
  }

  static Widget _buildMultiSelectList(
    BuildContext context,
    List<String> items,
    List<String> selectedItems,
    Function(List<String>) onChanged,
    String Function(String)? formatter,
  ) {
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.tableBorder(brightness)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, index) {
          String item = items[index];
          bool isSelected = selectedItems.contains(item);
          String displayText = formatter != null ? formatter(item) : item;
          return CheckboxListTile(
            title: Text(displayText),
            value: isSelected,
            onChanged: (value) {
              List<String> newSelected = List.from(selectedItems);
              if (value!) {
                if (!newSelected.contains(item)) {
                  newSelected.add(item);
                }
              } else {
                newSelected.remove(item);
              }
              onChanged(newSelected);
            },
          );
        },
      ),
    );
  }

  static Widget _buildMasterDxRangeInput(
    BuildContext context,
    double minValue,
    double maxValue,
    Function(double, double) onChanged,
  ) {
    final brightness = Theme.of(context).brightness;
    double formattedMin = double.parse(minValue.toStringAsFixed(1));
    double formattedMax = double.parse(maxValue.toStringAsFixed(1));
    TextEditingController minController = TextEditingController(text: formattedMin.toString());
    TextEditingController maxController = TextEditingController(text: formattedMax.toString());

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最小:'),
                  TextField(
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    controller: minController,
                    onEditingComplete: () {
                      String value = minController.text;
                      if (value.isEmpty) { onChanged(1.0, maxValue); }
                      else { double? newMin = double.tryParse(value); if (newMin != null && newMin >= 1.0 && newMin <= 15.0) { onChanged(newMin, maxValue); } }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最大:'),
                  TextField(
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    controller: maxController,
                    onEditingComplete: () {
                      String value = maxController.text;
                      if (value.isEmpty) { onChanged(minValue, 15.0); }
                      else { double? newMax = double.tryParse(value); if (newMax != null && newMax >= 1.0 && newMax <= 15.0) { onChanged(minValue, newMax); } }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text('范围：1.0 - 15.0', style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness))),
        SizedBox(height: 4),
        Text('输入完毕后请点击输入法的回车键', style: TextStyle(fontSize: 12, color: AppColors.greyHint(brightness))),
      ],
    );
  }

  static Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required Function(double) onChanged,
  }) {
    return Column(
      children: [
        Slider(value: value, min: min, max: max, divisions: divisions, label: label, onChanged: onChanged),
        Text(label),
      ],
    );
  }

  // prevent instantiation
  CommonWidgetUtil._();
}

// ============ 内部主题感知组件 ============

/// 主题感知的背景图组件（StatelessWidget）
/// 性能：用 Stack + 半透明覆层代替 ColorFiltered + BlendMode.darken，避免 saveLayer
/// - 浅色模式：白色半透明覆层使背景图变成若隐若现的纹理（不透明度用户可调）
/// - 深色模式：深色半透明覆层压暗背景图
/// - 纯黑模式：隐藏背景图，显示纯黑底色
class _ThemeAwareBgWidget extends StatelessWidget {
  const _ThemeAwareBgWidget();

  @override
  Widget build(BuildContext context) {
    // 用 ListenableBuilder 包裹，仅在覆层透明度变化时局部重建
    return ListenableBuilder(
      listenable: ThemeManager().lightOverlayNotifier,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isPureBlack = isDark && ThemeManager().pureBlackEnabled;
        final opacity = ThemeManager().lightOverlayOpacity;
        final overlayAlpha = (opacity * 255).round().clamp(0, 255);
        final lightOverlay = Color.fromARGB(overlayAlpha, 255, 255, 255);
        final darkOverlay = Color.fromARGB(overlayAlpha, 15, 15, 28);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 纯黑模式：不加载背景图，只放纯黑底色
            if (isPureBlack)
              const Positioned.fill(child: ColoredBox(color: Colors.black))
            else ...[
              Image.asset(
                'assets/background.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
              // 浅色/深色均添加覆层：浅色用白色洗淡，深色用暗色压暗
              if (isDark)
                Positioned.fill(child: ColoredBox(color: darkOverlay))
              else
                Positioned.fill(child: ColoredBox(color: lightOverlay)),
            ],
          ],
        );
      },
    );
  }
}

/// 主题感知的 chiffon 装饰组件（StatelessWidget）
/// 性能：用 Stack + 半透明覆层代替 ColorFiltered + BlendMode.darken，避免 saveLayer
/// - 浅色模式：降低透明度，让装饰层更含蓄
/// - 深色模式：大幅降低透明度并叠加暗色覆层
/// - 纯黑模式：完全隐藏装饰层
class _ThemeAwareChiffonWidget extends StatelessWidget {
  const _ThemeAwareChiffonWidget({super.key});

  static const double _darkOpacity = 0.35;
  static const double _lightOpacity = 0.40;

  @override
  Widget build(BuildContext context) {
    // 用 ListenableBuilder 包裹，仅在覆层透明度变化时局部重建
    return ListenableBuilder(
      listenable: ThemeManager().lightOverlayNotifier,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isPureBlack = isDark && ThemeManager().pureBlackEnabled;
        final opacity = ThemeManager().lightOverlayOpacity;
        final overlayAlpha = (opacity * 255).round().clamp(0, 255);
        final darkOverlay = Color.fromARGB(overlayAlpha, 10, 10, 25);

        // 纯黑模式：不显示装饰图
        if (isPureBlack) {
          return const SizedBox.shrink();
        }

        return Center(
          child: Transform.translate(
            offset: Offset(0, -MediaQuery.of(context).size.height * 0.03),
            child: Transform.scale(
              scale: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/chiffon2.png',
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    opacity: AlwaysStoppedAnimation(
                      isDark ? _darkOpacity : _lightOpacity,
                    ),
                  ),
                  if (isDark)
                    Positioned.fill(child: ColoredBox(color: darkOverlay)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 主题感知的标题组件
class _ThemeAwareTitleWidget extends StatefulWidget {
  final String title;
  const _ThemeAwareTitleWidget({required this.title});

  @override
  State<_ThemeAwareTitleWidget> createState() => _ThemeAwareTitleWidgetState();
}

class _ThemeAwareTitleWidgetState extends State<_ThemeAwareTitleWidget> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textColor = AppColors.primaryText(brightness);
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          widget.title,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

/// 主题感知的返回按钮组件
class _ThemeAwareBackButtonWidget extends StatefulWidget {
  const _ThemeAwareBackButtonWidget({super.key});

  @override
  State<_ThemeAwareBackButtonWidget> createState() => _ThemeAwareBackButtonWidgetState();
}

class _ThemeAwareBackButtonWidgetState extends State<_ThemeAwareBackButtonWidget> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final iconColor = AppColors.primaryText(brightness);
    return Positioned(
      top: 40,
      left: 10,
      child: GestureDetector(
        onTap: () {
          debugPrint('返回按钮被点击');
          Navigator.pop(context);
        },
        child: Container(
          padding: EdgeInsets.all(16),
          color: Colors.transparent,
          child: Icon(Icons.arrow_back, color: iconColor, size: 24),
        ),
      ),
    );
  }
}

/// 主题感知的章节标题
class _ThemeAwareSectionTitle extends StatefulWidget {
  final String title;
  const _ThemeAwareSectionTitle({required this.title});

  @override
  State<_ThemeAwareSectionTitle> createState() => _ThemeAwareSectionTitleState();
}

class _ThemeAwareSectionTitleState extends State<_ThemeAwareSectionTitle> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textColor = AppColors.primaryText(brightness);
    return Text(
      widget.title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }
}
