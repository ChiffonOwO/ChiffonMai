import 'package:flutter/material.dart';

/**
 * 通用Widget工具类
 * 用于构建通用背景Widget
 */
class CommonWidgetUtil {
  /**
   * 构建通用背景Widget
   * 层级1：基础背景图 - 占满整个屏幕，作为页面最底层背景
   * @return 通用背景Widget
   */
  static Widget buildCommonBgWidget() {
    return Container(
      // 固定背景，不受键盘影响, 占满整个屏幕，由 Flutter 布局引擎优化处理
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'), // 背景图资源
                fit: BoxFit.cover, // 覆盖整个容器，拉伸/裁剪适配
                opacity: 1.0, // 不透明
              ),
            ),
          );
  }

  /**
   * 构建通用背景Widget
   * 层级2：第一张虚化装饰图 - 居中显示，轻微向上偏移
   * @return 通用背景Widget
   */
  static Widget buildCommonChiffonBgWidget(BuildContext context) {
    return Center(
            child: Transform.translate(
              offset: Offset(0, -MediaQuery.of(context).size.height * 0.03), // 垂直向上偏移20px
              child: Transform.scale(
                scale: 1, // 不缩放
                child: Image.asset(
                  'assets/chiffon2.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(1), // 固定不透明
                ),
              ),
            ),
          );
  }

  /**
   * 构建通用标题Widget
   * @return 通用标题Widget
   */
  static Widget buildCommonTitleWidget(String title) {
    // 页面标题
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: Color.fromARGB(255, 84, 97, 97),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  /**
   * 构建通用返回按钮Widget
   * @return 通用返回按钮Widget
   */
  static Widget buildCommonBackButtonWidget(BuildContext context) {
    return Positioned(
      top: 40,
      left: 10,
      child: GestureDetector(
        onTap: () {
          print('返回按钮被点击');
          Navigator.pop(context); // 返回到主页
        },
        child: Container(
          padding: EdgeInsets.all(16), // 增加点击区域
          color: Colors.transparent, // 透明背景，不影响视觉
          child: Icon(Icons.arrow_back,
              color: Color.fromARGB(255, 84, 97, 97), size: 24), // 增大图标
        ),
      ),
    );
  }

  // static Widget buildCommonTitleAndBackButtonRowWidget(BuildContext context, String title) {
  //   return Row(
  //     children: [
  //       buildCommonTitleWidget(title),
  //       buildCommonBackButtonWidget(context),
  //     ],
  //   );
  // }

}
