import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/utils/StringUtil.dart';

/**
 * 通用Widget工具类
 * 用于构建通用背景Widget
 */
class CommonWidgetUtil {
  /**
   * 构建通用背景Widget
   * 层级1：基础背景图 - 占满整个屏幕，作为页面最底层背景
   * @return 通用背景Widget
   */
  static Widget buildCommonBgWidget() {
    return Container(
      // 固定背景，不受键盘影响, 占满整个屏幕，由 Flutter 布局引擎优化处理
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // 背景图资源
                fit: BoxFit.cover, // 覆盖整个容器，拉伸/裁剪适配
                opacity: 1.0, // 不透明
              ),
            ),
          );
  }

  /**
   * 构建通用背景Widget
   * 层级2：第一张虚化装饰图 - 居中显示，轻微向上偏移
   * @return 通用背景Widget
   */
  static Widget buildCommonChiffonBgWidget(BuildContext context) {
    return Center(
            child: Transform.translate(
              offset: Offset(0, -MediaQuery.of(context).size.height * 0.03), // 垂直向上偏移20px
              child: Transform.scale(
                scale: 1, // 不缩放
                child: Image.asset(
                  'assets/chiffon2.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1), // 固定不透明
                ),
              ),
            ),
          );
  }

  /**
   * 构建通用标题Widget
   * @return 通用标题Widget
   */
  static Widget buildCommonTitleWidget(String title) {
    // 页面标题
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: Color.fromARGB(255, 84, 97, 97),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  /**
   * 构建通用返回按钮Widget
   * @return 通用返回按钮Widget
   */
  static Widget buildCommonBackButtonWidget(BuildContext context) {
    return Positioned(
      top: 40,
      left: 10,
      child: GestureDetector(
        onTap: () {
          print('返回按钮被点击');
          Navigator.pop(context); // 返回到主页
        },
        child: Container(
          padding: EdgeInsets.all(16), // 增加点击区域
          color: Colors.transparent, // 透明背景，不影响视觉
          child: Icon(Icons.arrow_back,
              color: Color.fromARGB(255, 84, 97, 97), size: 24), // 增大图标
        ),
      ),
    );
  }

  /**
   * 构建猜歌通用设置Widget
   * @return 通用设置Widget
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
          // 版本选择
          _buildSectionTitle('选择版本（支持复选，默认全部，不选表示所有）'),
          _buildMultiSelectList(
            context,
            allVersions,
            selectedVersions,
            onVersionsChanged,
            (version) => StringUtil.formatVersion2(version),
          ),
          SizedBox(height: 20),

          // MASTER定数范围
          _buildSectionTitle('MASTER定数范围'),
          _buildMasterDxRangeInput(
            masterMinDx,
            masterMaxDx,
            onMasterDxRangeChanged,
          ),
          SizedBox(height: 20),

          // 流派选择
          _buildSectionTitle('选择流派（支持复选，默认全部，不选表示所有）'),
          _buildMultiSelectList(
            context,
            allGenres.where((genre) => genre != '\u5bb4\u4f1a\u5834').toList(),
            selectedGenres.where((genre) => genre != '\u5bb4\u4f1a\u5834').toList(),
            onGenresChanged,
            null,
          ),
          SizedBox(height: 20),

          // 猜测次数
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

          // 时间限制
          _buildSectionTitle('时间限制（拉到最右侧为无限制）'),
          _buildSlider(
            value: timeLimit == 0 ? 180.0 : timeLimit.toDouble(),
            min: 30,
            max: 180,
            divisions: 15, // (180-30)/10 = 15
            label: timeLimit == 0 || timeLimit == 180 ? '无限制' : '$timeLimit秒',
            onChanged: (value) {
              int selectedValue = value.toInt();
              // 步长10，将值四舍五入到最近的10的倍数
              int roundedValue = (selectedValue / 10).round() * 10;
              roundedValue = roundedValue.clamp(30, 180);
              onTimeLimitChanged(roundedValue == 180 ? 0 : roundedValue);
            },
          ),

        ],
      ),
    );
  }

  // 构建章节标题
  static Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(255, 84, 97, 97),
      ),
    );
  }

  // 构建多选列表
  static Widget _buildMultiSelectList(
    BuildContext context,
    List<String> items,
    List<String> selectedItems,
    Function(List<String>) onChanged,
    String Function(String)? formatter,
  ) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
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

  // 构建MASTER定数范围输入框
  static Widget _buildMasterDxRangeInput(
    double minValue,
    double maxValue,
    Function(double, double) onChanged,
  ) {
    // 处理浮点数精度问题，保留一位小数
    double formattedMin = double.parse(minValue.toStringAsFixed(1));
    double formattedMax = double.parse(maxValue.toStringAsFixed(1));
    
    // 创建控制器
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
                      // 输入完成时更新状态
                      String value = minController.text;
                      if (value.isEmpty) {
                        onChanged(1.0, maxValue);
                      } else {
                        double? newMin = double.tryParse(value);
                        if (newMin != null && newMin >= 1.0 && newMin <= 15.0) {
                          onChanged(newMin, maxValue);
                        }
                      }
                    },
                    onSubmitted: (value) {
                      // 提交时更新状态
                      if (value.isEmpty) {
                        onChanged(1.0, maxValue);
                      } else {
                        double? newMin = double.tryParse(value);
                        if (newMin != null && newMin >= 1.0 && newMin <= 15.0) {
                          onChanged(newMin, maxValue);
                        }
                      }
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
                      // 输入完成时更新状态
                      String value = maxController.text;
                      if (value.isEmpty) {
                        onChanged(minValue, 15.0);
                      } else {
                        double? newMax = double.tryParse(value);
                        if (newMax != null && newMax >= 1.0 && newMax <= 15.0) {
                          onChanged(minValue, newMax);
                        }
                      }
                    },
                    onSubmitted: (value) {
                      // 提交时更新状态
                      if (value.isEmpty) {
                        onChanged(minValue, 15.0);
                      } else {
                        double? newMax = double.tryParse(value);
                        if (newMax != null && newMax >= 1.0 && newMax <= 15.0) {
                          onChanged(minValue, newMax);
                        }
                      }
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
        Text('范围：1.0 - 15.0', style: TextStyle(fontSize: 12, color: Colors.grey)),
        SizedBox(height: 4),
        Text('输入完毕后请点击输入法的回车键', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // 构建滑块
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
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
        ),
        Text(label),
      ],
    );
  }

  // static Widget buildCommonTitleAndBackButtonRowWidget(BuildContext context, String title) {
  //   return Row(
  //     children: [
  //       buildCommonTitleWidget(title),
  //       buildCommonBackButtonWidget(context),
  //     ],
  //   );
  // }

}