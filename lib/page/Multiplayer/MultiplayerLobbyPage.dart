import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomCreatePage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomJoinPage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/GameRoomPage.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';

class MultiplayerLobbyPage extends StatefulWidget {
  const MultiplayerLobbyPage({super.key});

  @override
  State<MultiplayerLobbyPage> createState() => _MultiplayerLobbyPageState();
}

class _MultiplayerLobbyPageState extends State<MultiplayerLobbyPage> {
  final MultiplayerManager _manager = MultiplayerManager();
  List<RoomEntity> _rooms = [];
  bool _isLoading = true;
  
  // Stream 订阅引用，用于在 dispose 时取消订阅
  StreamSubscription? _roomListSubscription;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    
    _roomListSubscription = _manager.roomListStream.listen((rooms) {
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      _rooms = await _manager.getRoomList();
    } catch (e) {
      print('加载房间列表失败: $e');
    }
    setState(() => _isLoading = false);
  }

  void _handleCreateRoom() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoomCreatePage()),
    );
    
    if (result != null && result is RoomEntity) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GameRoomPage(room: result)),
      );
    }
  }

  void _handleJoinRoom() async {
    final roomId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoomJoinPage()),
    );
    
    if (roomId != null && roomId is String) {
      RoomEntity? room = await _manager.joinRoom(roomId);
      if (room != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GameRoomPage(room: room)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加入房间失败')),
        );
      }
    }
  }

  void _handleRoomTap(RoomEntity room) async {
    RoomEntity? joinedRoom = await _manager.joinRoom(room.roomId);
    if (joinedRoom != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GameRoomPage(room: joinedRoom)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加入房间失败')),
      );
    }
  }

  Widget _buildRoomCard(RoomEntity room, double scaleFactor) {
    return GestureDetector(
      onTap: () => _handleRoomTap(room),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8 * scaleFactor),
        padding: EdgeInsets.all(12 * scaleFactor),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8 * scaleFactor),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3.0 * scaleFactor,
              offset: Offset(1.0 * scaleFactor, 1.0 * scaleFactor),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  room.roomId,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 84, 97, 97)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: room.status == RoomStatus.waiting
                        ? Colors.green[100]
                        : room.status == RoomStatus.playing
                            ? Colors.blue[100]
                            : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    room.status.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: room.status == RoomStatus.waiting
                          ? Colors.green[700]
                          : room.status == RoomStatus.playing
                              ? Colors.blue[700]
                              : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${room.players.length}/${room.maxPlayers} 玩家'),
                const SizedBox(width: 16),
                const Icon(Icons.timer, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${room.timeLimit}秒'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '游戏模式: ${_getGameTypeName(room.gameType)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _getGameTypeName(dynamic gameType) {
    if (gameType is String) {
      switch (gameType) {
        case 'info':
          return '信息猜歌';
        case 'cover':
          return '封面猜歌';
        case 'blurred':
          return '模糊猜歌';
        case 'audio':
          return '音频猜歌';
        case 'alia':
          return '歌词猜歌';
        case 'letters':
          return '字母猜歌';
        default:
          return '默认模式';
      }
    }
    return '默认模式';
  }

  @override
  void dispose() {
    // 取消 Stream 订阅，防止内存泄漏
    _roomListSubscription?.cancel();
    super.dispose();
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
                          '多人游戏大厅',
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
                  child: RefreshIndicator(
                    onRefresh: _loadRooms,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(paddingM),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _handleCreateRoom,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 84, 97, 97),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: const Text('创建房间', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              SizedBox(width: paddingM),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _handleJoinRoom,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: Color.fromARGB(255, 84, 97, 97)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: const Text('加入房间', style: TextStyle(color: Color.fromARGB(255, 84, 97, 97))),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: paddingL * 1.5),
                          if (_isLoading)
                            const Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator()))
                          else if (_rooms.isEmpty)
                            const Center(child: Text('暂无房间，快来创建一个吧!'))
                          else
                            ..._rooms.map((room) => _buildRoomCard(room, scaleFactor)),
                        ],
                      ),
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