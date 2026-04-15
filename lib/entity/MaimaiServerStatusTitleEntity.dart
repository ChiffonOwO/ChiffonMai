// Maimai服务器状态标题实体类

// 配置信息
class ServerStatusConfig {
  final String slug;
  final String title;
  final String description;
  final String icon;
  final int autoRefreshInterval;
  final String theme;
  final bool published;
  final bool showTags;
  final String customCSS;
  final String footerText;
  final bool showPoweredBy;
  final String analyticsId;
  final String analyticsScriptUrl;
  final String analyticsType;
  final bool showCertificateExpiry;
  final bool showOnlyLastHeartbeat;
  final dynamic rssTitle;

  ServerStatusConfig({
    required this.slug,
    required this.title,
    required this.description,
    required this.icon,
    required this.autoRefreshInterval,
    required this.theme,
    required this.published,
    required this.showTags,
    required this.customCSS,
    required this.footerText,
    required this.showPoweredBy,
    required this.analyticsId,
    required this.analyticsScriptUrl,
    required this.analyticsType,
    required this.showCertificateExpiry,
    required this.showOnlyLastHeartbeat,
    this.rssTitle,
  });

  factory ServerStatusConfig.fromJson(Map<String, dynamic> json) {
    return ServerStatusConfig(
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      autoRefreshInterval: json['autoRefreshInterval'] ?? 0,
      theme: json['theme'] ?? '',
      published: json['published'] ?? false,
      showTags: json['showTags'] ?? false,
      customCSS: json['customCSS'] ?? '',
      footerText: json['footerText'] ?? '',
      showPoweredBy: json['showPoweredBy'] ?? false,
      analyticsId: json['analyticsId'] ?? '',
      analyticsScriptUrl: json['analyticsScriptUrl'] ?? '',
      analyticsType: json['analyticsType'] ?? '',
      showCertificateExpiry: json['showCertificateExpiry'] ?? false,
      showOnlyLastHeartbeat: json['showOnlyLastHeartbeat'] ?? false,
      rssTitle: json['rssTitle'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'title': title,
      'description': description,
      'icon': icon,
      'autoRefreshInterval': autoRefreshInterval,
      'theme': theme,
      'published': published,
      'showTags': showTags,
      'customCSS': customCSS,
      'footerText': footerText,
      'showPoweredBy': showPoweredBy,
      'analyticsId': analyticsId,
      'analyticsScriptUrl': analyticsScriptUrl,
      'analyticsType': analyticsType,
      'showCertificateExpiry': showCertificateExpiry,
      'showOnlyLastHeartbeat': showOnlyLastHeartbeat,
      'rssTitle': rssTitle,
    };
  }
}

// 监控项
class MonitorItem {
  final int id;
  final String name;
  final int sendUrl;
  final String type;
  final List<dynamic> tags;
  final int? certExpiryDaysRemaining;
  final bool? validCert;

  MonitorItem({
    required this.id,
    required this.name,
    required this.sendUrl,
    required this.type,
    required this.tags,
    this.certExpiryDaysRemaining,
    this.validCert,
  });

  factory MonitorItem.fromJson(Map<String, dynamic> json) {
    return MonitorItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      sendUrl: json['sendUrl'] ?? 0,
      type: json['type'] ?? '',
      tags: json['tags'] ?? [],
      certExpiryDaysRemaining: json['certExpiryDaysRemaining'],
      validCert: json['validCert'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sendUrl': sendUrl,
      'type': type,
      'tags': tags,
      'certExpiryDaysRemaining': certExpiryDaysRemaining,
      'validCert': validCert,
    };
  }
}

// 监控组
class PublicGroup {
  final int id;
  final String name;
  final int weight;
  final List<MonitorItem> monitorList;

  PublicGroup({
    required this.id,
    required this.name,
    required this.weight,
    required this.monitorList,
  });

  factory PublicGroup.fromJson(Map<String, dynamic> json) {
    return PublicGroup(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      weight: json['weight'] ?? 0,
      monitorList: (json['monitorList'] as List<dynamic>?)?.map((item) => MonitorItem.fromJson(item)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'monitorList': monitorList.map((item) => item.toJson()).toList(),
    };
  }
}

// 主服务器状态标题实体类
class MaimaiServerStatusTitleEntity {
  final ServerStatusConfig config;
  final List<dynamic> incidents;
  final List<PublicGroup> publicGroupList;
  final List<dynamic> maintenanceList;

  MaimaiServerStatusTitleEntity({
    required this.config,
    required this.incidents,
    required this.publicGroupList,
    required this.maintenanceList,
  });

  factory MaimaiServerStatusTitleEntity.fromJson(Map<String, dynamic> json) {
    return MaimaiServerStatusTitleEntity(
      config: ServerStatusConfig.fromJson(json['config'] ?? {}),
      incidents: json['incidents'] ?? [],
      publicGroupList: (json['publicGroupList'] as List<dynamic>?)?.map((group) => PublicGroup.fromJson(group)).toList() ?? [],
      maintenanceList: json['maintenanceList'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'config': config.toJson(),
      'incidents': incidents,
      'publicGroupList': publicGroupList.map((group) => group.toJson()).toList(),
      'maintenanceList': maintenanceList,
    };
  }

  // 获取服务器ID到名称的映射
  Map<String, String> getServerIdToNameMap() {
    final Map<String, String> map = {};
    
    for (final group in publicGroupList) {
      for (final monitor in group.monitorList) {
        map[monitor.id.toString()] = monitor.name;
      }
    }
    
    return map;
  }
}