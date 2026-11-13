import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 性能诊断：profile 构建下把每一帧的耗时打到日志里（logcat 里搜 "FT "）。
///
/// 每行一批帧，格式 `FT <build微秒>,<raster微秒>,<总跨度微秒>;...`：
/// build = Dart 侧构建+布局+绘制指令（UI 线程），raster = 光栅线程，
/// 总跨度 = 从 vsync 到这一帧光栅完成。release / debug 下不启用。
void installFrameLog() {
  if (!kProfileMode) return;
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    final sb = StringBuffer('FT ');
    for (final t in timings) {
      sb
        ..write(t.buildDuration.inMicroseconds)
        ..write(',')
        ..write(t.rasterDuration.inMicroseconds)
        ..write(',')
        ..write(t.totalSpan.inMicroseconds)
        ..write(';');
    }
    debugPrint(sb.toString());
  });
}
