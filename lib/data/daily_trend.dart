import 'package:flutter/foundation.dart';

@immutable
class Trend {
  final int rank;
  final int heat;
  final String board;
  final bool isNew;
  final int threadId;
  final String content;

  const Trend({
    required this.rank,
    required this.heat,
    required this.board,
    required this.isNew,
    required this.threadId,
    required this.content,
  });

  @override
  String toString() {
    return 'Trend(rank: $rank, heat: $heat, board: $board, isNew: $isNew, threadId: $threadId, content: $content)';
  }
}

@immutable
class DailyTrend {
  final DateTime date;
  final List<Trend> trends;

  const DailyTrend({required this.date, required this.trends});

  static final _dateRegex = RegExp(r'@(\d{4}-\d{2}-\d{2})');
  static final _trendRegex = RegExp(r'(\d+)\. Trend (\d+) \[(.*?)\]( New)?');
  static final _idRegex = RegExp(r'&gt;&gt;No\.(\d+)');

  factory DailyTrend.fromContent(String content) {
    var trendsContent = content;
    final dateMatch = _dateRegex.firstMatch(content);
    final date = dateMatch != null
        ? DateTime.parse(dateMatch.group(1)!)
        : DateTime.now();

    if (dateMatch != null) {
      trendsContent = content.substring(dateMatch.end).trim();
    }

    final trends = <Trend>[];
    final trendBlocks = trendsContent.split('—————<br />\n<br />');

    for (final block in trendBlocks) {
      final trendLines = block.trim().split('<br />\n');
      if (trendLines.length < 2) continue;

      final titleLine = trendLines.firstWhere(
        (line) => _trendRegex.hasMatch(line),
        orElse: () => '',
      );
      if (titleLine.isEmpty) continue;

      final idLine = trendLines.firstWhere(
        (line) => _idRegex.hasMatch(line),
        orElse: () => '',
      );
      if (idLine.isEmpty) continue;

      final trendMatch = _trendRegex.firstMatch(titleLine);
      final idMatch = _idRegex.firstMatch(idLine);

      if (trendMatch != null && idMatch != null) {
        final rank = int.parse(trendMatch.group(1)!);
        final heat = int.parse(trendMatch.group(2)!);
        final board = trendMatch.group(3)!;
        final isNew = trendMatch.group(4) != null;
        final threadId = int.parse(idMatch.group(1)!);

        final description = trendLines
            .where(
              (line) =>
                  !line.contains('&gt;&gt;No.') &&
                  !_trendRegex.hasMatch(line) &&
                  !_dateRegex.hasMatch(line),
            )
            .join('\n')
            .replaceAll(RegExp(r'<br\s*/?>'), '')
            .replaceAll(RegExp(r'<font[^>]*>'), '')
            .replaceAll('</font>', '')
            .trim();

        trends.add(
          Trend(
            rank: rank,
            heat: heat,
            board: board,
            isNew: isNew,
            threadId: threadId,
            content: description,
          ),
        );
      }
    }

    return DailyTrend(date: date, trends: trends);
  }

  @override
  String toString() => 'DailyTrend(date: $date, trends: $trends)';
}
