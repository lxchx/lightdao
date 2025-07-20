import 'package:flutter/material.dart';


/// 一个抽象的State基类，它为所有子类提供了为父Scaffold构建动态UI组件的能力。
///
/// 任何希望控制其父Scaffold的Drawer或FloatingActionButton的State对象，都应该继承自这个类，
/// 而不是直接继承State<T>。
///
/// <T> 是与此State关联的StatefulWidget的类型。
/// 如果有State不想继承State<T>而是继承其它State派生类型，应该另外实现一个ScaffoldAccessoryBuilder
abstract class ScaffoldAccessoryBuilder<T extends StatefulWidget> extends State<T> {
  /// 构建并返回一个Widget列表，用作抽屉的主要内容。
  /// 如果页面不需要Drawer，则返回null。子类必须重写此方法。
  List<Widget>? buildDrawerContent(BuildContext context);

  /// 构建并返回该页面希望在Scaffold中显示的FloatingActionButton。
  /// 如果页面不需要FAB，则返回null。子类必须重写此方法。
  /// [anchorContext] 是来自父级Scaffold的context，如果需要，可用于例如显示SnackBar。
  Widget? buildFloatingActionButton(BuildContext anchorContext);

  // 当处于这个导航页又一次单击选择导航项时调用
  // true说明有动作，false说明没动作，Scaffold页可以做动作
  bool onReLocated(BuildContext anchorContext);
}
