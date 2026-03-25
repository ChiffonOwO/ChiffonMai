/**
 * 曲绘路径工具类
 * 用于处理曲绘路径相关的操作
 */
import 'package:flutter/material.dart';

class CoverPathUtil {
  /**
   * 构建本地曲绘路径
   * @param songId 歌曲ID
   * @return 本地曲绘路径
   */
  static String getLocalCoverPath(String songId) {
    // 构建本地曲绘路径
    // 本地曲绘路径需要处理6位数的曲绘ID
    String coverId = songId.toString();
    // 对于6位数的曲绘，需要去除第一位并去除第一位后面所有的0，直到遇到第一位不是0的数字
    if (coverId.length == 6) {
      // 去除第一位
      coverId = coverId.substring(1);
      // 去掉第一位后面所有的0
      coverId = coverId.replaceAll(RegExp(r'^0+'), '');
    }
    return 'assets/cover/${coverId}.webp';
  }

  /**
   * 构建本地曲绘路径方式2，用于第一次尝试本地加载失败时的fallback
   * @param songId 歌曲ID
   * @return 本地曲绘路径Retry
   */
  static String getLocalCoverPathRetry(String songId) {
    // 一般就是<5位数的ID曲绘出问题，需要补齐成5位数，第一位补1，第一位后面补0
    String coverId = songId.toString();
    if (coverId.length < 5) {
      coverId = '1' + '0' * (4 - coverId.length) + coverId;
    }
    return 'assets/cover/${coverId}.webp';
  }

  /**
   * 构建网络曲绘路径，一般用于2次本地加载都失败时的fallback
   * @param songId 歌曲ID
   * @return 网络曲绘URL
   */
  static String getNetworkCoverUrl(String songId) {
    // 生成网络曲绘URL
    String coverId = songId.toString();

    // 对于6位数的曲绘，只需要去除第一位
    if (coverId.length == 6) {
      // 去掉第一位
      coverId = coverId.substring(1);
    }
    // 对于不足 5 位数的 ID，需要在其前面补 0 以补足 5 位数
    if (coverId.length < 5) {
      coverId = '0' * (5 - coverId.length) + coverId;
    }
    String networkCoverUrl = 'https://www.diving-fish.com/covers/$coverId.png';
    return networkCoverUrl;
  }

  /**
   * 构建曲绘Widget
   * @param songId 歌曲ID
   * @param size 曲绘尺寸
   * @return 曲绘Widget
   */
  static Widget buildCoverWidget(String songId, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Image.asset(
        getLocalCoverPath(songId),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 本地资产加载失败，尝试换一种方式加载本地资产
          return Image.asset(
            getLocalCoverPathRetry(songId),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 本地资产加载失败，尝试从网络加载
              return Image.network(
                getNetworkCoverUrl(songId),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 网络图片加载失败，显示默认图片0.webp
                  return Image.asset(
                    'assets/cover/0.webp',
                    fit: BoxFit.cover,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /**
   * 构建曲绘Widget（带上下文）
   * @param context 上下文
   * @param songId 歌曲ID
   * @param size 曲绘尺寸
   * @return 曲绘Widget
   */
  static Widget buildCoverWidgetWithContext(
      BuildContext context, String songId, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child:
          Image.asset(getLocalCoverPath(songId.toString()), fit: BoxFit.cover,
              // 本地资产加载失败，尝试换一种方式加载本地资产
              errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          getLocalCoverPathRetry(songId.toString()),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 本地资产加载方式2失败，尝试从网络加载
            return Image.network(
              getNetworkCoverUrl(songId.toString()),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // 网络图片加载失败，显示默认图片0.webp
                return Image.asset(
                  'assets/cover/0.webp',
                  fit: BoxFit.cover,
                );
              },
            );
          },
        );
      }),
    );
  }

  static Widget buildCoverWidgetWithContextRRect(
      BuildContext context, String songId, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: buildCoverWidgetWithContext(context, songId, size),
    );
  }
}
