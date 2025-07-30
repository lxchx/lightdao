import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// 请求相册权限（用于保存图片）
  static Future<bool> requestPhotoPermission(BuildContext context) async {
    if (Platform.isIOS) {
      return await _requestIOSPhotoPermission(context);
    } else if (Platform.isAndroid) {
      return await _requestAndroidPhotoPermission(context);
    }
    return false;
  }

  /// 请求相机权限
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (Platform.isIOS) {
      return await _requestIOSCameraPermission(context);
    } else if (Platform.isAndroid) {
      return await _requestAndroidCameraPermission(context);
    }
    return false;
  }

  /// iOS相册权限请求
  static Future<bool> _requestIOSPhotoPermission(BuildContext context) async {
    // 检查当前权限状态
    final status = await Permission.photos.status;

    // 如果已经有权限，直接返回
    if (status.isGranted) {
      return true;
    }

    // 如果权限被永久拒绝，显示对话框
    if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog(context, '相册权限', '保存图片');
      return false;
    }

    // 如果权限被拒绝或未确定，尝试请求权限
    if (status.isDenied) {
      final result = await Permission.photos.request();

      if (result.isGranted) {
        return true;
      } else if (result.isPermanentlyDenied) {
        _showPermissionDeniedDialog(context, '相册权限', '保存图片');
        return false;
      } else {
        // 用户拒绝了权限请求
        return false;
      }
    }

    return false;
  }

  /// iOS相机权限请求
  static Future<bool> _requestIOSCameraPermission(BuildContext context) async {
    // 检查当前权限状态
    final status = await Permission.camera.status;

    // 如果已经有权限，直接返回
    if (status.isGranted) {
      return true;
    }

    // 如果权限被永久拒绝，显示对话框
    if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog(context, '相机权限', '拍照');
      return false;
    }

    // 如果权限被拒绝或未确定，尝试请求权限
    if (status.isDenied) {
      final result = await Permission.camera.request();

      if (result.isGranted) {
        return true;
      } else if (result.isPermanentlyDenied) {
        _showPermissionDeniedDialog(context, '相机权限', '拍照');
        return false;
      } else {
        // 用户拒绝了权限请求
        return false;
      }
    }

    return false;
  }

  /// Android相册权限请求
  static Future<bool> _requestAndroidPhotoPermission(
    BuildContext context,
  ) async {
    // Android 13+ 使用 photos 权限
    if (await Permission.photos.isGranted) {
      return true;
    }

    final result = await Permission.photos.request();
    if (result.isGranted) {
      return true;
    }

    // 尝试其他权限
    if (await Permission.storage.isGranted) {
      return true;
    }

    final storageResult = await Permission.storage.request();
    if (storageResult.isGranted) {
      return true;
    }

    _showPermissionDeniedDialog(context, '存储权限', '保存图片');
    return false;
  }

  /// Android相机权限请求
  static Future<bool> _requestAndroidCameraPermission(
    BuildContext context,
  ) async {
    if (await Permission.camera.isGranted) {
      return true;
    }

    final result = await Permission.camera.request();
    if (result.isGranted) {
      return true;
    }

    _showPermissionDeniedDialog(context, '相机权限', '拍照');
    return false;
  }

  /// 显示权限被拒绝的对话框
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String permissionName,
    String featureName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('权限被拒绝'),
        content: Text('需要$permissionName才能$featureName。请在设置中开启权限。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
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

  /// 检查权限状态
  static Future<PermissionStatus> checkPhotoPermission() async {
    if (Platform.isIOS) {
      return await Permission.photos.status;
    } else if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted) {
        return photosStatus;
      }
      return await Permission.storage.status;
    }
    return PermissionStatus.denied;
  }

  /// 检查相机权限状态
  static Future<PermissionStatus> checkCameraPermission() async {
    return await Permission.camera.status;
  }
}
