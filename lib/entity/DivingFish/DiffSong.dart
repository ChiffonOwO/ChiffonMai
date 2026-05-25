class DiffSong {
  // 键：字符串数字（"8"/"9"），值：难度列表
  final Map<String, List<DiffData>> charts;

  DiffSong({
    required this.charts,
  });

  // 手写 fromJson：处理 Map + 嵌套 DiffData 解析
  factory DiffSong.fromJson(Map<String, dynamic> json) {
    // 1. 解析 charts（处理空值 + 遍历解析每个 DiffData 列表）
    final Map<String, List<DiffData>> charts = {};
    final Map<String, dynamic>? chartsJson = json['charts'] as Map<String, dynamic>?;
    
    if (chartsJson != null) {
      chartsJson.forEach((key, value) {
        // 解析每个 key 对应的 DiffData 列表
        final List<dynamic>? diffListJson = value as List<dynamic>?;
        if (diffListJson != null) {
          final List<DiffData> diffDataList = diffListJson
              .map((item) => DiffData.fromJson(item as Map<String, dynamic>))
              // 过滤空对象（比如列表最后一个 {}）
              .where((diffData) => diffData.diff.isNotEmpty)
              .toList();
          charts[key] = diffDataList;
        }
      });
    }

    return DiffSong(
      charts: charts,
    );
  }

  // 手写 toJson：处理嵌套 DiffData 序列化
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    
    // 遍历 charts，序列化每个 DiffData 列表
    final Map<String, List<dynamic>> chartsJson = {};
    charts.forEach((key, diffDataList) {
      chartsJson[key] = diffDataList.map((diffData) => diffData.toJson()).toList();
    });
    data['charts'] = chartsJson;

    return data;
  }
}

class DiffData {
  /// 游玩次数（兼容 int/double）
  final num cnt;

  /// 难度标识（如 "5"/"7"/"9+"）
  final String diff;

  /// 拟合难度值（对应 JSON 的 fit_diff）
  final num fitDiff;

  /// 平均分
  final num avg;

  /// DX 平均分（对应 JSON 的 avg_dx）
  final num avgDx;

  /// 标准差（对应 JSON 的 std_dev）
  final num stdDev;

  /// 分布数组
  final List<num> dist;

  /// FC 分布数组（对应 JSON 的 fc_dist）
  final List<num> fcDist;

  DiffData({
    required this.cnt,
    required this.diff,
    required this.fitDiff,
    required this.avg,
    required this.avgDx,
    required this.stdDev,
    required this.dist,
    required this.fcDist,
  });

  // 手写 fromJson：核心处理字段映射 + 空值 + 类型转换
  factory DiffData.fromJson(Map<String, dynamic> json) {
    return DiffData(
      // 1. 基础字段：空值兜底 + num 兼容 int/double
      cnt: json['cnt'] as num? ?? 0,
      diff: json['diff'] as String? ?? '',
      // 2. 下划线字段映射到小驼峰：fit_diff → fitDiff
      fitDiff: json['fit_diff'] as num? ?? 0,
      avg: json['avg'] as num? ?? 0,
      avgDx: json['avg_dx'] as num? ?? 0,
      stdDev: json['std_dev'] as num? ?? 0,
      // 3. 数组字段：空值兜底 + 转 List<num>
      dist: _convertToListNum(json['dist']),
      fcDist: _convertToListNum(json['fc_dist']),
    );
  }

  // 手写 toJson：小驼峰转下划线
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['cnt'] = cnt;
    data['diff'] = diff;
    data['fit_diff'] = fitDiff; // fitDiff → fit_diff
    data['avg'] = avg;
    data['avg_dx'] = avgDx; // avgDx → avg_dx
    data['std_dev'] = stdDev; // stdDev → std_dev
    data['dist'] = dist;
    data['fc_dist'] = fcDist; // fcDist → fc_dist
    return data;
  }

  // 工具方法：统一处理数组转 List<num>（避免重复代码）
  static List<num> _convertToListNum(dynamic json) {
    if (json is List<dynamic>) {
      return json.map((e) => e as num? ?? 0).toList();
    }
    return []; // 非数组/空值时返回空列表
  }
}