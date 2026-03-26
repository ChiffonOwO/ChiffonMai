/**
 * 曲绘路径工具类
 * 用于处理曲绘路径相关的操作
 */
import 'package:flutter/material.dart';

class CoverUtil {
  /**
   * 构建曲绘路径 通用方法
   * @param coverId 曲绘ID
   * @return 曲绘路径
   */
  static String buildCoverPath(String? coverId) =>
      'assets/cover/${coverId ?? '0'}.webp';

  /**
   * 构建本地曲绘路径方式1，用于初步处理后的正常加载
   * @param songId 歌曲ID
   * @return 本地曲绘路径1
   */
  static String getLocalCoverPath(String songId) {
    // 构建本地曲绘路径
    // 本地曲绘路径需要处理5位数和6位数的曲绘ID
    String coverId = songId.toString();
    // 对于5位数和6位数的曲绘，需要去除第一位并去除第一位后面所有的0，直到遇到第一位不是0的数字
    if (coverId.length == 6 || coverId.length == 5) {
      // 去除第一位
      coverId = coverId.substring(1);
      // 去掉第一位后面所有的0
      coverId = coverId.replaceAll(RegExp(r'^0+'), '');
    }
    return buildCoverPath(coverId);
  }

  /**
   * 构建本地曲绘路径方式2，用于第一次尝试本地加载失败时的fallback
   * @param songId 歌曲ID
   * @return 本地曲绘路径Retry1
   */
  static String getLocalCoverPathRetry1(String songId) {
    // 一般就是<5位数的ID曲绘出问题，需要补齐成5位数，第一位补1，第一位后面补0
    String coverId = songId.toString();
    if (coverId.length < 5) {
      coverId = '1' + '0' * (4 - coverId.length) + coverId;
    }
    return buildCoverPath(coverId);
  }

  /**
   * 构建本地曲绘路径方式3，用于第二次尝试本地加载失败时的fallback
   * @param songId 歌曲ID
   * @return 本地曲绘路径Retry2
   */
  static String getLocalCoverPathRetry2(String songId) {
    // 我服了呀，怎么宴会场的谱面这么多事
    // 从最后一位开始往左找，直到遇到第一个0停止
    String coverId = songId.toString();
    // 只处理6位长度的ID
    if (coverId.length == 6) {
      // 从最后一位往前找第一个 0
      for (int i = 5; i >= 0; i--) {
        if (coverId[i] == '0') {
          // 保留 0 右边的所有内容
          coverId = coverId.substring(i + 1);
          break;
        }
      }
    }
    return buildCoverPath(coverId);
  }

  /**
   * 构建网络曲绘路径，一般用于所有本地加载都失败时的fallback
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
        // 先尝试直接加载资产
        buildCoverPath(songId.toString()),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            getLocalCoverPath(songId),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 本地资产加载失败，尝试换一种方式加载本地资产
              return Image.asset(
                getLocalCoverPathRetry1(songId),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    getLocalCoverPathRetry2(songId),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // 本地资产加载失败，尝试从网络加载
                      return Image.network(
                        getNetworkCoverUrl(songId),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // 网络图片加载失败，显示默认图片0.webp
                          return Image.asset(
                            buildCoverPath('0'),
                            fit: BoxFit.cover,
                          );
                        },
                      );
                    },
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
      child: Image.asset(
        // 先尝试直接加载资产
        buildCoverPath(songId.toString()),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(getLocalCoverPath(songId.toString()),
              fit: BoxFit.cover,
              // 本地资产加载失败，尝试换一种方式加载本地资产
              errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              getLocalCoverPathRetry1(songId.toString()),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  getLocalCoverPathRetry2(songId.toString()),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // 本地资产加载方式2失败，尝试从网络加载
                    return Image.network(
                      getNetworkCoverUrl(songId.toString()),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 网络图片加载失败，显示默认图片0.webp
                        return Image.asset(
                          buildCoverPath('0'),
                          fit: BoxFit.cover,
                        );
                      },
                    );
                  },
                );
              },
            );
          });
        },
      ),
    );
  }

  /**
   * 构建曲绘Widget（带上下文）（圆角矩形）
   * @param context 上下文
   * @param songId 歌曲ID
   * @param size 曲绘尺寸
   * @return 曲绘Widget
   */
  static Widget buildCoverWidgetWithContextRRect(
      BuildContext context, String songId, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: buildCoverWidgetWithContext(context, songId, size),
    );
  }
}