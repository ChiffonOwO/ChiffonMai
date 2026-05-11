import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

// 消息回调类型
typedef MessageCallback = void Function(Map<String, dynamic> message);

class WebSocketBroadcastService {
  static final WebSocketBroadcastService _instance = WebSocketBroadcastService._internal();
  factory WebSocketBroadcastService() => _instance;
  WebSocketBroadcastService._internal();

  WebSocketChannel? _channel;
  final Map<String, List<MessageCallback>> _listeners = {};
  bool _isConnected = false;
  String? _currentPlayerId;
  
  // 心跳相关
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  DateTime? _lastHeartbeatReceived;
  static const int _heartbeatInterval = 30; // 心跳间隔（秒）- 增加到30秒
  static const int _heartbeatTimeout = 90; // 心跳超时时间（秒）- 增加到90秒
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  
  // 保存连接信息用于重连
  String? _host;
  String? _appkey;
  String? _username;

  // 获取当前玩家ID
  String? get currentPlayerId => _currentPlayerId;

  Future<void> initialize({
    required String host,
    String appkey = '',
    String? username,
  }) async {
    // 保存连接信息用于重连
    _host = host;
    _appkey = appkey;
    _username = username;
    
    if (_isConnected) {
      print('[WebSocket] 已连接，跳过初始化');
      return;
    }

    try {
      // 构建 WebSocket URL
      // 如果是 http/https URL，转换为 ws/wss
      String wsUrl = host;
      if (host.startsWith('http://')) {
        wsUrl = 'ws://' + host.substring(7);
      } else if (host.startsWith('https://')) {
        wsUrl = 'wss://' + host.substring(8);
      } else if (!host.startsWith('ws://') && !host.startsWith('wss://')) {
        wsUrl = 'wss://' + host;
      }
      
      print('[WebSocket] 连接到: $wsUrl');
      
      final url = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(url);
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('[WebSocket] 错误: $error');
          _isConnected = false;
          _stopHeartbeat();
          _scheduleReconnect();
        },
        onDone: () {
          print('[WebSocket] 连接关闭');
          _isConnected = false;
          _stopHeartbeat();
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      print('[WebSocket] 连接成功');
      
      // 启动心跳
      _startHeartbeat();
    } catch (e) {
      print('[WebSocket] 初始化失败: $e');
      rethrow;
    }
  }
  
