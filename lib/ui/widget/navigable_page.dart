import 'package:flutter/material.dart';

/// 一个数据类，用于封装AppPage和ForumPage之间传递的板块选择信息。
/// 使用这个类可以避免在方法调用中传递多个参数，让代码更清晰。
class ForumSelection {
  final int id;
  final String name;
  final bool isTimeline;

  const ForumSelection({
    required this.id,
    required this.name,
    required this.isTimeline,
  });
}

/// 一个抽象类，定义了一个页面可以向其父Scaffold提供抽屉“内容”的契约。
///
/// 任何希望拥有自定义抽屉的顶级页面都应该实现这个类。
/// 它返回一个Widget列表，而不是一个完整的Drawer，这使得AppPage可以根据布局
/// 决定如何展示这些内容，实现了UI逻辑的完美分离。
abstract class NavigablePage {
  /// 构建并返回此页面希望在抽屉中显示的内容Widget列表。
  List<Widget> buildDrawerContent(BuildContext context);
}
