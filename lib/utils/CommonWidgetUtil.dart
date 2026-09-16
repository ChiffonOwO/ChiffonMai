import 'dart:io';

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
   *
   * 注意：这里**不再**有 onReset 形参。原先它是个从未被使用的死参数，
   * 各页面因此各自手写一份「重置所有设置」按钮和默认值字面量，
   * 结果歌曲片段页那份漏了播放时长。默认值现在统一来自
   * `GuessChartCommonSettingsService.defaultSettings()`。
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
    {
    // 定数范围这一节的标题。
    //
    // 默认面向「按 MASTER 难度定数筛选」的模式（无提示 / 曲绘 / 模糊曲绘 /
    // 歌曲片段 / 别名 / 开字母），那里确实只看 MASTER 的定数。
    // 但**谱面片段猜歌**是按「难度随机池」抽谱的，判定用的是池内各难度
    // 各自的定数，写「MASTER定数范围」会让用户以为只按 MASTER 筛 —— 与实际不符，
    // 所以那一页传「定数范围」。
    String dxRangeTitle = 'MASTER定数范围',
    // 定数范围下方的补充说明（可选），用于点明判定口径。
    String? dxRangeHint,
  }) {
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
          _buildSectionTitle(dxRangeTitle),
          _buildMasterDxRangeInput(
            context,
            masterMinDx,
            masterMaxDx,
            onMasterDxRangeChanged,
          ),
          if (dxRangeHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                dxRangeHint,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.greyHint(
                      Theme.of(context).brightness),
                ),
              ),
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
            // divisions 必须是 (max-min) 的约数：原来写 20，步长 = 19/20 = 0.95，
            // 拖动会取到 10 两次（9.5→10、10.45→10）且拿不到整数序列。
            // 19 段 → 步长正好 1，取值 1..20 一一对应。
            divisions: 19,
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
    return _MasterDxRangeInput(
      minValue: minValue,
      maxValue: maxValue,
      onChanged: onChanged,
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

/// MASTER 定数范围输入框。
///
/// 必须是 StatefulWidget，且**由它自己持有 TextEditingController**：
/// 原先这个输入框直接建在 `buildGuessChartSettingsWidget` 里，每次外层
/// setState（勾选版本、拖滑块……）都会新建 controller，导致
/// - 用户输入到一半、去点了别的控件 → 输入内容被重置回旧值；
/// - 提交时机是 `onEditingComplete`，只有按回车才生效，点「确定」直接
///   关掉对话框时改动会**静默丢失**（widget 测试里实测 committed=0）。
///
/// 现在改为：controller 由本 State 持有，失焦（onTapOutside）与回车都会提交，
/// 并且 controller 文本只在「外部值变化」时才同步，不会打断用户输入。
class _MasterDxRangeInput extends StatefulWidget {
  const _MasterDxRangeInput({
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
  });

  final double minValue;
  final double maxValue;
  final Function(double, double) onChanged;

  @override
  State<_MasterDxRangeInput> createState() => _MasterDxRangeInputState();
}

class _MasterDxRangeInputState extends State<_MasterDxRangeInput> {
  static const double _absoluteMin = 1.0;
  static const double _absoluteMax = 15.0;

  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final FocusNode _minFocus;
  late final FocusNode _maxFocus;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(text: _fmt(widget.minValue));
    _maxController = TextEditingController(text: _fmt(widget.maxValue));
    _minFocus = FocusNode();
    _maxFocus = FocusNode();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MasterDxRangeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有外部值**真的变了**才回写文本，否则会把用户正在输入的内容抹掉
    // （例如「14.」这种还没输入完、暂不非法的中间态）。
    if (widget.minValue != oldWidget.minValue && !_minFocus.hasFocus) {
      _minController.text = _fmt(widget.minValue);
    }
    if (widget.maxValue != oldWidget.maxValue && !_maxFocus.hasFocus) {
      _maxController.text = _fmt(widget.maxValue);
    }
  }

  static String _fmt(double v) => v.toStringAsFixed(1);

  /// 提交一个输入框的值。非法输入（空/非数字/越界）一律**回滚成当前外部值**，
  /// 而不是悄悄丢弃——否则用户会看着一个和实际生效值不一致的数字。
  void _commit({required bool isMin}) {
    final TextEditingController controller = isMin ? _minController : _maxController;
    final double fallback = isMin ? widget.minValue : widget.maxValue;
    final double? parsed = double.tryParse(controller.text.trim());
    final bool valid = parsed != null &&
        parsed >= _absoluteMin &&
        parsed <= _absoluteMax;
    if (!valid) {
      controller.text = _fmt(fallback);
      return;
    }
    final double newMin = isMin ? parsed : widget.minValue;
    final double newMax = isMin ? widget.maxValue : parsed;
    // 归一化显示（14 -> 14.0），并保持 min <= max：
    // 若用户把最小值填得比最大值还大，就把最大值一起顶上去。
    if (newMin > newMax) {
      final double unified = isMin ? newMin : newMax;
      _minController.text = _fmt(unified);
      _maxController.text = _fmt(unified);
      widget.onChanged(unified, unified);
      return;
    }
    controller.text = _fmt(parsed);
    widget.onChanged(newMin, newMax);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最小:'),
                  TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    controller: _minController,
                    focusNode: _minFocus,
                    onSubmitted: (_) => _commit(isMin: true),
                    onTapOutside: (_) => _commit(isMin: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最大:'),
                  TextField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    controller: _maxController,
                    focusNode: _maxFocus,
                    onSubmitted: (_) => _commit(isMin: false),
                    onTapOutside: (_) => _commit(isMin: false),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('范围：1.0 - 15.0',
            style:
                TextStyle(fontSize: 12, color: AppColors.greyHint(brightness))),
        const SizedBox(height: 4),
        Text('输入后点其它位置或按回车即可生效',
            style:
                TextStyle(fontSize: 12, color: AppColors.greyHint(brightness))),
      ],
    );
  }
}

