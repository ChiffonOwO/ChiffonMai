import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AchievementFullReverseCalculator extends StatefulWidget {
  const AchievementFullReverseCalculator({super.key});

  @override
  State<AchievementFullReverseCalculator> createState() =>
      _AchievementFullReverseCalculatorState();
}

class _AchievementFullReverseCalculatorState
    extends State<AchievementFullReverseCalculator> {
  // 普通音符的计数器
  int _tapCp = 0, _tapP = 0, _tapG = 0, _tapGo = 0, _tapM = 0;
  int _holdCp = 0, _holdP = 0, _holdG = 0, _holdGo = 0, _holdM = 0;
  int _slideCp = 0, _slideP = 0, _slideG = 0, _slideGo = 0, _slideM = 0;
  int _touchCp = 0, _touchP = 0, _touchG = 0, _touchGo = 0, _touchM = 0;
  int _breakCp = 0, _breakP = 0, _breakG = 0, _breakGo = 0, _breakM = 0;

  // TextEditingControllers for all input fields
  late TextEditingController _tapCpController;
  late TextEditingController _tapPController;
  late TextEditingController _tapGController;
  late TextEditingController _tapGoController;
  late TextEditingController _tapMController;

  late TextEditingController _holdCpController;
  late TextEditingController _holdPController;
  late TextEditingController _holdGController;
  late TextEditingController _holdGoController;
  late TextEditingController _holdMController;

  late TextEditingController _slideCpController;
  late TextEditingController _slidePController;
  late TextEditingController _slideGController;
  late TextEditingController _slideGoController;
  late TextEditingController _slideMController;

  late TextEditingController _touchCpController;
  late TextEditingController _touchPController;
  late TextEditingController _touchGController;
  late TextEditingController _touchGoController;
  late TextEditingController _touchMController;

  late TextEditingController _breakCpController;
  late TextEditingController _breakPController;
  late TextEditingController _breakGController;
  late TextEditingController _breakGoController;
  late TextEditingController _breakMController;

  // 达成率输入
  String _achievementRate = '';

  // 计算结果存储
  String? _resultText;
  bool _calculating = false;

  // 定义权重常量
  static const int TAP_WEIGHT = 1;
  static const int HOLD_WEIGHT = 2;
  static const int SLIDE_WEIGHT = 3;
  static const int TOUCH_WEIGHT = 1;
  static const int BREAK_WEIGHT = 5;

  @override
  void initState() {
    super.initState();

    // Initialize all controllers with current values
    _tapCpController = TextEditingController(text: _tapCp.toString());
    _tapPController = TextEditingController(text: _tapP.toString());
    _tapGController = TextEditingController(text: _tapG.toString());
    _tapGoController = TextEditingController(text: _tapGo.toString());
    _tapMController = TextEditingController(text: _tapM.toString());

    _holdCpController = TextEditingController(text: _holdCp.toString());
    _holdPController = TextEditingController(text: _holdP.toString());
    _holdGController = TextEditingController(text: _holdG.toString());
    _holdGoController = TextEditingController(text: _holdGo.toString());
    _holdMController = TextEditingController(text: _holdM.toString());

    _slideCpController = TextEditingController(text: _slideCp.toString());
    _slidePController = TextEditingController(text: _slideP.toString());
    _slideGController = TextEditingController(text: _slideG.toString());
    _slideGoController = TextEditingController(text: _slideGo.toString());
    _slideMController = TextEditingController(text: _slideM.toString());

    _touchCpController = TextEditingController(text: _touchCp.toString());
    _touchPController = TextEditingController(text: _touchP.toString());
    _touchGController = TextEditingController(text: _touchG.toString());
    _touchGoController = TextEditingController(text: _touchGo.toString());
    _touchMController = TextEditingController(text: _touchM.toString());

    _breakCpController = TextEditingController(text: _breakCp.toString());
    _breakPController = TextEditingController(text: _breakP.toString());
    _breakGController = TextEditingController(text: _breakG.toString());
    _breakGoController = TextEditingController(text: _breakGo.toString());
    _breakMController = TextEditingController(text: _breakM.toString());
  }

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    _tapCpController.dispose();
    _tapPController.dispose();
    _tapGController.dispose();
    _tapGoController.dispose();
    _tapMController.dispose();

    _holdCpController.dispose();
    _holdPController.dispose();
    _holdGController.dispose();
    _holdGoController.dispose();
    _holdMController.dispose();

    _slideCpController.dispose();
    _slidePController.dispose();
    _slideGController.dispose();
    _slideGoController.dispose();
    _slideMController.dispose();

    _touchCpController.dispose();
    _touchPController.dispose();
    _touchGController.dispose();
    _touchGoController.dispose();
    _touchMController.dispose();

    _breakCpController.dispose();
    _breakPController.dispose();
    _breakGController.dispose();
    _breakGoController.dispose();
    _breakMController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 计算总计
    int totalCp = _tapCp + _holdCp + _slideCp + _touchCp + _breakCp;
    int totalP = _tapP + _holdP + _slideP + _touchP + _breakP;
    int totalG = _tapG + _holdG + _slideG + _touchG + _breakG;
    int totalGo = _tapGo + _holdGo + _slideGo + _touchGo + _breakGo;
    int totalM = _tapM + _holdM + _slideM + _touchM + _breakM;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false, // 防止键盘弹出时挤压背景
      body: Stack(
        children: [
          // 层级1：基础背景图 - 占满整个屏幕，作为页面最底层背景
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // 背景图资源
                fit: BoxFit.cover, // 覆盖整个容器，拉伸/裁剪适配
                opacity: 1.0, // 不透明
              ),
            ),
          ),

          // 层级2：第一张虚化装饰图 - 居中显示，轻微向上偏移
          Center(
            child: Transform.translate(
              offset: Offset(0, -screenHeight * 0.02), // 垂直向上偏移屏幕高度的2%
              child: Transform.scale(
                scale: 1, // 不缩放
                child: Image.asset(
                  'assets/chiffon2.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1), // 固定不透明
                ),
              ),
            ),
          ),

          // 页面标题
          Positioned(
            top: screenHeight * 0.08, // 距离顶部为屏幕高度的8%
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "达成率反推",
                style: TextStyle(
                  color: Color.fromARGB(255, 84, 97, 97),
                  fontSize: screenWidth * 0.06, // 字体大小为屏幕宽度的6%
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // 返回按钮
          Positioned(
            top: screenHeight * 0.05, // 距离顶部为屏幕高度的5%
            left: screenWidth * 0.03, // 距离左侧为屏幕宽度的3%
            child: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: Color.fromARGB(255, 84, 97, 97), 
                  size: screenWidth * 0.06), // 图标大小为屏幕宽度的6%
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          // 主要内容区域
          Positioned(
            top: screenHeight * 0.15, // 距离顶部为屏幕高度的15%
            left: screenWidth * 0.03, // 距离左侧为屏幕宽度的3%
            right: screenWidth * 0.03, // 距离右侧为屏幕宽度的3%
            bottom: screenHeight * 0.03, // 距离底部为屏幕高度的3%
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5.0,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(screenWidth * 0.04), // padding 为屏幕宽度的4%
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 普通音符表格
                    _buildSectionTitle('判定详情'),
                    _buildNormalNoteTable(
                        totalCp, totalP, totalG, totalGo, totalM),
                    SizedBox(height: screenHeight * 0.03), // 间距为屏幕高度的3%

                    // 达成率输入框
                    _buildAchievementRateInput(),
                    SizedBox(height: screenHeight * 0.025), // 间距为屏幕高度的2.5%

                    // 计算和重置按钮区域
                    Row(
                      children: [
                        // 重置按钮 - 占据1/5宽度
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: _resetAll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015), // 垂直 padding 为屏幕高度的1.5%
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text("重置", style: TextStyle(fontSize: screenWidth * 0.035)), // 字体大小为屏幕宽度的3.5%
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.02), // 按钮间距为屏幕宽度的2%
                        // 计算按钮 - 占据4/5宽度
                        Expanded(
                          flex: 4,
                          child: _buildCalculateButton(),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%

                    // 计算结果显示区域
                    if (_resultText != null)
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.03), // padding 为屏幕宽度的3%
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          _resultText!,
                          style: TextStyle(fontSize: screenWidth * 0.035, height: 1.5), // 字体大小为屏幕宽度的3.5%
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建计算按钮
  Widget _buildCalculateButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return ElevatedButton(
      onPressed: _calculating ? null : _calculateFullReverse,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015), // 垂直 padding 为屏幕高度的1.5%
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _calculating
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: screenWidth * 0.04, // 宽度为屏幕宽度的4%
                    height: screenWidth * 0.04, // 高度为屏幕宽度的4%
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                SizedBox(width: screenWidth * 0.025), // 间距为屏幕宽度的2.5%
                Text("计算中..."),
              ],
            )
          : Text("计算绝赞详情", style: TextStyle(fontSize: screenWidth * 0.04)), // 字体大小为屏幕宽度的4%
    );
  }

  // 核心计算逻辑（移植Java代码）
  void _calculateFullReverse() async {
    // 输入验证
    if (_achievementRate.isEmpty) {
      _showErrorDialog("请输入目标达成率");
      return;
    }

    double targetRate;
    try {
      targetRate = double.parse(_achievementRate);
      if (targetRate < 0 || targetRate > 101) {
        _showErrorDialog("达成率请输入0~101之间的数值");
        return;
      }
    } catch (e) {
      _showErrorDialog("达成率格式错误，请输入有效的数字（如100.5000）");
      return;
    }

    // 标记计算中状态
    setState(() {
      _calculating = true;
      _resultText = null;
    });

    // 使用异步计算避免UI阻塞
    await Future.delayed(const Duration(milliseconds: 100), () {
      // ========== 第一步：获取输入数据 ==========
      // 目标达成率（保留4位小数）
      double totalScoreTarget = double.parse(targetRate.toStringAsFixed(4));

      // 各音符数量
      int tapNum = _tapCp + _tapP + _tapG + _tapGo + _tapM;
      int holdNum = _holdCp + _holdP + _holdG + _holdGo + _holdM;
      int slideNum = _slideCp + _slideP + _slideG + _slideGo + _slideM;
      int touchNum = _touchCp + _touchP + _touchG + _touchGo + _touchM;
      int breakNum = _breakCp + _breakP + _breakG + _breakGo + _breakM;

      // 总权重计算
      int totalTapWeight = tapNum * TAP_WEIGHT;
      int totalHoldWeight = holdNum * HOLD_WEIGHT;
      int totalSlideWeight = slideNum * SLIDE_WEIGHT;
      int totalTouchWeight = touchNum * TOUCH_WEIGHT;
      int totalBreakWeight = breakNum * BREAK_WEIGHT;
      int totalWeight = totalTapWeight +
          totalHoldWeight +
          totalSlideWeight +
          totalTouchWeight +
          totalBreakWeight;

      // 非break部分基础得分
      double baseTap =
          TAP_WEIGHT * (_tapCp + _tapP + _tapG * 0.8 + _tapGo * 0.5);
      double baseHold =
          HOLD_WEIGHT * (_holdCp + _holdP + _holdG * 0.8 + _holdGo * 0.5);
      double baseSlide =
          SLIDE_WEIGHT * (_slideCp + _slideP + _slideG * 0.8 + _slideGo * 0.5);
      double baseTouch =
          TOUCH_WEIGHT * (_touchCp + _touchP + _touchG * 0.8 + _touchGo * 0.5);
      double baseNonBreak = baseTap + baseHold + baseSlide + baseTouch;

      // ========== 第二步：遍历寻找可行解 ==========
      bool found = false;
      const double errorThreshold = 0.0001; // 误差阈值
      String result = "";

      // 存储最优解
      int bestP75 = 0, bestP50 = 0, bestG80 = 0, bestG60 = 0, bestG50 = 0;
      double bestBaseScore = 0, bestExtraScore = 0, bestTotalScore = 0;
      double minError = double.infinity;

      // 遍历break_perfect_75的可能值（0~breakP）
      for (int breakP75 = 0; breakP75 <= _breakP; breakP75++) {
        int breakP50 = _breakP - breakP75;

        // 遍历break_great_80的可能值（0~breakG）
        for (int breakG80 = 0; breakG80 <= _breakG; breakG80++) {
          // 遍历break_great_60的可能值（0~剩余数量）
          for (int breakG60 = 0; breakG60 <= _breakG - breakG80; breakG60++) {
            int breakG50 = _breakG - breakG80 - breakG60;

            // 计算基础达成率
            double baseBreak = BREAK_WEIGHT *
                (_breakCp +
                    _breakP +
                    breakG80 * 0.8 +
                    breakG60 * 0.6 +
                    breakG50 * 0.5 +
                    _breakGo * 0.4);
            double baseTotal = baseNonBreak + baseBreak;
            double baseScore = (baseTotal / totalWeight) * 100;
            baseScore = double.parse(baseScore.toStringAsFixed(4));

            // 计算额外达成率
            double extraBreak = _breakCp +
                breakP75 * 0.75 +
                breakP50 * 0.5 +
                _breakG * 0.4 +
                _breakGo * 0.3;
            double extraScore = breakNum == 0 ? 0 : (extraBreak / breakNum);
            extraScore = double.parse(extraScore.toStringAsFixed(4));

            // 总达成率
            double totalScore = baseScore + extraScore;
            totalScore = double.parse(totalScore.toStringAsFixed(4));
            double error = (totalScore - totalScoreTarget).abs();

            // 更新最优解
            if (error < minError) {
              minError = error;
              bestP75 = breakP75;
              bestP50 = breakP50;
              bestG80 = breakG80;
              bestG60 = breakG60;
              bestG50 = breakG50;
              bestBaseScore = baseScore;
              bestExtraScore = extraScore;
              bestTotalScore = totalScore;
            }

            // 找到符合误差阈值的解
            if (error <= errorThreshold) {
              result = """✅ 找到可行解（误差≤0.0001%）：
目标达成率：$totalScoreTarget%
50落 = $breakP75
100落 = $breakP50
80% GREAT = $breakG80
60% GREAT = $breakG60
50% GREAT = $breakG50
基础达成率：$baseScore%
额外达成率：$extraScore%
总达成率：$totalScore%
误差：$error%""";
              found = true;
              break;
            }
          }
          if (found) break;
        }
        if (found) break;
      }

      // 未找到精确解，显示最接近的解
      if (!found) {
        result = """❌ 未找到符合误差阈值的解，以下是最接近的结果：
目标达成率：$totalScoreTarget%
50落 = $bestP75
100落 = $bestP50
80% GREAT = $bestG80
60% GREAT = $bestG60
50% GREAT = $bestG50
基础达成率：$bestBaseScore%
额外达成率：$bestExtraScore%
总达成率：$bestTotalScore%
最小误差：$minError%""";
      }

      // 更新UI显示结果
      setState(() {
        _calculating = false;
        _resultText = result;
      });
    });
  }

  // 显示错误提示弹窗
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("输入错误"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }
  
  // 重置所有数据
  void _resetAll() {
    setState(() {
      // 重置所有音符计数器
      _tapCp = 0; _tapP = 0; _tapG = 0; _tapGo = 0; _tapM = 0;
      _holdCp = 0; _holdP = 0; _holdG = 0; _holdGo = 0; _holdM = 0;
      _slideCp = 0; _slideP = 0; _slideG = 0; _slideGo = 0; _slideM = 0;
      _touchCp = 0; _touchP = 0; _touchG = 0; _touchGo = 0; _touchM = 0;
      _breakCp = 0; _breakP = 0; _breakG = 0; _breakGo = 0; _breakM = 0;
      
      // 重置达成率输入
      _achievementRate = '';
      
      // 重置计算结果
      _resultText = null;
      _calculating = false;
      
      // 更新所有控制器的文本
      _tapCpController.text = '0';
      _tapPController.text = '0';
      _tapGController.text = '0';
      _tapGoController.text = '0';
      _tapMController.text = '0';
      
      _holdCpController.text = '0';
      _holdPController.text = '0';
      _holdGController.text = '0';
      _holdGoController.text = '0';
      _holdMController.text = '0';
      
      _slideCpController.text = '0';
      _slidePController.text = '0';
      _slideGController.text = '0';
      _slideGoController.text = '0';
      _slideMController.text = '0';
      
      _touchCpController.text = '0';
      _touchPController.text = '0';
      _touchGController.text = '0';
      _touchGoController.text = '0';
      _touchMController.text = '0';
      
      _breakCpController.text = '0';
      _breakPController.text = '0';
      _breakGController.text = '0';
      _breakGoController.text = '0';
      _breakMController.text = '0';
    });
  }

  // 构建区域标题
  Widget _buildSectionTitle(String title) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Text(
      title,
      style: TextStyle(
        fontSize: screenWidth * 0.05, // 字体大小为屏幕宽度的5%
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
      textAlign: TextAlign.center,
    );
  }

  // 构建普通音符表格
  Widget _buildNormalNoteTable(
      int totalCp, int totalP, int totalG, int totalGo, int totalM) {
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey),
        verticalInside: BorderSide(color: Colors.grey),
        top: BorderSide(color: Colors.grey),
        bottom: BorderSide(color: Colors.grey),
        left: BorderSide(color: Colors.grey),
        right: BorderSide(color: Colors.grey),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // 表头
        TableRow(
          children: [
            _buildTableCell('', color: Colors.transparent),
            _buildTableCell('CRITICAL\nPERFECT',
                color: Colors.yellow[200]!, fontSize: 8.5),
            _buildTableCell('PERFECT', color: Colors.yellow[400]!, fontSize: 9),
            _buildTableCell('GREAT', color: Colors.pink[200]!, fontSize: 10),
            _buildTableCell('GOOD', color: Colors.green[200]!, fontSize: 10),
            _buildTableCell('MISS', color: Colors.grey[200]!, fontSize: 10),
          ],
        ),
        // TAP行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('TAP',
                color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(
                _tapCp, (val) => setState(() => _tapCp = val), _tapCpController,
                color: Colors.yellow[200]),
            _buildNumberInputCell(
                _tapP, (val) => setState(() => _tapP = val), _tapPController,
                color: Colors.yellow[400]),
            _buildNumberInputCell(
                _tapG, (val) => setState(() => _tapG = val), _tapGController,
                color: Colors.pink[200]),
            _buildNumberInputCell(
                _tapGo, (val) => setState(() => _tapGo = val), _tapGoController,
                color: Colors.green[200]),
            _buildNumberInputCell(
                _tapM, (val) => setState(() => _tapM = val), _tapMController,
                color: Colors.grey[200]),
          ],
        ),
        // HOLD行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('HOLD',
                color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(_holdCp,
                (val) => setState(() => _holdCp = val), _holdCpController,
                color: Colors.yellow[200]),
            _buildNumberInputCell(
                _holdP, (val) => setState(() => _holdP = val), _holdPController,
                color: Colors.yellow[400]),
            _buildNumberInputCell(
                _holdG, (val) => setState(() => _holdG = val), _holdGController,
                color: Colors.pink[200]),
            _buildNumberInputCell(_holdGo,
                (val) => setState(() => _holdGo = val), _holdGoController,
                color: Colors.green[200]),
            _buildNumberInputCell(
                _holdM, (val) => setState(() => _holdM = val), _holdMController,
                color: Colors.grey[200]),
          ],
        ),
        // SLIDE行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('SLIDE',
                color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(_slideCp,
                (val) => setState(() => _slideCp = val), _slideCpController,
                color: Colors.yellow[200]),
            _buildNumberInputCell(_slideP,
                (val) => setState(() => _slideP = val), _slidePController,
                color: Colors.yellow[400]),
            _buildNumberInputCell(_slideG,
                (val) => setState(() => _slideG = val), _slideGController,
                color: Colors.pink[200]),
            _buildNumberInputCell(_slideGo,
                (val) => setState(() => _slideGo = val), _slideGoController,
                color: Colors.green[200]),
            _buildNumberInputCell(_slideM,
                (val) => setState(() => _slideM = val), _slideMController,
                color: Colors.grey[200]),
          ],
        ),
        // TOUCH行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('TOUCH',
                color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(_touchCp,
                (val) => setState(() => _touchCp = val), _touchCpController,
                color: Colors.yellow[200]),
            _buildNumberInputCell(_touchP,
                (val) => setState(() => _touchP = val), _touchPController,
                color: Colors.yellow[400]),
            _buildNumberInputCell(_touchG,
                (val) => setState(() => _touchG = val), _touchGController,
                color: Colors.pink[200]),
            _buildNumberInputCell(_touchGo,
                (val) => setState(() => _touchGo = val), _touchGoController,
                color: Colors.green[200]),
            _buildNumberInputCell(_touchM,
                (val) => setState(() => _touchM = val), _touchMController,
                color: Colors.grey[200]),
          ],
        ),
        // BREAK行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('BREAK',
                color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(_breakCp,
                (val) => setState(() => _breakCp = val), _breakCpController,
                color: Colors.yellow[200]),
            _buildNumberInputCell(_breakP,
                (val) => setState(() => _breakP = val), _breakPController,
                color: Colors.yellow[400]),
            _buildNumberInputCell(_breakG,
                (val) => setState(() => _breakG = val), _breakGController,
                color: Colors.pink[200]),
            _buildNumberInputCell(_breakGo,
                (val) => setState(() => _breakGo = val), _breakGoController,
                color: Colors.green[200]),
            _buildNumberInputCell(_breakM,
                (val) => setState(() => _breakM = val), _breakMController,
                color: Colors.grey[200]),
          ],
        ),
        // 总计行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('总计',
                color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildTableCell(totalCp.toString(), color: Colors.yellow[200]!),
            _buildTableCell(totalP.toString(), color: Colors.yellow[400]!),
            _buildTableCell(totalG.toString(), color: Colors.pink[200]!),
            _buildTableCell(totalGo.toString(), color: Colors.green[200]!),
            _buildTableCell(totalM.toString(), color: Colors.grey[200]!),
          ],
        ),
      ],
    );
  }

  // 构建达成率输入框
  Widget _buildAchievementRateInput() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('达成率: '),
        SizedBox(
          width: screenWidth * 0.3, // 宽度为屏幕宽度的30%
          child: TextField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '四位小数',
              contentPadding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02), // 水平 padding 为屏幕宽度的2%
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
            ],
            textAlign: TextAlign.center,
            onChanged: (val) {
              setState(() {
                _achievementRate = val;
              });
            },
          ),
        ),
        SizedBox(width: screenWidth * 0.01), // 间距为屏幕宽度的1%
        const Text('%'),
      ],
    );
  }

  // 构建表格单元格
  Widget _buildTableCell(String text, {Color? color, double fontSize = 12.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      color: color,
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01), // 垂直 padding 为屏幕高度的1%
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: screenWidth * 0.025, // 字体大小为屏幕宽度的2.5%
        ),
      ),
    );
  }

  // 构建数字输入单元格
  Widget _buildNumberInputCell(
      int value, Function(int) onChanged, TextEditingController controller,
      {Color? color}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      color: color, // 添加颜色参数
      padding: EdgeInsets.zero, // 移除所有内边距，确保颜色完全填充
      margin: EdgeInsets.zero, // 确保没有外边距
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: value == 0 ? '' : value.toString(),
          contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.01, 
              vertical: screenHeight * 0.01), // 设置输入框内边距
          isDense: true, // 紧凑模式，减少默认高度
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: screenWidth * 0.025, // 字体大小为屏幕宽度的2.5%
        ),
        onTap: () {
          if (value == 0) {
            controller.clear();
          } else {
            // 将光标移动到文本末尾
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        },
        onChanged: (val) {
          final parsedValue = int.tryParse(val) ?? 0;
          onChanged(parsedValue);
          if (val.isEmpty) {
            controller.text = '0';
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        },
      ),
    );
  }
}