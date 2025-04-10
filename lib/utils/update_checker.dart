import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String updateLog;
  final String downloadUrl;
  final bool hasUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.updateLog,
    required this.downloadUrl,
    required this.hasUpdate,
  });
}

typedef DownloadProgressCallback = void Function(int received, int total);

class UpdateChecker {
  static const String _apiUrl =
      'https://api.github.com/repos/lxchx/lightdao/releases/latest';

  static Future<UpdateInfo?> checkUpdate() async {
    // 获取当前版本
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // 获取最新版本信息
    final response = await http.get(Uri.parse(_apiUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch update info: ${response.statusCode}');
    }

    final data = json.decode(response.body);

    // 解析版本号（移除'v'前缀）
    final latestVersion = (data['tag_name'] as String).replaceFirst('v', '');

    // 解析更新日志和下载链接
    final updateLog = data['body'] as String;
    final downloadUrl = (data['assets'] as List).firstWhere(
      (asset) => asset['name'] == 'app-release.apk',
      orElse: () => throw Exception('No APK found in release assets'),
    )['browser_download_url'] as String;

    // 比较版本号
    final hasUpdate = _compareVersions(latestVersion, currentVersion);

    return UpdateInfo(
      latestVersion: latestVersion,
      currentVersion: currentVersion,
      updateLog: updateLog,
      downloadUrl: downloadUrl,
      hasUpdate: hasUpdate,
    );
  }

  // 比较版本号，如果 latest > current 返回 true
  static bool _compareVersions(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static Future<String?> downloadUpdate({
    required String url,
    required String version,
    DownloadProgressCallback? onProgress,
    CancelToken? cancelToken, // 添加取消令牌参数
  }) async {
    final dio = Dio();
    // 尝试获取下载目录
    final dir = await getDownloadsDirectory() ??
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();

    final savePath = '${dir.path}/lightdao_v$version.apk';

    await dio.download(
      url,
      savePath,
      cancelToken: cancelToken, // 使用取消令牌
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress?.call(received, total);
        }
      },
    );

    return savePath;
  }
}
