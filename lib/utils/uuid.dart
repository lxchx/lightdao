import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';

Future<String> generateDeviceUuid() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

  String deviceId = androidInfo.id;

  String salt = "lightdaouuidgenerator";

  // 将设备ID和盐值进行UTF8编码并生成SHA256哈希值
  var bytes = utf8.encode(deviceId + salt);
  var digest = sha256.convert(bytes);

  String hash = digest.toString().substring(0, 32);
  String uuid =
      '${hash.substring(0, 8)}-${hash.substring(8, 12)}-${hash.substring(12, 16)}-${hash.substring(16, 20)}-${hash.substring(20, 32)}';
  return uuid;
}