  // 启动心跳定时器
  void _startHeartbeat() {
    _stopHeartbeat();
    
    // 发送心跳消息
    _sendHeartbeat();
    
    // 设置定时发送心跳
    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatInterval), (timer) {
      _sendHeartbeat();
      
      // 检查心跳超时
      if (_lastHeartbeatReceived != null) {
        Duration elapsed = DateTime.now().difference(_lastHeartbeatReceived!);
        if (elapsed.inSeconds > _heartbeatTimeout) {
          print('[WebSocket] 心跳超时，尝试重连');
          _isConnected = false;
          _stopHeartbeat();
          _scheduleReconnect();
        }
      }
    });
  }
  
  // 停止心跳定时器
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  // 发送心跳消息
  void _sendHeartbeat() {
    if (!_isConnected || _channel == null) {
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'heartbeat',
        'payload': {},
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送心跳');
    } catch (e) {
      print('[WebSocket] 发送心跳失败: $e');
    }
  }
  
  // 调度重连（使用指数退避策略）
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[WebSocket] 已达到最大重连次数，停止尝试');
      return;
    }
    
    _reconnectTimer?.cancel();
    
    // 指数退避：第n次重连延迟为 2^n 秒，最多30秒
    int delay = (pow(2, _reconnectAttempts)).toInt();
    delay = delay > 30 ? 30 : delay;
    
    print('[WebSocket] ${delay}秒后进行第 ${_reconnectAttempts + 1} 次重连...');
    
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnect();
    });
  }
  
  // 尝试重连
  Future<void> _reconnect() async {
    _reconnectAttempts++;
    print('[WebSocket] 第 $_reconnectAttempts 次尝试重连...');
    
    try {
      // 关闭旧连接
      _channel?.sink.close(status.normalClosure);
      _channel = null;
      _isConnected = false;
      
      // 使用保存的连接信息重新初始化
      if (_host != null) {
        await initialize(
          host: _host!,
          appkey: _appkey ?? '',
          username: _username,
        );
        print('[WebSocket] 重连成功');
      } else {
        print('[WebSocket] 无法重连：没有保存连接信息');
      }
    } catch (e) {
      print('[WebSocket] 重连失败: $e');
      _scheduleReconnect();
    }
  }
  
  // 发送初始化消息
  Future<void> sendInitialize(String? nickname) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'initialize',
        'payload': {
          'nickname': nickname,
        },
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送初始化消息');
    } catch (e) {
      print('[WebSocket] 发送初始化消息失败: $e');
    }
  }
  
  // 发送创建房间消息
  Future<void> sendCreateRoom(Map<String, dynamic> options) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'create_room',
        'payload': options,
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送创建房间消息');
    } catch (e) {
      print('[WebSocket] 发送创建房间消息失败: $e');
    }
  }
  
  // 发送加入房间消息（支持房间ID或房间码）
  Future<void> sendJoinRoom(String roomId, String? nickname) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      // 添加详细的调试日志
      print('[WebSocket] 准备加入房间 - roomId: "$roomId", 长度: ${roomId.length}, nickname: "$nickname"');
      
      String data;
      
      // 判断是房间ID还是房间码
      // 房间码是6位数字，房间ID是36位UUID
      if (roomId.length == 6 && RegExp(r'^\d{6}$').hasMatch(roomId)) {
        // 使用房间码加入
        print('[WebSocket] 检测到房间码，使用 join_room_by_code 动作');
        data = json.encode({
          'action': 'join_room_by_code',
          'payload': {
            'code': roomId,
            'nickname': nickname,
          },
        });
      } else {
        // 使用房间ID加入
        data = json.encode({
          'action': 'join_room',
          'payload': {
            'roomId': roomId,
            'nickname': nickname,
          },
        });
      }
      
      _channel!.sink.add(data);
      print('[WebSocket] 发送加入房间消息成功');
    } catch (e) {
      print('[WebSocket] 发送加入房间消息失败: $e');
    }
  }
  
  // 发送更新准备状态消息
  Future<void> sendUpdateReady(bool ready) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'update_ready',
        'payload': {'ready': ready},
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送更新准备状态消息: $ready');
    } catch (e) {
      print('[WebSocket] 发送更新准备状态消息失败: $e');
    }
  }
  
  // 发送开始游戏消息
  Future<void> sendStartGame() async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'start_game',
        'payload': {},
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送开始游戏消息');
    } catch (e) {
      print('[WebSocket] 发送开始游戏消息失败: $e');
    }
  }
  
  // 发送开始下一回合消息
  Future<void> sendStartNextRound() async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'start_next_round',
        'payload': {},
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送开始下一回合消息');
    } catch (e) {
      print('[WebSocket] 发送开始下一回合消息失败: $e');
    }
  }
  
  // 发送猜测消息
  Future<void> sendGuess(String songId, String songName) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'submit_guess',
        'payload': {
          'songId': songId,
          'songName': songName,
        },
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送猜测消息: $songId');
    } catch (e) {
      print('[WebSocket] 发送猜测消息失败: $e');
    }
  }
  
  // 发送离开房间消息
  Future<void> sendLeaveRoom() async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'leave_room',
        'payload': {},
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送离开房间消息');
    } catch (e) {
      print('[WebSocket] 发送离开房间消息失败: $e');
    }
  }
  
  // 发送获取房间列表消息
  Future<void> sendGetRooms() async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'get_rooms',
        'payload': {},
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送获取房间列表消息');
    } catch (e) {
      print('[WebSocket] 发送获取房间列表消息失败: $e');
    }
  }
  
  // 发送投降消息
  Future<void> sendSurrender() async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'surrender',
        'payload': {},
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送投降消息');
    } catch (e) {
      print('[WebSocket] 发送投降消息失败: $e');
    }
  }

  // 发送上传歌曲数据消息
  Future<void> sendUploadSongs(List<Map<String, dynamic>> songs) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'upload_songs',
        'payload': {
          'songs': songs,
        },
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送上传歌曲数据消息，数量: ${songs.length}');
    } catch (e) {
      print('[WebSocket] 发送上传歌曲数据消息失败: $e');
    }
  }

  // 发送获取歌曲数量消息
  Future<void> sendGetSongCount() async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }
    
    try {
      final data = json.encode({
        'action': 'get_song_count',
        'payload': {},
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送获取歌曲数量消息');
    } catch (e) {
      print('[WebSocket] 发送获取歌曲数量消息失败: $e');
    }
  }

  void subscribe({
    required String channel,
    required MessageCallback onMessage,
  }) {
    if (!_listeners.containsKey(channel)) {
      _listeners[channel] = [];
    }
    _listeners[channel]!.add(onMessage);
    print('[WebSocket] 订阅频道: $channel');
  }

  void unsubscribe({required String channel}) {
    _listeners.remove(channel);
    print('[WebSocket] 取消订阅频道: $channel');
  }

  Future<void> publish({
    required String channel,
    required Map<String, dynamic> message,
  }) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] 未连接，无法发送消息');
      return;
    }

    try {
      final data = json.encode({
        'channel': channel,
        'event': 'broadcast',
        'data': message,
      });
      _channel!.sink.add(data);
      print('[WebSocket] 发送消息到频道 $channel: $message');
    } catch (e) {
      print('[WebSocket] 发送消息失败: $e');
    }
  }

  void _handleMessage(dynamic message) {
    try {
      print('[WebSocket] 收到消息: ${message.toString().substring(0, message.toString().length > 200 ? 200 : message.toString().length)}');
      
      final Map<String, dynamic> data = json.decode(message.toString());
      final String action = data['action'] ?? '';
      
      // 如果是初始化响应，保存玩家ID
      if (action == 'initialized') {
        _currentPlayerId = data['payload']?['playerId'];
        print('[WebSocket] 收到初始化响应，playerId: $_currentPlayerId');
      }
      
      // 处理心跳响应，更新最后收到心跳的时间
      if (action == 'heartbeat') {
        _lastHeartbeatReceived = DateTime.now();
        print('[WebSocket] 收到心跳响应');
      }
      
      // 检查是否有全局监听器
      if (_listeners.containsKey('global')) {
        print('[WebSocket] 全局监听器数量: ${_listeners['global']!.length}');
        for (final callback in _listeners['global']!) {
          callback(data);
        }
      }
      
      // 检查特定频道的监听器
      final String channel = data['channel'] ?? '';
      if (channel.isNotEmpty && _listeners.containsKey(channel)) {
        for (final callback in _listeners[channel]!) {
          callback(data['payload'] ?? {});
        }
      }
      
      // 如果没有指定频道，尝试使用action作为频道
      if (channel.isEmpty && _listeners.containsKey(action)) {
        for (final callback in _listeners[action]!) {
          callback(data['payload'] ?? {});
        }
      }
    } catch (e) {
      print('[WebSocket] 处理消息失败: $e');
    }
  }

  void disconnect() {
    // 停止所有定时器
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    _channel?.sink.close(status.normalClosure);
    _isConnected = false;
    _listeners.clear();
    print('[WebSocket] 已断开连接');
  }

  bool get isConnected => _isConnected;
}