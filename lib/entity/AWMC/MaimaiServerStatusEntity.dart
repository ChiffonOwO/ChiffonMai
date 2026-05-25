// Maimai服务器状态实体类

// 心跳记录项
class HeartbeatItem {
  final int status; // 状态码：0-离线，1-正常，2-延迟
  final String time; // 时间戳
  final String msg; // 消息
  final int? ping; // 延迟时间（毫秒）

  HeartbeatItem({
    required this.status,
    required this.time,
    required this.msg,
    this.ping,
  });

  factory HeartbeatItem.fromJson(Map<String, dynamic> json) {
    return HeartbeatItem(
      status: json['status'] ?? 0,
      time: json['time'] ?? '',
      msg: json['msg'] ?? '',
      ping: json['ping'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'time': time,
      'msg': msg,
      'ping': ping,
    };
  }

  // 获取状态文本
  String getStatusText() {
    switch (status) {
      case 0:
        return '故障';
      case 1:
        return '正常';
      case 2:
        return '重试中';
      default:
        return '未知';
    }
  }

  // 获取状态颜色
  String getStatusColor() {
    switch (status) {
      case 0:
        return '#ff0000'; // 红色
      case 1:
        return '#00ff00'; // 绿色
      case 2:
        return '#ffaa00'; // 橙色
      default:
        return '#999999'; // 灰色
    }
  }
}

// 心跳列表（服务器ID到心跳记录的映射）
class HeartbeatList {
  final Map<String, List<HeartbeatItem>> items;

  HeartbeatList(this.items);

  factory HeartbeatList.fromJson(Map<String, dynamic> json) {
    final Map<String, List<HeartbeatItem>> items = {};
    
    json.forEach((key, value) {
      if (value is List) {
        items[key] = value.map((item) => HeartbeatItem.fromJson(item)).toList();
      }
    });
    
    return HeartbeatList(items);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    
    items.forEach((key, value) {
      json[key] = value.map((item) => item.toJson()).toList();
    });
    
    return json;
  }

  // 获取指定服务器的最新心跳记录
  HeartbeatItem? getLatestHeartbeat(String serverId) {
    final serverHeartbeats = items[serverId];
    if (serverHeartbeats == null || serverHeartbeats.isEmpty) {
      return null;
    }
    return serverHeartbeats.last;
  }

  // 获取所有服务器ID
  List<String> getServerIds() {
    return items.keys.toList();
  }
}

class UpTimeList {
  final num uptime1_24;
  final num uptime4_24;
  final num uptime5_24;
  final num uptime6_24;
  final num uptime7_24;
  final num uptime8_24;
  final num uptime9_24;
  final num uptime10_24;
  final num uptime11_24;
  final num uptime12_24;
  final num uptime13_24;
  final num uptime14_24;
  final num uptime15_24;
  final num uptime16_24;
  final num uptime17_24;
  final num uptime18_24;
  
  UpTimeList(
    this.uptime1_24,
    this.uptime4_24,
    this.uptime5_24,
    this.uptime6_24,
    this.uptime7_24,
    this.uptime8_24,
    this.uptime9_24,  
    this.uptime10_24,
    this.uptime11_24,
    this.uptime12_24,
    this.uptime13_24,
    this.uptime14_24,
    this.uptime15_24,
    this.uptime16_24,
    this.uptime17_24,
    this.uptime18_24,
  );

  factory UpTimeList.fromJson(Map<String, dynamic> json) {
    return UpTimeList(
      json['1_24'] ?? 0,
      json['4_24'] ?? 0,
      json['5_24'] ?? 0,
      json['6_24'] ?? 0,
      json['7_24'] ?? 0,
      json['8_24'] ?? 0,
      json['9_24'] ?? 0,
      json['10_24'] ?? 0,
      json['11_24'] ?? 0,
      json['12_24'] ?? 0,
      json['13_24'] ?? 0,
      json['14_24'] ?? 0,
      json['15_24'] ?? 0,
      json['16_24'] ?? 0,
      json['17_24'] ?? 0,
      json['18_24'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uptime1_24': uptime1_24,
      'uptime4_24': uptime4_24,
      'uptime5_24': uptime5_24,
      'uptime6_24': uptime6_24,
      'uptime7_24': uptime7_24,
      'uptime8_24': uptime8_24,
      'uptime9_24': uptime9_24,
      'uptime10_24': uptime10_24,
      'uptime11_24': uptime11_24,
      'uptime12_24': uptime12_24,
      'uptime13_24': uptime13_24,
      'uptime14_24': uptime14_24,
      'uptime15_24': uptime15_24,
      'uptime16_24': uptime16_24,
      'uptime17_24': uptime17_24,
      'uptime18_24': uptime18_24,
    };
  }
   
}

// 主服务器状态实体类
class MaimaiServerStatusEntity {
  final HeartbeatList heartbeatList;
  final UpTimeList uptimeList;

  MaimaiServerStatusEntity(this.heartbeatList, this.uptimeList);

  factory MaimaiServerStatusEntity.fromJson(Map<String, dynamic> json) {
    return MaimaiServerStatusEntity(
      HeartbeatList.fromJson(json['heartbeatList'] ?? {}),
      UpTimeList.fromJson(json['uptimeList'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heartbeatList': heartbeatList.toJson(),
      'uptimeList': uptimeList.toJson(),
    };
  }
}