import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/GameType.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

class RoomCreatePage extends StatefulWidget {
  const RoomCreatePage({super.key});

  @override
  State<RoomCreatePage> createState() => _RoomCreatePageState();
}

class _RoomCreatePageState extends State<RoomCreatePage> {
  final MultiplayerManager _manager = MultiplayerManager();
  // 只支持无提示猜歌模式
  final GameType _gameType = GameType.info;
  int _maxPlayers = 4;
  int _timeLimit = 60;
  int _maxGuesses = 10;
  bool _isCreating = false;

  Future<void> _handleCreateRoom() async {
    if (_isCreating) return;
    
    setState(() => _isCreating = true);
    
    try {
      final room = await _manager.createRoom(
        gameType: _gameType,
        maxPlayers: _maxPlayers,
        timeLimit: _timeLimit,
        maxGuesses: _maxGuesses,
      );
      
      if (room != null) {
        Navigator.pop(context, room);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建房间失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建房间失败: $e')),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375.0;
    final paddingS = 8.0 * scaleFactor;
    final paddingM = 12.0 * scaleFactor;
    final paddingL = 16.0 * scaleFactor;
    final borderRadiusSmall = 8.0 * scaleFactor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
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
                padding: EdgeInsets.fromLTRB(paddingM, 48, paddingM, paddingS),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Color.fromARGB(255, 84, 97, 97)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Center(
                        child: Text(
                          '创建房间',
                          style: TextStyle(
                            color: Color.fromARGB(255, 84, 97, 97),
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
                  margin: EdgeInsets.fromLTRB(paddingS, 0, paddingS, paddingL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5.0 * scaleFactor,
                        offset: Offset(2.0 * scaleFactor, 2.0 * scaleFactor),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(paddingM),
                    child: Column(
                      children: [
                        Text(
                          '游戏模式',
                          style: TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: paddingM),
                        // 固定显示无提示猜歌模式
                        Container(
                          padding: EdgeInsets.all(paddingM),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 84, 97, 97),
                            borderRadius: BorderRadius.circular(borderRadiusSmall),
                          ),
                          child: Text(
                            '无提示猜歌',
                            style: TextStyle(color: Colors.white, fontSize: 18 * scaleFactor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(height: paddingL * 1.5),
                        Text(
                          '房间设置',
                          style: TextStyle(fontSize: 16 * scaleFactor, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: paddingM),
                        Container(
                          padding: EdgeInsets.all(paddingM),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(borderRadiusSmall),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('最大玩家数', style: TextStyle(fontSize: 14 * scaleFactor))),
                                  DropdownButton<int>(
                                    value: _maxPlayers,
                                    items: [2, 3, 4, 5, 6].map((value) {
                                      return DropdownMenuItem(
                                        value: value,
                                        child: Text('$value 人', style: TextStyle(fontSize: 14 * scaleFactor)),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(() => _maxPlayers = value!),
                                  ),
                                ],
                              ),
                              SizedBox(height: paddingM),
                              Row(
                                children: [
                                  Expanded(child: Text('时间限制', style: TextStyle(fontSize: 14 * scaleFactor))),
                                  DropdownButton<int>(
                                    value: _timeLimit,
                                    items: [30, 45, 60, 90, 120].map((value) {
                                      return DropdownMenuItem(
                                        value: value,
                                        child: Text('$value 秒', style: TextStyle(fontSize: 14 * scaleFactor)),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(() => _timeLimit = value!),
                                  ),
                                ],
                              ),
                              SizedBox(height: paddingM),
                              Row(
                                children: [
                                  Expanded(child: Text('最大猜测次数', style: TextStyle(fontSize: 14 * scaleFactor))),
                                  DropdownButton<int>(
                                    value: _maxGuesses,
                                    items: [5, 10, 15, 20].map((value) {
                                      return DropdownMenuItem(
                                        value: value,
                                        child: Text('$value 次', style: TextStyle(fontSize: 14 * scaleFactor)),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(() => _maxGuesses = value!),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: paddingL * 1.5),
                        ElevatedButton(
                          onPressed: _handleCreateRoom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 84, 97, 97),
                            padding: EdgeInsets.symmetric(vertical: 16 * scaleFactor),
                            minimumSize: Size(double.infinity, 50 * scaleFactor),
                          ),
                          child: _isCreating
                              ? SizedBox(width: 24 * scaleFactor, height: 24 * scaleFactor, child: CircularProgressIndicator(color: Colors.white))
                              : Text('创建房间', style: TextStyle(color: Colors.white, fontSize: 16 * scaleFactor)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}