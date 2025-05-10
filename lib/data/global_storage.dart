import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lightdao/utils/kv_store.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MyImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'MyImagelibCachedImageData';

  static final MyImageCacheManager _instance = MyImageCacheManager._();

  factory MyImageCacheManager() {
    return _instance;
  }

  MyImageCacheManager._() : super(Config(key, stalePeriod: Duration(days: 30)));
}

class MyThreadCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'MyThreadlibCachedImageData';

  static final MyThreadCacheManager _instance = MyThreadCacheManager._();

  factory MyThreadCacheManager() {
    return _instance;
  }

  MyThreadCacheManager._() : super(Config(key, stalePeriod: Duration(days: 5)));
}

typedef ImageSize = Size;
final memoryImageInfoCache = LRUCache<String, ImageSize>(
  1000,
);
