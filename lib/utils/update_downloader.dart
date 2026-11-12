import 'package:app_installer/app_installer.dart';
import 'package:dio/dio.dart';
import 'package:lightdao/utils/update_checker.dart';

/// 下载 / 安装更新包失败时抛出的异常，[message] 直接展示给用户。
class UpdateDownloadException implements Exception {
  final String message;

  UpdateDownloadException(this.message);

  @override
  String toString() => message;
}

/// 新版本 APK 的下载与安装。
///
/// 关于页的手动更新和启动时的「自动更新」共用这里的逻辑，避免两份下载代码。
class UpdateDownloader {
  /// 下载 [updateInfo] 对应的安装包，返回本地保存路径。
  ///
  /// 进度通过 [onProgress] 回调（total 未知时不会回调），[cancelToken] 用于取消。
  /// 无法确定保存路径时抛 [UpdateDownloadException]。
  static Future<String> downloadApk({
    required UpdateInfo updateInfo,
    DownloadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final savePath = await UpdateChecker.downloadUpdate(
      url: updateInfo.downloadUrl,
      version: updateInfo.latestVersion,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (savePath == null) {
      throw UpdateDownloadException('无法获取保存路径');
    }
    return savePath;
  }

  /// 调起系统安装器安装 [savePath] 处的 APK。
  static Future<void> installApk(String savePath) {
    return AppInstaller.installApk(savePath);
  }
}
