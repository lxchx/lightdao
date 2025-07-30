import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class PhotoSaver {
  /// 保存图片到相册，让gal包自己处理权限
  static Future<bool> saveImageToGallery(
    String imagePath, {
    BuildContext? context,
  }) async {
    try {
      // 直接使用gal包保存图片，让它自己处理权限
      await Gal.putImage(imagePath);
      return true;
    } catch (e) {
      // 如果保存失败，显示错误信息
      if (context != null) {
        _showErrorDialog(context, '保存失败', '保存图片到相册失败: $e');
      }
      return false;
    }
  }

  /// 保存网络图片到相册
  static Future<bool> saveNetworkImageToGallery(
    String imageUrl, {
    BuildContext? context,
  }) async {
    try {
      // 下载图片到临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 这里需要实现图片下载逻辑
      // 暂时返回false，需要添加http下载功能
      if (context != null) {
        _showErrorDialog(context, '功能未实现', '网络图片保存功能暂未实现');
      }
      return false;
    } catch (e) {
      if (context != null) {
        _showErrorDialog(context, '保存失败', '保存网络图片失败: $e');
      }
      return false;
    }
  }

  /// 显示错误对话框
  static void _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示成功提示
  static void showSuccessMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('图片已保存到相册'), duration: Duration(seconds: 2)),
    );
  }
}
