import 'dart:async';
import 'dart:collection';
import 'package:synchronized/synchronized.dart';

class IntervalRunner<T> {
  final Duration interval;
  DateTime? _lastRunTime;
  final Queue<Function> _callbackQueue = Queue();
  final _schedulerLock = Lock();
  final _queueLock = Lock();

  IntervalRunner({required this.interval});

  Future<T> run(Future<T> Function() callback) async {
    final completer = Completer<Future<T> Function()>();
    Duration delay = Duration.zero;

    await _queueLock.synchronized(() {
      _callbackQueue.add(() {
        completer.complete(callback);
      });
    });

    await _schedulerLock.synchronized(() async {
      DateTime now = DateTime.now();

      if (_lastRunTime != null && _lastRunTime!.add(interval).isAfter(now)) {
        delay = _lastRunTime!.add(interval).difference(now);
        await Future.delayed(delay);
      }

      await _queueLock.synchronized(() {
        final curCallback = _callbackQueue.removeFirst();
        // 不能用前面存的now
        // 因为即使不同的run之间通过_schedulerLock互斥了
        // 但是依然可能调度到其他协程上，两处执行时刻存在一个大gap
        _lastRunTime = DateTime.now();
        curCallback();
      });
    });

    return (await completer.future)();
  }
}

class IntervalRunnerDebug<T> {
  final Duration interval;
  DateTime? _lastRunTime;
  final Queue<(int, Function)> _callbackQueue = Queue();
  final _schedulerLock = Lock();
  final _queueLock = Lock();

  IntervalRunnerDebug({required this.interval});

  Future<T> run(int key, Future<T> Function() callback) async {
    final completer = Completer<Future<T> Function()>();
    Duration delay = Duration.zero;

    print('${DateTime.now()} run: key: $key');

    await _queueLock.synchronized(() {
      print('${DateTime.now()} key: $key _queueLock 1BEGIN');
      _callbackQueue.add((
        key,
        () {
          print(
              '${DateTime.now()} Queue中排到了 $key， 此时Queue的长度：${_callbackQueue.length}');
          completer.complete(callback);
        }
      ));
      print('${DateTime.now()} key: $key _queueLock 1END');
    });

    await _schedulerLock.synchronized(() async {
      print('${DateTime.now()} key: $key _schedulerLock BEGIN');
      DateTime now = DateTime.now();

      if (_lastRunTime != null && _lastRunTime!.add(interval).isAfter(now)) {
        delay = _lastRunTime!.add(interval).difference(now);
        print('${DateTime.now()} now: $now, _lastRunTime: $_lastRunTime, key: $key 需要等$delay时间到${_lastRunTime!.add(interval)}');
        await Future.delayed(delay);
      } else {
        print('${DateTime.now()} now: $now, _lastRunTime: $_lastRunTime, key: $key 不需要等');
      }
      await _queueLock.synchronized(() {
        print('${DateTime.now()} key: $key _queueLock 2BEGIN');
        final (curKey, curCallback) = _callbackQueue.removeFirst();
        _lastRunTime = DateTime.now();
        print(
            '${DateTime.now()} 在key为$key的run中排到的是$curKey, 此时Queue的长度：${_callbackQueue.length}');
        curCallback();
        print('${DateTime.now()} key: $key _queueLock 2END');
      });
      print('${DateTime.now()} key: $key _schedulerLock END');
    });

    return (await completer.future)();
  }
}

class Throttle<T> {
  final Duration interval;
  DateTime? _lastRunTime;
  final _lock = Lock();

  Throttle({required this.interval});

  Future<T?> run(Future<T> Function() callback) async {
    bool cancel = false;

    await _lock.synchronized(() async {
      DateTime now = DateTime.now();

      if (_lastRunTime == null || _lastRunTime!.add(interval).isBefore(now)) {
        _lastRunTime = now;
      } else {
        cancel = true;
        return;
      }
    });
    if (cancel) return null;

    return callback();
  }
}
