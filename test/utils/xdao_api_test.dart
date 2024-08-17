import 'package:lightdao/data/xdao/ref.dart';
import 'package:test/test.dart';

import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/utils/xdao_api.dart';

void main() {
  group('fetchForumThreads', () {
    test('returns a list of ThreadJson if the http call completes successfully', () async {
      const forumId = 4;
      const page = 1;

      final threads = await fetchForumThreads(forumId, page, null);

      expect(threads, isA<List<ThreadJson>>());
      expect(threads.isNotEmpty, true);
    });

    test('throws an XDaoApiMsgException if the forumId does not exist', () async {
      const forumId = -1;
      const page = 1;

      expect(() => fetchForumThreads(forumId, page, null), throwsA(isA<XDaoApiMsgException>()));
    });

    test('throws an ArgumentError if page is less than or equal to 0', () async {
      const forumId = 4;
      const page = -1;

      expect(() => fetchForumThreads(forumId, page, null), throwsA(isA<ArgumentError>()));
    });
  });

  group('getThread', () {
    test('returns a ThreadJson if the http call completes successfully', () async {
      const threadId = 63452866;
      const page = 1;

      final thread = await getThread(threadId, page, null);

      expect(thread, isA<ThreadJson>());
    });

    test('throws an XDaoApiMsgException if the threadId does not exist', () async {
      const threadId = -1;
      const page = 1;

      expect(() => getThread(threadId, page, null), throwsA(isA<XDaoApiMsgException>()));
    });

    test('throws an ArgumentError if page is less than or equal to 0', () async {
      const threadId = 63452788;
      const page = -1;

      expect(() => getThread(threadId, page, null), throwsA(isA<ArgumentError>()));
    });
  });

  group('fetchRef', () {
    test('returns a RefJson if the http call completes successfully', () async {
      const id = 63443442;

      final ref = await fetchRef(id, null);

      expect(ref, isA<RefJson>());
    });

    test('throws an XDaoApiNotSuccussException if the id does not exist', () async {
      const id = -1;

      expect(() => fetchRef(id, null), throwsA(isA<XDaoApiNotSuccussException>()));
    });
  });
}
