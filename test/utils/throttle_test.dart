import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/utils/throttle.dart';

void main() {
  group('IntervalRunner', () {
    test('should catch exceptions thrown by the callback', () async {
      final runner = IntervalRunner<void>(interval: Duration(seconds: 1));

      bool exceptionCaught = false;

      try {
        await runner.run(() async {
          throw Exception('Test exception');
        });
      } catch (e) {
        exceptionCaught = true;
        expect(e, isException);
        expect(e.toString(), contains('Test exception'));
      }

      expect(exceptionCaught, isTrue);
    });
  });
  group('IntervalRunner', () {
    test('callbacks are called with at least the specified interval', () async {
      final interval = Duration(milliseconds: 100);
      final runner = IntervalRunnerDebug<void>(interval: interval);
      final results = <int>[];
      final startTime = DateTime.now();

      Future<void> callback(int key) async {
        final now = DateTime.now();
        print('$now 排到了$key');
        final elapsed = now.difference(startTime).inMilliseconds;
        results.add(elapsed);
        print('Callback $key called at $elapsed ms');
      }

      // Schedule multiple callbacks
      for (int i = 0; i < 50; i++) {
        runner.run(i, () => callback(i));
      }

      // Wait for all callbacks to complete
      await Future.delayed(Duration(seconds: 6));

      // Verify that the intervals between callbacks are at least the specified interval
      for (int i = 1; i < results.length; i++) {
        final intervalBetweenCallbacks = results[i] - results[i - 1];
        expect(
          intervalBetweenCallbacks * 1.2,
          greaterThanOrEqualTo(interval.inMilliseconds),
          reason: '$i 和 ${i - 1}之间太短了',
        );
      }
      expect(results.length, equals(50));
    });
  });
}
