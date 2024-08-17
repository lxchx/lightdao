import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class LRUCache<K, V> {
  final int capacity;
  final Map<K, V> _cache = {};
  final List<K> _keys = [];

  LRUCache(this.capacity);

  V? get(K key) {
    if (_cache.containsKey(key)) {
      _keys.remove(key);
      _keys.add(key);
      return _cache[key];
    }
    return null;
  }

  void put(K key, V value) {
    if (capacity != -1 && _cache.length >= capacity) {
      final oldestKey = _keys.removeAt(0);
      _cache.remove(oldestKey);
    }
    _keys.remove(key);
    _keys.insert(0, key);
    _cache[key] = value;
  }

  bool contains(K key) {
    return _cache.containsKey(key);
  }

  V? getIndex(int index) {
    return _cache[_keys[index]];
  }

  int get length {
    return _cache.length;
  }

  void remove(K key) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
      _keys.remove(key);
    }
  }
}

class LRUCacheAdapter<K, V> extends TypeAdapter<LRUCache<K, V>> {
  @override
  final typeId = 6;

  @override
  LRUCache<K, V> read(BinaryReader reader) {
    final capacity = reader.readInt();
    final cache = Map<K, V>.from(reader.readMap());
    final keys = List<K>.from(reader.readList());
    final lruCache = LRUCache<K, V>(capacity);
    lruCache._cache.addAll(cache);
    lruCache._keys.addAll(keys);
    return lruCache;
  }

  @override
  void write(BinaryWriter writer, LRUCache<K, V> obj) {
    writer.writeInt(obj.capacity);
    writer.writeMap(obj._cache);
    writer.writeList(obj._keys);
  }
}

class PersistentKVStore<K, V> {
  final String uniqueId;
  late Box _box;
  late Future<void> _initFuture;

  PersistentKVStore(this.uniqueId) {
    _initFuture = _initHive();
  }

  Future<void> exportToFile(String filePath) async {
    await _initFuture;
    await File(_box.path!).copy(filePath);
  }

  Future<void> importFromFile(String filePath) async {
    await _initFuture;
    final file = File(filePath);
    if (await file.exists()) {
      _box.close();
      await file.copy(_box.path!);
      _box = await Hive.openBox('KVStore::$uniqueId');
    } else {
      throw FileSystemException('文件不存在');
    }
  }

  Future<void> _initHive() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    _box = await Hive.openBox('KVStore::$uniqueId');
  }

  Future<V?> get(K key) async {
    await _initFuture;
    try {
      return _box.get(key);
    } catch (e) {
      return null;
    }
  }

  Future<void> put(K key, V value) async {
    await _initFuture;
    try {
      await _box.put(key, value);
    } catch (e) {
      print('保存键 $key 的值时出错: $e');
    }
  }

  Future<void> delete(K key) async {
    await _initFuture;
    try {
      await _box.delete(key);
    } catch (e) {
      print('删除键 $key 的值时出错: $e');
    }
  }
}
