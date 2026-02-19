import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SingleRatingCalculator extends StatefulWidget {
  const SingleRatingCalculator({super.key});

  @override
  State<SingleRatingCalculator> createState() => _SingleRatingCalculatorState();
}

class _SingleRatingCalculatorState extends State<SingleRatingCalculator> {
  // 输入控制器
  late TextEditingController _difficultyController;
  late TextEditingController _completionController;

  // 计算结果
  String _rating = '';
  double _singleRating = 0.0;
  double _multiplier = 0.0;
  bool _showResults = false;

  // 舞萌DX 完成度-评级-乘数对照表
  final List<Map<String, dynamic>> maimaiRatingMultiplier = [
    {"completion": 100.5, "rating": "SSS+", "multiplier": 0.224},
    {"completion": 100.4999, "rating": "SSS", "multiplier": 0.222},
    {"completion": 100.0, "rating": "SSS", "multiplier": 0.216},
    {"completion": 99.9999, "rating": "SS+", "multiplier": 0.214},
    {"completion": 99.5, "rating": "SS+", "multiplier": 0.211},
    {"completion": 99.0, "rating": "SS", "multiplier": 0.208},
    {"completion": 98.9999, "rating": "S+", "multiplier": 0.206},
    {"completion": 98.0, "rating": "S+", "multiplier": 0.203},
    {"completion": 97.0, "rating": "S", "multiplier": 0.2},
    {"completion": 96.9999, "rating": "AAA", "multiplier": 0.176},
    {"completion": 94.0, "rating": "AAA", "multiplier": 0.168},
    {"completion": 90.0, "rating": "AA", "multiplier": 0.152},
    {"completion": 80.0, "rating": "A", "multiplier": 0.136},
    {"completion": 79.9999, "rating": "BBB", "multiplier": 0.128},
    {"completion": 75.0, "rating": "BBB", "multiplier": 0.120},
    {"completion": 70.0, "rating": "BB", "multiplier": 0.112},
    {"completion": 60.0, "rating": "B", "multiplier": 0.096},
    {"completion": 50.0, "rating": "C", "multiplier": 0.08},
    {"completion": 40.0, "rating": "D", "multiplier": 0.064},
    {"completion": 30.0, "rating": "D", "multiplier": 0.048},
    {"completion": 20.0, "rating": "D", "multiplier": 0.032},
    {"completion": 10.0, "rating": "D", "multiplier": 0.016},
  ];

  @override
  void initState() {
    super.initState();
    _difficultyController = TextEditingController();
    _completionController = TextEditingController();
  }

  @override
  void dispose() {
    _difficultyController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  // 计算单曲Rating
  void _calculateSingleRating() {
    try {
      double difficulty = double.tryParse(_difficultyController.text) ?? 0.0;
      double completion = double.tryParse(_completionController.text) ?? 0.0;

      // 验证输入范围
      if (difficulty < 1.0 || difficulty > 15.0) {
        _showError('歌曲定数必须在1.0到15.0之间');
        return;
      }

      if (completion < 0 || completion > 101) {
        _showError('达成率必须在0到101之间');
        return;
      }

      // 特别处理：如果达成率大于100.5，则按100.5计算
      double adjustedCompletion = completion > 100.5 ? 100.5 : completion;
      double calculationCompletion = completion > 100.5 ? 100.5 : completion;

      // 查找对应的评级和乘数
      Map<String, dynamic>? selectedRating;
      
      // 遍历表格查找正确的区间
      for (var item in maimaiRatingMultiplier) {
        if (adjustedCompletion >= item['completion']) {
          selectedRating = item;
          break;
        }
      }
      
      // 如果没有找到（不应该发生），使用默认值
      selectedRating ??= {"rating": "D", "multiplier": 0.016};

      String rating = selectedRating['rating'];
      double multiplier = selectedRating['multiplier'];

      // 计算单曲Rating
      double singleRating = difficulty * multiplier * calculationCompletion;
      singleRating = singleRating.floorToDouble(); // 取整数部分（向下取整）

      setState(() {
        _rating = rating;
        _multiplier = multiplier;
        _singleRating = singleRating;
        _showResults = true;
      });
    } catch (e) {
      _showError('计算失败，请检查输入');
    }
  }

  // 显示错误对话框
  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            // 层级1：基础背景图 - 占满整个屏幕，作为页面最底层背景
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                  opacity: 1.0,
                ),
              ),
            ),

            // 层级2：第一张虚化装饰图 - 居中显示，轻微向上偏移
            Center(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Transform.scale(
                  scale: 1,
                  child: Image.asset(
                    'assets/chiffon2.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(1),
                  ),
                ),
              ),
            ),

            // 页面标题
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "单曲Rating计算",
                  style: TextStyle(
                    color: Color.fromARGB(255, 84, 97, 97),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),

            // 返回按钮
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 84, 97, 97), size: 24),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),

            // 主要内容区域 - 使用SingleChildScrollView实现滚动
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              bottom: 20,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // 第一个白色区域：输入和结果
                    Container(
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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 歌曲定数输入
                            const Text(
                              '歌曲定数（1.0-15.0）',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _difficultyController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
                              ],
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '请输入歌曲定数',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 达成率输入
                            const Text(
                              '达成率（%）',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _completionController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                              ],
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '请输入达成率',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 预留的深色结果区域
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('计算结果',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('评级:', style: TextStyle(color: Colors.white)),
                                      Text(
                                        _showResults ? _rating : '-',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('乘数:', style: TextStyle(color: Colors.white)),
                                      Text(
                                        _showResults ? _multiplier.toString() : '-',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('单曲Rating:', style: TextStyle(color: Colors.white)),
                                      Text(
                                        _showResults ? _singleRating.toString() : '-',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 计算按钮 - 放到第一个白色区域的最下方
                            ElevatedButton(
                              onPressed: _calculateSingleRating,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                elevation: 5,
                              ),
                              child: const Text('计算Rating'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 第二个白色区域：评级对照表
                    Container(
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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 计算公式
                            const Text(
                              '单曲Rating = 定数 * 乘数 * 达成率',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Text(
                              '（保留整数部分）',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // 表格
                            Table(
                              border: TableBorder.all(color: Colors.grey),
                              children: [
                                // 表头
                                const TableRow(
                                  children: [
                                    TableCell(
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          '完成度',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          '评级',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          '乘数',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // 表格内容
                                ...maimaiRatingMultiplier.map((item) {
                                  return TableRow(
                                    children: [
                                      TableCell(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            item['completion'].toString(),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      TableCell(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            item['rating'],
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      TableCell(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            item['multiplier'].toString(),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}