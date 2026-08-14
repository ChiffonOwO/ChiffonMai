import 'package:flutter/material.dart';
import '../entity/FeatureModels.dart';

/// 集中管理所有功能分类和功能项定义
class FeatureRegistry {
  FeatureRegistry._();

  static List<ButtonCategory> allCategories(bool isDivingFishLoggedIn) => [
    ButtonCategory(name: '曲库与数据', items: [
      const ButtonItem(icon: Icons.music_note, title: '乐曲查询', subtitle: '查询舞萌曲库的乐曲'),
      const ButtonItem(icon: Icons.score, title: '成绩查询', subtitle: '查看游玩数据'),
      const ButtonItem(icon: Icons.wysiwyg_rounded, title: '牌子进度', subtitle: '真代没有真将哦'),
      const ButtonItem(icon: Icons.grading_rounded, title: '个性化成绩查询', subtitle: '目前支持等级/谱师的牌子查询'),
      const ButtonItem(icon: Icons.collections_bookmark, title: '收藏品查询', subtitle: '查看收藏品详细信息'),
      const ButtonItem(icon: Icons.bookmark_add, title: '舞萌百科', subtitle: '到底什么是错位?'),
    ]),
    ButtonCategory(name: 'Best50与排行榜', items: [
      const ButtonItem(icon: Icons.leaderboard, title: 'Best50查询', subtitle: '我去,龙币!'),
      const ButtonItem(icon: Icons.analytics, title: '拟合Best50查询', subtitle: '我w55怎么拟合才w52?!'),
      const ButtonItem(icon: Icons.person_search_outlined, title: '个性化Best50查询', subtitle: '我超，名刀50!'),
      const ButtonItem(icon: Icons.analytics_outlined, title: '个性化拟合Best50查询', subtitle: '按标签筛选的拟合Best50'),
      const ButtonItem(icon: Icons.leaderboard, title: '排行榜(仅供参考)', subtitle: '总Rating排行榜'),
      const ButtonItem(icon: Icons.leaderboard_outlined, title: '特殊排行榜', subtitle: '各种有意思的排行榜'),
    ]),
    ButtonCategory(name: '猜歌游戏', items: [
      const ButtonItem(icon: Icons.gamepad, title: '无提示猜歌', subtitle: '舞萌笑传之猜猜呗1'),
      const ButtonItem(icon: Icons.gamepad, title: '根据部分曲绘猜歌', subtitle: '舞萌笑传之猜猜呗2'),
      const ButtonItem(icon: Icons.gamepad, title: '根据模糊曲绘猜歌', subtitle: '舞萌笑传之猜猜呗3'),
      const ButtonItem(icon: Icons.gamepad, title: '根据歌曲片段猜歌', subtitle: '舞萌笑传之猜猜呗4'),
      const ButtonItem(icon: Icons.gamepad, title: '根据别名猜歌', subtitle: '舞萌笑传之猜猜呗5'),
      const ButtonItem(icon: Icons.gamepad, title: '舞萌开字母', subtitle: '舞萌笑传之猜猜呗6'),
      const ButtonItem(icon: Icons.gamepad, title: '多人猜歌游戏', subtitle: '什么叫你随便答了一个就对了?!'),
    ]),
    ButtonCategory(name: '实用工具', icon: Icons.work, items: [
      const ButtonItem(icon: Icons.arrow_circle_up, title: '段位表', subtitle: '我去，炫彩真段位!'),
      const ButtonItem(icon: Icons.label, title: '基于标签推荐', subtitle: '基于你游玩的谱面标签推荐曲目'),
      const ButtonItem(icon: Icons.trending_up, title: '基于目标Rating推荐', subtitle: '基于目标Rating推荐适合上分的谱面'),
      const ButtonItem(icon: Icons.tune, title: '基于定数区间推荐', subtitle: '基于定数区间推荐适合上分的谱面'),
      const ButtonItem(icon: Icons.shuffle, title: '随机乐曲', subtitle: '随机选曲1-4首'),
      const ButtonItem(icon: Icons.calculate, title: '单曲Rating计算', subtitle: '我鸟加这个有分吃吗？'),
      const ButtonItem(icon: Icons.percent, title: '达成率计算', subtitle: '根据判定详情算出达成率'),
      const ButtonItem(icon: Icons.compare_arrows, title: '版本对照', subtitle: '舞神要打哪些代的歌？'),
      const ButtonItem(icon: Icons.replay, title: '达成率反推', subtitle: '根据判定详情推出绝赞详情'),
      const ButtonItem(icon: Icons.door_back_door, title: 'KALEIDXSCOPE', subtitle: '白xx!(bushi)'),
      const ButtonItem(icon: Icons.image_search, title: '曲绘识别', subtitle: '拍照识别曲绘对应的歌曲'),
      const ButtonItem(icon: Icons.bar_chart, title: '定数分布', subtitle: '查看谱面定数分布柱状图'),
      const ButtonItem(icon: Icons.favorite, title: '收藏夹', subtitle: '管理你收藏的谱面'),
      const ButtonItem(icon: Icons.play_arrow, title: '自定义谱面播放', subtitle: '播放你自己本地的谱面'),
      const ButtonItem(icon: Icons.today, title: '每日推荐', subtitle: '每日推荐歌曲'),
      const ButtonItem(icon: Icons.people, title: '好友对比', subtitle: '对比你和好友的成绩差异'),
      const ButtonItem(icon: Icons.map, title: '全国音游地图', subtitle: '看看哪里有你想玩的机台'),
      const ButtonItem(icon: Icons.public, title: '全球音游街机地图', subtitle: '查看NearCade全球街机店铺'),
    ]),
    ButtonCategory(name: '系统', icon: Icons.settings, items: [
      const ButtonItem(icon: Icons.file_upload_sharp, title: '刷新数据', subtitle: '刷新你的舞萌数据'),
      const ButtonItem(icon: Icons.cleaning_services, title: '刷新maidata', subtitle: '手动刷新所有maidata数据'),
      const ButtonItem(icon: Icons.qr_code_scanner, title: '同步成绩到水鱼', subtitle: '将成绩同步到水鱼查分器'),
      const ButtonItem(icon: Icons.cloud_sync, title: '同步成绩到落雪', subtitle: '将成绩同步到落雪咖啡屋'),
      if (isDivingFishLoggedIn)
        const ButtonItem(icon: Icons.logout, title: '登出账号', subtitle: '清除水鱼登录状态')
      else
        const ButtonItem(icon: Icons.login, title: '登录水鱼', subtitle: '获取ImportToken以便同步成绩'),
      const ButtonItem(icon: Icons.network_check, title: '服务器状态', subtitle: '查看舞萌服务器状态'),
      const ButtonItem(icon: Icons.update, title: '检查更新', subtitle: '检查应用是否有新版本'),
      const ButtonItem(icon: Icons.info_outline, title: '关于本APP', subtitle: '了解ChiffonMai的方方面面'),
      const ButtonItem(icon: Icons.poll_outlined, title: '问卷调查', subtitle: '助力ChiffonMai更上一层楼!'),
      const ButtonItem(icon: Icons.manage_accounts, title: '账号管理', subtitle: '查看已绑定的水鱼账号信息'),
      const ButtonItem(icon: Icons.backup, title: '数据备份', subtitle: '导出/导入本地数据'),
      const ButtonItem(icon: Icons.comment, title: '最近评论', subtitle: '查看全站最近50条评论'),
      const ButtonItem(icon: Icons.star, title: '最近评分', subtitle: '查看全站最近50条谱面评分'),
      const ButtonItem(icon: Icons.dark_mode, title: '浅色/深色模式', subtitle: '切换浅色/深色主题'),
    ]),
  ];
}
