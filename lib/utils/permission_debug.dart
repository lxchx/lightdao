import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionDebug {
  /// 调试iOS相册权限状态
  static Future<void> debugPhotoPermission(BuildContext context) async {
    if (!Platform.isIOS) return;

    final StringBuffer debugInfo = StringBuffer();
    debugInfo.writeln('=== iOS相册权限调试信息 ===');

    try {
      // 检查 photos 权限
      debugInfo.writeln('\n1. 检查 photos 权限:');
      final photosStatus = await Permission.photos.status;
      debugInfo.writeln('   photos.status: $photosStatus');
      debugInfo.writeln('   photos.isGranted: ${photosStatus.isGranted}');
      debugInfo.writeln('   photos.isDenied: ${photosStatus.isDenied}');
      debugInfo.writeln(
        '   photos.isPermanentlyDenied: ${photosStatus.isPermanentlyDenied}',
      );

      // 尝试请求权限
      debugInfo.writeln('\n2. 尝试请求权限:');
      debugInfo.writeln('   尝试请求 photos 权限...');
      final photosResult = await Permission.photos.request();
      debugInfo.writeln('   photos.request() 结果: $photosResult');

      // 最终状态
      debugInfo.writeln('\n3. 最终权限状态:');
      final finalPhotosStatus = await Permission.photos.status;
      debugInfo.writeln('   最终 photos.status: $finalPhotosStatus');
    } catch (e) {
      debugInfo.writeln('调试过程中发生错误: $e');
    }

    // 显示调试信息
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('权限调试信息'),
        content: SingleChildScrollView(child: Text(debugInfo.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('去设置'),
          ),
        ],
      ),
    );
  }

  /// 调试相机权限状态
  static Future<void> debugCameraPermission(BuildContext context) async {
    if (!Platform.isIOS) return;

    final StringBuffer debugInfo = StringBuffer();
    debugInfo.writeln('=== iOS相机权限调试信息 ===');

    try {
      // 检查相机权限
      debugInfo.writeln('\n1. 检查相机权限:');
      final cameraStatus = await Permission.camera.status;
      debugInfo.writeln('   camera.status: $cameraStatus');
      debugInfo.writeln('   camera.isGranted: ${cameraStatus.isGranted}');
      debugInfo.writeln('   camera.isDenied: ${cameraStatus.isDenied}');
      debugInfo.writeln(
        '   camera.isPermanentlyDenied: ${cameraStatus.isPermanentlyDenied}',
      );

      // 尝试请求权限
      debugInfo.writeln('\n2. 尝试请求相机权限:');
      final cameraResult = await Permission.camera.request();
      debugInfo.writeln('   camera.request() 结果: $cameraResult');

      // 最终状态
      debugInfo.writeln('\n3. 最终相机权限状态:');
      final finalCameraStatus = await Permission.camera.status;
      debugInfo.writeln('   最终 camera.status: $finalCameraStatus');
    } catch (e) {
      debugInfo.writeln('调试过程中发生错误: $e');
    }

    // 显示调试信息
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('相机权限调试信息'),
        content: SingleChildScrollView(child: Text(debugInfo.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('去设置'),
          ),
        ],
      ),
    );
  }
}
