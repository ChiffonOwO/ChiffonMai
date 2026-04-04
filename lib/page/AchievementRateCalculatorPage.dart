import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

class AchievementRateCalculator extends StatefulWidget {
  const AchievementRateCalculator({super.key});

  @override
  State<AchievementRateCalculator> createState() =>
      _AchievementRateCalculatorState();
}

class _AchievementRateCalculatorState
    extends State<AchievementRateCalculator> {
  // 普通音符的计数器
  int _tapCp = 0, _tapP = 0, _tapG = 0, _tapGo = 0, _tapM = 0;
  int _holdCp = 0, _holdP = 0, _holdG = 0, _holdGo = 0, _holdM = 0;
  int _slideCp = 0, _slideP = 0, _slideG = 0, _slideGo = 0, _slideM = 0;
  int _touchCp = 0, _touchP = 0, _touchG = 0, _touchGo = 0, _touchM = 0;

  // Break音符的计数器
  int _breakP = 0, _break50 = 0, _break100 = 0;
  int _break80 = 0, _break60 = 0, _break50g = 0;
  int _breakGo = 0, _breakM = 0;

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
  
  late TextEditingController _breakPController;
  late TextEditingController _break50Controller;
  late TextEditingController _break100Controller;
  late TextEditingController _break80Controller;
  late TextEditingController _break60Controller;
  late TextEditingController _break50gController;
  late TextEditingController _breakGoController;
  late TextEditingController _breakMController;

  // 定义各种note的权重
  static const int tapWeight = 1;
  static const int holdWeight = 2;
  static const int slideWeight = 3;
  static const int touchWeight = 1;
  static const int breakWeight = 5;

  // 计算达成率的方法
  void _calculateAchievementRate() {
    try {
      // 计算音符总数
      int tapNum = _tapCp + _tapP + _tapG + _tapGo + _tapM;
      int holdNum = _holdCp + _holdP + _holdG + _holdGo + _holdM;
      int slideNum = _slideCp + _slideP + _slideG + _slideGo + _slideM;
      int touchNum = _touchCp + _touchP + _touchG + _touchGo + _touchM;
      int breakNum = _breakP + _break50 + _break100 + _break80 + _break60 + _break50g + _breakGo + _breakM;

      // 计算音符权重的总数
      int totalTapWeight = tapNum * tapWeight;
      int totalHoldWeight = holdNum * holdWeight;
      int totalSlideWeight = slideNum * slideWeight;
      int totalTouchWeight = touchNum * touchWeight;
      int totalBreakWeight = breakNum * breakWeight;

      int totalWeight = totalTapWeight + totalHoldWeight + totalSlideWeight + totalTouchWeight + totalBreakWeight;

      // 计算基础评价部分 满分100
      double baseTapWeight = tapWeight * (_tapCp + _tapP + _tapG * 0.80 + _tapGo * 0.50);
      double baseHoldWeight = holdWeight * (_holdCp + _holdP + _holdG * 0.80 + _holdGo * 0.50);
      double baseSlideWeight = slideWeight * (_slideCp + _slideP + _slideG * 0.80 + _slideGo * 0.50);
      double baseTouchWeight = touchWeight * (_touchCp + _touchP + _touchG * 0.80 + _touchGo * 0.50);
      double baseBreakWeight = breakWeight * (
          _breakP + (_break50 + _break100) + _break80 * 0.80 + _break60 * 0.60 + _break50g * 0.50 + _breakGo * 0.40
      );
      double baseWeight = baseTapWeight + baseHoldWeight + baseSlideWeight + baseTouchWeight + baseBreakWeight;

      // 基础部分 满分100 结果四舍五入保留四位小数
      double baseScore = (baseWeight / totalWeight) * 100;
      baseScore = double.parse(baseScore.toStringAsFixed(4));

      // 计算额外评价部分 全由break决定 满分1 结果四舍五入保留四位小数
      double extraBreakWeight = _breakP + _break100 * 0.50 + _break50 * 0.75 + 
          (_break80 + _break60 + _break50g) * 0.40 + _breakGo * 0.30;
      double extraScore = extraBreakWeight / breakNum;
      extraScore = double.parse(extraScore.toStringAsFixed(4));

      // 最终达成率
      double totalScore = baseScore + extraScore;
      totalScore = double.parse(totalScore.toStringAsFixed(4));

      // 计算单个普通note的判定损失
      double singleTapGreatLoss = double.parse((0.20 * 100.00 * tapWeight / totalWeight).toStringAsFixed(4)) ;
      double singleTapGoodLoss = double.parse((0.50 * 100.00 * tapWeight / totalWeight).toStringAsFixed(4));
      double singleTapMissLoss = double.parse((1.00 * 100.00 * tapWeight / totalWeight).toStringAsFixed(4));
      double singleHoldGreatLoss = double.parse((0.20 * 100.00 * holdWeight / totalWeight).toStringAsFixed(4));
      double singleHoldGoodLoss = double.parse((0.50 * 100.00 * holdWeight / totalWeight).toStringAsFixed(4));
      double singleHoldMissLoss = double.parse((1.00 * 100.00 * holdWeight / totalWeight).toStringAsFixed(4));
      double singleSlideGreatLoss = double.parse((0.20 * 100.00 * slideWeight / totalWeight).toStringAsFixed(4));
      double singleSlideGoodLoss = double.parse((0.50 * 100.00 * slideWeight / totalWeight).toStringAsFixed(4));
      double singleSlideMissLoss = double.parse((1.00 * 100.00 * slideWeight / totalWeight).toStringAsFixed(4));
      double singleTouchGreatLoss = double.parse((0.20 * 100.00 * touchWeight / totalWeight).toStringAsFixed(4));
      double singleTouchGoodLoss = double.parse((0.50 * 100.00 * touchWeight / totalWeight).toStringAsFixed(4));
      double singleTouchMissLoss = double.parse((1.00 * 100.00 * touchWeight / totalWeight).toStringAsFixed(4));

      // 显示结果
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('计算结果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('基础达成率: $baseScore%'),
              Text('奖励达成率: $extraScore%'),
              Text('总达成率: $totalScore%'),
              Text('单个TAP的判定损失:'),
              Text('GREAT: $singleTapGreatLoss%'),
              Text('GOOD: $singleTapGoodLoss%'),
              Text('MISS: $singleTapMissLoss%'),
              Text('单个HOLD的判定损失:'),
              Text('GREAT: $singleHoldGreatLoss%'),
              Text('GOOD: $singleHoldGoodLoss%'),
              Text('MISS: $singleHoldMissLoss%'),
              Text('单个SLIDE的判定损失:'),
              Text('GREAT: $singleSlideGreatLoss%'),
              Text('GOOD: $singleSlideGoodLoss%'),
              Text('MISS: $singleSlideMissLoss%'),
              Text('单个TOUCH的判定损失:'),
              Text('GREAT: $singleTouchGreatLoss%'),
              Text('GOOD: $singleTouchGoodLoss%'),
              Text('MISS: $singleTouchMissLoss%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      // 处理除数为0的异常
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('错误'),
          content: const Text('计算失败：除数不能为0，请确保至少有一个音符输入'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

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
    
    _breakPController = TextEditingController(text: _breakP.toString());
    _break50Controller = TextEditingController(text: _break50.toString());
    _break100Controller = TextEditingController(text: _break100.toString());
    _break80Controller = TextEditingController(text: _break80.toString());
    _break60Controller = TextEditingController(text: _break60.toString());
    _break50gController = TextEditingController(text: _break50g.toString());
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
    
    _breakPController.dispose();
    _break50Controller.dispose();
    _break100Controller.dispose();
    _break80Controller.dispose();
    _break60Controller.dispose();
    _break50gController.dispose();
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
    int totalCp = _tapCp + _holdCp + _slideCp + _touchCp;
    int totalP = _tapP + _holdP + _slideP + _touchP;
    int totalG = _tapG + _holdG + _slideG + _touchG;
    int totalGo = _tapGo + _holdGo + _slideGo + _touchGo;
    int totalM = _tapM + _holdM + _slideM + _touchM;
    
    // 自定义常量
    final Color textPrimaryColor = Color.fromARGB(255, 84, 97, 97);
    final double borderRadiusSmall = 8.0;
    final BoxShadow defaultShadow = BoxShadow(
      color: Colors.grey.withOpacity(0.5),
      spreadRadius: 2,
      blurRadius: 5,
      offset: Offset(0, 3),
    );

    return Scaffold(
      backgroundColor: Colors.transparent, // 透明背景
      resizeToAvoidBottomInset: false, // 防止键盘弹出时挤压背景
      body: Stack(
        children: [
          // 背景
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          // 页面内容
          Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '达成率计算器',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 占位，保持标题居中
                    SizedBox(width: 48),
                  ],
                ),
              ),

              // 主内容区域
              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [defaultShadow],
                  ),
                  child: Column(
                    children: [
                      // 可滚动内容区域
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(screenWidth * 0.04), // padding 为屏幕宽度的4%
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 普通音符表格
                              _buildSectionTitle('普通音符'),
                              _buildNormalNoteTable(totalCp, totalP, totalG, totalGo, totalM),
                              SizedBox(height: screenHeight * 0.03), // 间距为屏幕高度的3%

                              // BREAK音符区域
                              _buildSectionTitle('BREAK音符'),
                              _buildBreakNoteSection(),
                              SizedBox(height: screenHeight * 0.03), // 间距为屏幕高度的3%
                            ],
                          ),
                        ),
                      ),

                      // 计算按钮
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.03),
                        child: ElevatedButton(
                          onPressed: _calculateAchievementRate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02), // 垂直 padding 为屏幕高度的2%
                            textStyle: TextStyle(
                              fontSize: screenWidth * 0.05, // 字体大小为屏幕宽度的5%
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            elevation: 5,
                          ),
                          child: const Text('计算达成率'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      border: TableBorder( // 调整边框样式，确保颜色完全填充
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
            _buildTableCell('CRITICAL\nPERFECT', color: Colors.yellow[200]!, fontSize: 8.5),
            _buildTableCell('PERFECT', color: Colors.yellow[400]!, fontSize: 9),
            _buildTableCell('GREAT', color: Colors.pink[200]!, fontSize: 10),
            _buildTableCell('GOOD', color: Colors.green[200]!, fontSize: 10),
            _buildTableCell('MISS', color: Colors.grey[200]!, fontSize: 10),
          ],
        ),
        // TAP行
        TableRow(
          decoration: const BoxDecoration(), // 确保行没有额外装饰
          children: [
            _buildTableCell('TAP', color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(_tapCp, (val) => setState(() => _tapCp = val), _tapCpController, color: Colors.yellow[200]),
            _buildNumberInputCell(_tapP, (val) => setState(() => _tapP = val), _tapPController, color: Colors.yellow[400]),
            _buildNumberInputCell(_tapG, (val) => setState(() => _tapG = val), _tapGController, color: Colors.pink[200]),
            _buildNumberInputCell(_tapGo, (val) => setState(() => _tapGo = val), _tapGoController, color: Colors.green[200]),
            _buildNumberInputCell(_tapM, (val) => setState(() => _tapM = val), _tapMController, color: Colors.grey[200]),
          ],
        ),
        // HOLD行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('HOLD', color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(_holdCp, (val) => setState(() => _holdCp = val), _holdCpController, color: Colors.yellow[200]),
            _buildNumberInputCell(_holdP, (val) => setState(() => _holdP = val), _holdPController, color: Colors.yellow[400]),
            _buildNumberInputCell(_holdG, (val) => setState(() => _holdG = val), _holdGController, color: Colors.pink[200]),
            _buildNumberInputCell(_holdGo, (val) => setState(() => _holdGo = val), _holdGoController, color: Colors.green[200]),
            _buildNumberInputCell(_holdM, (val) => setState(() => _holdM = val), _holdMController, color: Colors.grey[200]),
          ],
        ),
        // SLIDE行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('SLIDE', color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(_slideCp, (val) => setState(() => _slideCp = val), _slideCpController, color: Colors.yellow[200]),
            _buildNumberInputCell(_slideP, (val) => setState(() => _slideP = val), _slidePController, color: Colors.yellow[400]),
            _buildNumberInputCell(_slideG, (val) => setState(() => _slideG = val), _slideGController, color: Colors.pink[200]),
            _buildNumberInputCell(_slideGo, (val) => setState(() => _slideGo = val), _slideGoController, color: Colors.green[200]),
            _buildNumberInputCell(_slideM, (val) => setState(() => _slideM = val), _slideMController, color: Colors.grey[200]),
          ],
        ),
        // TOUCH行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('TOUCH', color: Colors.lightBlue[100]!, fontSize: 11.2),
            _buildNumberInputCell(_touchCp, (val) => setState(() => _touchCp = val), _touchCpController, color: Colors.yellow[200]),
            _buildNumberInputCell(_touchP, (val) => setState(() => _touchP = val), _touchPController, color: Colors.yellow[400]),
            _buildNumberInputCell(_touchG, (val) => setState(() => _touchG = val), _touchGController, color: Colors.pink[200]),
            _buildNumberInputCell(_touchGo, (val) => setState(() => _touchGo = val), _touchGoController, color: Colors.green[200]),
            _buildNumberInputCell(_touchM, (val) => setState(() => _touchM = val), _touchMController, color: Colors.grey[200]),
          ],
        ),
        // 总计行
        TableRow(
          decoration: const BoxDecoration(),
          children: [
            _buildTableCell('总计', color: Colors.lightBlue[100]!, fontSize: 11.2),
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

  // 构建BREAK音符区域
  Widget _buildBreakNoteSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Column(
      children: [
        // Perfect部分
        Container(
          color: Colors.yellow[400],
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01), // 垂直 padding 为屏幕高度的1%
          child: Text(
            'Perfect',
            style: TextStyle(
              fontSize: screenWidth * 0.027, // 字体大小为屏幕宽度的2.7%
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        _buildBreakRow('大P', _breakP, (val) => setState(() => _breakP = val), _breakPController),
        _buildBreakRow('50落', _break50, (val) => setState(() => _break50 = val), _break50Controller),
        _buildBreakRow('100落', _break100, (val) => setState(() => _break100 = val), _break100Controller),
        SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%

        // Great部分
        Container(
          color: Colors.pink[200],
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01), // 垂直 padding 为屏幕高度的1%
          child: Text(
            'Great',
            style: TextStyle(
              fontSize: screenWidth * 0.027, // 字体大小为屏幕宽度的2.7%
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ),
        _buildBreakRow('80%', _break80, (val) => setState(() => _break80 = val), _break80Controller),
        _buildBreakRow('60%', _break60, (val) => setState(() => _break60 = val), _break60Controller),
        _buildBreakRow('50%', _break50g, (val) => setState(() => _break50g = val), _break50gController),
        SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%

        // GOOD和MISS
        _buildBreakRow('GOOD', _breakGo, (val) => setState(() => _breakGo = val), _breakGoController,
            color: Colors.green[200]),
        _buildBreakRow('MISS', _breakM, (val) => setState(() => _breakM = val), _breakMController,
            color: Colors.grey[200]),
        SizedBox(height: screenHeight * 0.02), // 间距为屏幕高度的2%

        // Break总数
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.blue[100],
                padding: EdgeInsets.all(screenWidth * 0.03), // padding 为屏幕宽度的3%
                child: Text(
                  'Break总数:',
                  style: TextStyle(
                    fontSize: screenWidth * 0.024, // 字体大小为屏幕宽度的2.4%
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02, // 水平 padding 为屏幕宽度的2%
                  vertical: screenHeight * 0.015, // 垂直 padding 为屏幕高度的1.5%
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.white,
                ),
                child: Text(
                  (_breakP + _break50 + _break100 + _break80 + _break60 + _break50g + _breakGo + _breakM).toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: screenWidth * 0.03, // 字体大小为屏幕宽度的3%
                  ),
                ),
              ),
            ),
          ],
        ),
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
  Widget _buildNumberInputCell(int value, Function(int) onChanged, TextEditingController controller, {Color? color}) {
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
        },
        onEditingComplete: () {
          // 只在失去焦点时补0
          if (controller.text.isEmpty) {
            controller.text = '0';
            onChanged(0);
          }
        },
      ),
    );
  }

  // 构建BREAK音符行
  Widget _buildBreakRow(String label, int value, Function(int) onChanged, TextEditingController controller,
      {Color? color}) {
    final screenWidth = MediaQuery.of(context).size.width;
    //final screenHeight = MediaQuery.of(context).size.height;
    
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            color: color ?? Colors.yellow[100],
            padding: EdgeInsets.all(screenWidth * 0.03), // padding 为屏幕宽度的3%
            child: Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.024, // 字体大小为屏幕宽度的2.4%
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02), // 水平 padding 为屏幕宽度的2%
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: value == 0 ? '' : value.toString(),
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
              },
              onEditingComplete: () {
                // 只在失去焦点时补0
                if (controller.text.isEmpty) {
                  controller.text = '0';
                  onChanged(0);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}