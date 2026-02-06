import 'package:flutter/material.dart';

void main(List<String> args) {
  runApp(MainPage());
}

//构造无状态Widget
//需要继承StatelessWidget类并重写build方法
class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: "Flutter组件初体验", //标题内容（可以不设置）
        //theme: ThemeData(scaffoldBackgroundColor: Colors.blue), //骨架的颜色
        home: Scaffold(
          appBar: AppBar(
            title: Text("这里是头部区域"),
            centerTitle: true,
          ),
          body: Container(
            child: Center(

              // child: InkWell(
              //   // 波纹颜色
              //   splashColor: Colors.blue.withOpacity(0.3),
              //   // 高亮底色
              //   highlightColor: Colors.grey[200],
              //   // 圆角裁剪
              //   borderRadius: BorderRadius.circular(8),
              //   // 单击回调
              //   onTap: () => print("按钮被点击"),
              //   child: Container(
              //     padding:
              //         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              //     child: const Text("点击触发水波纹"),
              //   ),
              // ),

              // child: TextButton(
              //     onPressed: () => print("点击了TextButton"),
              //     child: Text("我是TextButton")),

              // //手势检测组件
              // child: GestureDetector(
              //   onTap: () => {print("单击了该区域")},
              //   onDoubleTap: () => {print("双击了该区域")},
              //   onLongPress: () => {print("长按了该区域")},
              // )
            ),
          ),
          bottomNavigationBar: Container(
            height: 80,
            child: Center(
              child: Text("底部区域"),
            ),
          ),
        ),
      );
}

//有状态组件 第一个类对外
class CountPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _CountPageState();
  /**
   * 或写作
   * @override
     State<StatefulWidget> createState() {
     return _CountPageState();
    } 
   */
}

//有状态组件 第二个类对内 处理数据，业务逻辑，渲染视图
//命名规范 _对外类名State
class _CountPageState extends State<CountPage> {
  // 1. 定义需要维护的状态（变量）
  int _count = 0;

  // 2. 定义修改状态的方法（必须通过 setState 触发 UI 更新）
  void _incrementCounter() {
    setState(() {
      _count++; // 修改状态变量
    });
  }

  // 3. 构建 UI（根据状态动态渲染）
  /// floatingActionButton（简称 FAB）是一个悬浮式的圆形按钮，通常出现在页面的右下角，
  /// 用于承载当前页面最核心、最常用的操作（比如 “添加”“新建”“提交” 等）。
  /// 它属于 Scaffold 的属性，必须在 Scaffold 内部使用。
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: "计数器",
        home: Scaffold(
          appBar: AppBar(
            title: Text("计数器"),
            centerTitle: true,
          ),
          body: Center(
            child: Text("当前计数：$_count", style: TextStyle(fontSize: 24)),
          ),
          floatingActionButton:
              FloatingActionButton(onPressed: _incrementCounter),
        ),
      );
}


class HelloContainerPage extends StatelessWidget {
  const HelloContainerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          transform: Matrix4.rotationZ(0.05), //Container的面向操作者的旋转角度，采用弧度制
          margin: EdgeInsets.all(20), //外边距
          alignment: Alignment.center, //控制其子组件child在Container内部的对其方式 这里为居中
          width: 200, 
          height: 200, 
          //BoxDecoration为复杂的样式设计
          decoration: BoxDecoration(
            color: Colors.blue, //Container背景颜色
            borderRadius: BorderRadius.circular(15), //Container的四个角 这里是圆角
            border: Border.all(color: Colors.yellow, width: 3), //Container的四个边 这里是粗度为3的黄色边框
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100, //Colors.grey.shade100 是极浅的灰色
                blurRadius: 5, //设置阴影的模糊半径（单位：逻辑像素），控制阴影的 “虚化程度”
                offset: Offset(2, 2), //设置阴影相对于组件本身的偏移位置，Offset(x, y)的两个参数分别控制水平和垂直方向
              )
            ],
          ),
          child: Text("Hello, I am Container", style: TextStyle(color: Colors.white, fontSize: 20),),
        ),
      )
    );
  }
}
