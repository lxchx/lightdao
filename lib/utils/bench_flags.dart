/// 性能测量用的单变量开关。正常构建全部为 false，不改变任何行为。
///
/// 用法：flutter build apk --profile --dart-define=LD_BENCH_OFF=fade,img
/// 每个名字关掉一类"可能拖慢绘制"的东西，用来量它到底占多少：
///   fade  折叠正文底部的渐隐（ShaderMask，离屏图层）
///   img   帖子配图（换成同尺寸的色块）
class BenchFlags {
  static const String _off = String.fromEnvironment('LD_BENCH_OFF');
  static final Set<String> _set = _off.split(',').toSet();
  static bool off(String name) => _off.isNotEmpty && _set.contains(name);
}
