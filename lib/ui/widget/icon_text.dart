import 'package:flutter/material.dart';

/// 一个高度优化的、用于将图标和文本并排显示的组件。
///
/// 其样式行为与 Flutter 官方的 [Chip] 组件对齐，提供了简洁、独立且一致的视觉控制。
class IconText extends StatelessWidget {
  /// 显示的图标 Widget。可以是 [Icon]、[CircleAvatar] 或任何其他 Widget。
  final Widget icon;

  /// 显示的文本 Widget。
  final Widget text;

  /// 图标和文本之间的间距，默认为 4.0。
  final double spacing;

  /// 如果为 true，则图标显示在文本的右侧（尾部）。
  /// 默认为 false，即图标在左侧。
  final bool iconAtTail;

  /// 应用于 [icon] Widget 的主题。
  ///
  /// - `size`: 默认值为 18.0，与 [Chip] 的 avatar 尺寸一致。
  /// - `color`: 默认值会继承自上层的 [IconThemeData]。它与文本颜色是解耦的，
  ///          这与 [Chip] 的行为一致。
  final IconThemeData? iconTheme;

  const IconText({
    super.key,
    required this.icon,
    required this.text,
    this.spacing = 4.0,
    this.iconAtTail = false,
    this.iconTheme,
  });

  @override
  Widget build(BuildContext context) {
    // 关键修正：图标颜色不再关联文本颜色，而是继承自上下文的 IconTheme。
    final IconThemeData ambientIconTheme = IconTheme.of(context);

    // 创建一个与 Chip avatar 中图标行为一致的默认图标主题
    final IconThemeData defaultIconTheme = IconThemeData(
      size: 18.0,
      color: ambientIconTheme.color, // 继承上层 IconTheme 的颜色
    );

    // 将用户传入的主题与默认主题合并，用户的自定义优先级更高
    final IconThemeData finalIconTheme = defaultIconTheme.merge(iconTheme);

    // 将最终的主题应用到 icon Widget 上。
    final Widget themedIcon = IconTheme(data: finalIconTheme, child: icon);

    // 根据 iconAtTail 标志位构建子组件列表
    final children = !iconAtTail
        ? [themedIcon, SizedBox(width: spacing), text]
        : [text, SizedBox(width: spacing), themedIcon];

    return Row(
      mainAxisSize: MainAxisSize.min, // 宽度包裹内容
      crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中对齐
      children: children,
    );
  }
}
