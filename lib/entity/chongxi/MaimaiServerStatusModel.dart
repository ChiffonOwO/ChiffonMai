// mai.chongxi.us/api/bot 返回的舞萌服务器状态。

class MaimaiServiceStatus {
  final String key;
  final String name;
  final String state;
  final String stateText;
  final int? latency;
  final String durationText;

  const MaimaiServiceStatus({
    required this.key,
    required this.name,
    required this.state,
    required this.stateText,
    required this.latency,
    required this.durationText,
  });

  factory MaimaiServiceStatus.fromJson(Map<String, dynamic> json) {
    final rawLatency = json['latency'];
    return MaimaiServiceStatus(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      state: json['state']?.toString() ?? 'unknown',
      stateText: json['state_text']?.toString() ?? '未知',
      latency:
          rawLatency is num ? rawLatency.round() : int.tryParse('$rawLatency'),
      durationText: json['duration_text']?.toString() ?? '',
    );
  }

  bool get isHealthy => state == 'ok' || state == 'normal' || state == 'up';
}

class MaimaiLatencySummary {
  final int? currentMs;
  final String load;
  final String loadText;
  final String volatility;
  final String volatilityText;

  const MaimaiLatencySummary({
    required this.currentMs,
    required this.load,
    required this.loadText,
    required this.volatility,
    required this.volatilityText,
  });

  factory MaimaiLatencySummary.fromJson(Map<String, dynamic> json) {
    final rawCurrent = json['current_ms'];
    return MaimaiLatencySummary(
      currentMs:
          rawCurrent is num ? rawCurrent.round() : int.tryParse('$rawCurrent'),
      load: json['load']?.toString() ?? '',
      loadText: json['load_text']?.toString() ?? '',
      volatility: json['volatility']?.toString() ?? '',
      volatilityText: json['volatility_text']?.toString() ?? '',
    );
  }
}

class MaimaiReportsSummary {
  final int anomalyCount;
  final int normalCount;
  final int? lastReportAgoMinutes;
  final bool dataEmpty;

  const MaimaiReportsSummary({
    required this.anomalyCount,
    required this.normalCount,
    required this.lastReportAgoMinutes,
    required this.dataEmpty,
  });

  factory MaimaiReportsSummary.fromJson(Map<String, dynamic> json) {
    final rawLastReport = json['last_report_ago_minutes'];
    return MaimaiReportsSummary(
      anomalyCount: _asInt(json['anomaly_count']),
      normalCount: _asInt(json['normal_count']),
      lastReportAgoMinutes: rawLastReport is num
          ? rawLastReport.round()
          : int.tryParse('$rawLastReport'),
      dataEmpty: json['data_empty'] == true,
    );
  }
}

class MaimaiRecentLog {
  final String timeAgo;
  final String region;
  final String type;

  const MaimaiRecentLog({
    required this.timeAgo,
    required this.region,
    required this.type,
  });

  factory MaimaiRecentLog.fromJson(Map<String, dynamic> json) {
    return MaimaiRecentLog(
      timeAgo: json['time_ago']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }
}

class MaimaiServerStatusEntity {
  final String version;
  final String timestamp;
  final String status;
  final String statusText;
  final String incidentLevel;
  final String verdict;
  final String verdictText;
  final List<MaimaiServiceStatus> services;
  final String summary;
  final MaimaiLatencySummary latency;
  final MaimaiReportsSummary reports;
  final List<MaimaiRecentLog> recentLogs;
  final String? broadcast;
  final String url;

  const MaimaiServerStatusEntity({
    required this.version,
    required this.timestamp,
    required this.status,
    required this.statusText,
    required this.incidentLevel,
    required this.verdict,
    required this.verdictText,
    required this.services,
    required this.summary,
    required this.latency,
    required this.reports,
    required this.recentLogs,
    required this.broadcast,
    required this.url,
  });

  factory MaimaiServerStatusEntity.fromJson(Map<String, dynamic> json) {
    final rawServices = json['services'];
    final rawLogs = json['recent_logs'];
    return MaimaiServerStatusEntity(
      version: json['version']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      statusText: json['status_text']?.toString() ?? '未知',
      incidentLevel: json['incident_level']?.toString() ?? 'unknown',
      verdict: json['verdict']?.toString() ?? 'unknown',
      verdictText: json['verdict_text']?.toString() ?? '暂无状态说明',
      services: rawServices is List
          ? rawServices
              .whereType<Map>()
              .map((item) => MaimaiServiceStatus.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
      summary: json['summary']?.toString() ?? '',
      latency: MaimaiLatencySummary.fromJson(_asMap(json['latency'])),
      reports: MaimaiReportsSummary.fromJson(_asMap(json['reports'])),
      recentLogs: rawLogs is List
          ? rawLogs
              .whereType<Map>()
              .map((item) => MaimaiRecentLog.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
      broadcast: json['broadcast']?.toString(),
      url: json['url']?.toString() ?? '',
    );
  }

  bool get isHealthy => status == 'normal' || verdict == 'normal';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

int _asInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}
