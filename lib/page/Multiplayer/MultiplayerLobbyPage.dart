import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/manager/MultiplayerManager.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomCreatePage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/RoomJoinPage.dart';
import 'package:my_first_flutter_app/page/Multiplayer/GameRoomPage.dart';
import 'package:my_first_flutter_app/utils/CommonWidgetUtil.dart';
import 'package:my_first_flutter_app/utils/AppConstants.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/RoomEntity.dart';

class MultiplayerLobbyPage extends StatefulWidget {
  const MultiplayerLobbyPage({super.key, this.manager});

  /// 可注入的管理器（默认用单例）。
  ///
  /// 存在的意义是可测：这个页面一进来就会 `initialize()`（为了把断线宽限期内的
  /// 原座位要回来），而那条链路会连 WebSocket、留下心跳/重连/超时定时器 ——
  /// widget test 的 fake async 收不掉它们。测试注入一个不联网的实现即可。
  final MultiplayerManager? manager;

  @override
  State<MultiplayerLobbyPage> createState() => _MultiplayerLobbyPageState();
}

class _MultiplayerLobbyPageState extends State<MultiplayerLobbyPage> {
  late final MultiplayerManager _manager = widget.manager ?? MultiplayerManager();
  bool _isCreating = false;
  bool _isJoining = false;
  bool _returning = false;
  StreamSubscription<RoomEntity?>? _roomSubscription;

  @override
  void initState() {
    super.initState();
    // 进大厅就连一次：进程被杀后重开时，只有连上并带本机身份 initialize，
    // 服务端才可能把我们接回断线宽限期内的原座位（见 MultiplayerManager.currentRoom）。
    _tryResumeRoom();
    _roomSubscription = _manager.roomStream.listen((room) {
      if (!mounted) return;
      // 房间出现 / 消失都要刷新：出现时显示「回到房间」入口，
      // 消失（宽限期过了、被踢、房间散了）时把入口收掉。
      setState(() {});
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  Future<void> _tryResumeRoom() async {
    try {
      await _manager.initialize();
      if (!mounted) return;
      // initialize 之前可能已经推过 room_joined（那时还没订阅），这里补一次刷新
      setState(() {});
    } catch (e) {
      debugPrint('[MultiplayerLobby] 初始化连接失败（忽略，用户仍可建房/加入）: $e');
    }
  }

  void _enterRoom(RoomEntity room) {
    if (_returning) return;
    _returning = true;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameRoomPage(room: room)),
    ).whenComplete(() => _returning = false);
  }

  /// 建房/加入之前先把还留着的旧座位退掉，否则服务端会同时记着两个房间
  /// （旧房间里留下一个不再操作的「幽灵座位」）。
  Future<void> _leaveResidualRoom() async {
    if (_manager.currentRoom == null) return;
    await _manager.leaveRoom();
  }

  void _handleCreateRoom() async {
    if (_isCreating) return;
    
    setState(() => _isCreating = true);
    await _leaveResidualRoom();
    if (!mounted) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoomCreatePage()),
    );
    if (!mounted) return;
    
    setState(() => _isCreating = false);
    
    if (result != null && result is RoomEntity) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GameRoomPage(room: result)),
      );
    }
  }

  void _handleJoinRoom() async {
    if (_isJoining) return;
    
    setState(() => _isJoining = true);
    await _leaveResidualRoom();
    if (!mounted) return;
    
    final roomId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoomJoinPage()),
    );
    if (!mounted) return;
    
    setState(() => _isJoining = false);
    
    if (roomId != null && roomId is String) {
      RoomEntity? room = await _manager.joinRoom(roomId);
      if (!mounted) return;
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

  /// 「你还在房间 XXXXXX 里，点击返回」——进程被杀后重开时用得上：
  /// 服务端在断线宽限期（120s）内还留着我们的座位，重连后被接了回去，
  /// 但界面上一局已经没了，得给一个明确的入口（不自动跳，避免吓人）。
  Widget _buildReturnRoomBanner(RoomEntity room) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375.0;
    final paddingM = 12.0 * scaleFactor;
    final borderRadius = 8.0 * scaleFactor;

    return Padding(
      padding: EdgeInsets.only(bottom: paddingM),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: () => _enterRoom(room),
          child: Padding(
            padding: EdgeInsets.all(paddingM),
            child: Row(
              children: [
                Icon(Icons.meeting_room_outlined,
                    color: scheme.onPrimaryContainer, size: 22 * scaleFactor),
                SizedBox(width: paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '你还在房间 ${room.roomCode} 里',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 15 * scaleFactor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2 * scaleFactor),
                      Text(
                        '${room.gameType.name} · ${room.players.length} 人 · 点击返回',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                          fontSize: 12.5 * scaleFactor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onPrimaryContainer, size: 22 * scaleFactor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375.0;
    final paddingS = 4.0 * scaleFactor;
    final paddingM = 12.0 * scaleFactor;
    final paddingL = 10.0 * scaleFactor;
    final borderRadiusSmall = 8.0 * scaleFactor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),

          Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(paddingM, 48, paddingM, paddingL),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '多人游戏',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: screenWidth * 0.06,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  margin: EdgeInsets.fromLTRB(paddingS, 0, paddingS, paddingL),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                    boxShadow: [AppConstants.defaultShadow(brightness)],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(paddingM),
                    child: Column(
                      children: [
                        // 还在房间里（切后台/被杀重开后被服务端接回座位）→ 给一个返回入口
                        if (_manager.currentRoom != null)
                          _buildReturnRoomBanner(_manager.currentRoom!),

                        SizedBox(height: screenHeight * 0.15),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 150 * scaleFactor,
                          child: ElevatedButton(
                            onPressed: _handleCreateRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadiusSmall),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_box, size: 48 * scaleFactor, color: Theme.of(context).colorScheme.onPrimary),
                                SizedBox(height: paddingM),
                                Text(
                                  '创建房间',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: paddingL),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 150 * scaleFactor,
                          child: ElevatedButton(
                            onPressed: _handleJoinRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadiusSmall),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_add, size: 48 * scaleFactor, color: Theme.of(context).colorScheme.primary),
                                SizedBox(height: paddingM),
                                Text(
                                  '加入房间',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  double get screenHeight => MediaQuery.of(context).size.height;
}