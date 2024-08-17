import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'MyImagelibCachedImageData';

  static final MyImageCacheManager _instance = MyImageCacheManager._();

  factory MyImageCacheManager() {
    return _instance;
  }

  MyImageCacheManager._() : super(Config(key));
}

class MyThreadCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'MyThreadlibCachedImageData';

  static final MyThreadCacheManager _instance = MyThreadCacheManager._();

  factory MyThreadCacheManager() {
    return _instance;
  }

  MyThreadCacheManager._() : super(Config(key));
}