/// 主题感知的背景图组件（StatelessWidget）
/// 性能：用 Stack + 半透明覆层代替 ColorFiltered + BlendMode.darken，避免 saveLayer
/// - 浅色模式：白色半透明覆层使背景图变成若隐若现的纹理（不透明度用户可调）
/// - 深色模式：深色半透明覆层压暗背景图
/// - 纯黑模式：隐藏背景图，显示纯黑底色
/// - 用户自定义背景图：ThemeManager.customBackgroundPath 非空时优先使用本地文件
class _ThemeAwareBgWidget extends StatelessWidget {
  const _ThemeAwareBgWidget();

  @override
  Widget build(BuildContext context) {
    // 用 ListenableBuilder 包裹两个信号：覆层透明度 + 自定义背景图路径
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeManager().lightOverlayNotifier,
        ThemeManager().customBackgroundPathNotifier,
      ]),
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isPureBlack = isDark && ThemeManager().pureBlackEnabled;
        final opacity = ThemeManager().lightOverlayOpacity;
        final overlayAlpha = (opacity * 255).round().clamp(0, 255);
        final lightOverlay = Color.fromARGB(overlayAlpha, 255, 255, 255);
        final darkOverlay = Color.fromARGB(overlayAlpha, 15, 15, 28);

        // 解析背景图层：自定义路径 -> Image.file，否则 -> Image.asset
        final customPath = ThemeManager().customBackgroundPath;
        Widget bgImage;
        if (customPath != null) {
          bgImage = Image.file(
            File(customPath),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        } else {
          bgImage = Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 纯黑模式：不加载背景图，只放纯黑底色
            if (isPureBlack)
              const Positioned.fill(child: ColoredBox(color: Colors.black))
            else ...[
              Positioned.fill(child: bgImage),
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
/// - 浅色/深色模式：使用 ThemeManager.chiffonOpacity 控制装饰图透明度
/// - 纯黑模式：完全隐藏装饰层
class _ThemeAwareChiffonWidget extends StatelessWidget {
  const _ThemeAwareChiffonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 用 ListenableBuilder 包裹两个信号：覆层透明度 + chiffon 透明度
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeManager().lightOverlayNotifier,
        ThemeManager().chiffonOpacityNotifier,
      ]),
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
                      ThemeManager().chiffonOpacity,
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
