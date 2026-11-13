// 审计用例（已转为正向断言）：LRU 淘汰方向、内置表情去重、相对时间文案。
//
// 原始复现见 flutter-scroll/dist/lightdao-bugs-20261113.md（BUG-A/B/C）。
// 运行：flutter test test/audit/logic_audit_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/utils/kv_store.dart';

void main() {
  group('BUG-A LRUCache 的淘汰方向 (audit #7)', () {
    test('容量满时淘汰最久未使用项，而不是刚 put 的那一项', () {
      final cache = LRUCache<int, String>(3);
      cache.put(1, 'a');
      cache.put(2, 'b');
      cache.put(3, 'c');
      cache.get(1); // 用过 1，1 最不可能被淘汰
      cache.put(4, 'd'); // LRU 应该淘汰 2

      expect(cache.contains(2), isFalse, reason: '最久未使用的 2 应被淘汰');
      expect(cache.contains(1), isTrue, reason: '刚读过，不该被淘汰');
      expect(cache.contains(3), isTrue, reason: '刚 put 的 3 不该被淘汰');
      expect(cache.contains(4), isTrue);
    });

    test('get 命中后该条目成为最新（头部）', () {
      final cache = LRUCache<int, String>(10);
      for (var i = 0; i < 5; i++) {
        cache.put(i, 'v$i');
      }
      // put 认为下标 0 是最新（浏览历史据此"最新在上"展示）
      expect(cache.getIndex(0), 'v4');
      expect(cache.getIndex(4), 'v0');

      cache.get(2); // 点开历史里的一串
      expect(cache.getIndex(0), 'v2', reason: '读一次之后被读条目应成为最新');
      expect(
        [for (var i = 0; i < 5; i++) cache.getIndex(i)],
        ['v2', 'v4', 'v3', 'v1', 'v0'],
      );
    });

    test('容量满了以后新条目仍然进得来（浏览历史不会冻结）', () {
      // 浏览历史是 capacity 5000 的 LRUCache（setting.dart），这里用小容量
      // 复现同一个边界：满了之后 put 新条目必须淘汰最旧项、让新项进来。
      final cache = LRUCache<int, String>(2);
      cache.put(1, 'a');
      cache.put(2, 'b');
      cache.put(3, 'c'); // 淘汰最旧的 1

      expect(cache.contains(3), isTrue, reason: '新条目必须进得来');
      expect(cache.contains(2), isTrue, reason: '较新的 2 应保留');
      expect(cache.contains(1), isFalse, reason: '最旧的 1 应被淘汰');
      expect(cache.length, 2);
    });
  });
  group('BUG-B 内置表情不应重复 (audit #8)', () {
    test('内置表情表的 key 唯一', () {
      final keys = xDaoPhrases.map((phrase) => phrase.key).toList();
      final dupes = <String>{};
      final seen = <String>{};
      for (final key in keys) {
        if (!seen.add(key)) dupes.add(key);
      }
      expect(dupes, isEmpty, reason: '常量表里不许有重复表情');
      expect(keys.length, seen.length);
      expect(
        keys.where((key) => key == '･ﾟ( ﾉヮ´ )').length,
        1,
        reason: '这条曾经在表里出现两次，表情面板出现两个相同格子',
      );
    });

    test('mergePhraseLists([], xDaoPhrases) 不引入重复', () {
      final merged = mergePhraseLists([], xDaoPhrases);
      final keys = merged.map((phrase) => phrase.key).toList();
      expect(keys.length, keys.toSet().length);
      expect(merged.length, xDaoPhrases.length);
    });

    test('两份列表各自的重复也去掉，顺序保持先 base 后 additional', () {
      final merged = mergePhraseLists(
        [
          const Phrase('a', 'A'),
          const Phrase('b', 'B'),
          const Phrase('a', 'A2'),
        ],
        [
          const Phrase('b', 'B2'),
          const Phrase('c', 'C'),
          const Phrase('c', 'C2'),
        ],
      );

      expect(merged.map((phrase) => phrase.key).toList(), ['a', 'b', 'c']);
      expect(merged[0].value, 'A', reason: '同一 key 保留最先出现的那一条');
    });
  });
}
