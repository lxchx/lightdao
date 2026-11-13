# anchored_slivers 设计文档

> 状态：原型（0.1.0-dev）。库代码 `anchored_slivers/lib/`，测试 `anchored_slivers/test/`。
> 先例调研的逐条出处见 `prior-art.md`；本文只引用结论。

## 1. 要解决的问题

`SliverList` 的布局是"从第一个存活的 child 往下累加"：每个 child 的位置 = 上一个 child 的位置 + 它的高度
（Flutter 3.32.4 `rendering/sliver_list.dart:258-262`）。第一个存活的 child 通常在屏幕外的缓存区（默认 250px）。
它或它下面任何一项高度变了，后面所有项都跟着平移，而滚动位置（`ScrollPosition.pixels`）没人动——
屏幕上看就是内容自己跳了一下。瀑布流（`flutter_staggered_grid_view` 的 `SliverMasonryGrid`）是同一个毛病。

目标：视口里有一条"锚线"（默认在可见区域正中），压在锚线上的 item 不因为别的 item 变高变矮、插入删除而移动。
其余行为与 `SliverList` 相同，能放进任何 `CustomScrollView`。

## 2. 方案对比

| 方案 | 做法 | 结论 |
|---|---|---|
| A. 仍从上往下排，事后用 `scrollOffsetCorrection` 补偿 | 记住锚点旧位置，排完算出位移 δ，上报校正让 viewport 改 pixels 重排 | 可行但差：**每次**高度变化都要多跑一轮 viewport 布局；校正量取决于"上面所有项"的累加，一次算不准就会撞 `maxLayoutCycles`（viewport 重排有次数上限，超了直接抛错）；瀑布流里各列位移不同，**一个标量 δ 补不了多列** |
| B. `CustomScrollView.center` 双向列表 | 把数据在锚点处切成两个 sliver，一个向上长一个向下长 | 只解决"往头部追加"；锚点是数据里的固定位置，不随滚动移动；要用户把一个列表拆成两个 delegate，接口不通用 |
| C. 自建 Viewport / Scrollable | fork 框架的 viewport 和 scrollable（lightdao 里的 TsukuyomiList、scrollable_positioned_list 都是这条路） | 能做，但要么不兼容标准 sliver，要么得长期跟着框架内部改；违背"兼容 sliver 生态是硬要求" |
| **D. 在 sliver 内部"从锚点向外排"（采用）** | 自定义 `RenderSliver`：先定住锚点 child 的位置，再向上、向下分别排 | 高度变化被锚点**上方**吸收，锚点和它下面的东西位置天然不变，**不需要动 pixels**，没有多余的布局轮次；每列各有一个锚点，所以瀑布流同样成立 |

D 的代价是"第 0 项不一定在偏移 0"——上方高度变了以后，列表开头会漂到负数或正数偏移。这笔账只在一个地方结：
**当第 0 项被真正建出来时**（用户滚回了顶部附近），上报一次 `scrollOffsetCorrection` 把整体平移回去。
这次校正同时改了 pixels 和所有 child 的偏移，屏幕上不动，且一轮内只发一次、之后的那轮必然不再发，所以不会循环。
这和 CSS scroll anchoring 的思路一致（选一个锚点节点、记它的位置、布局后保持），区别是 Web 是事后调滚动位置，这里直接在布局里做。

## 3. 布局算法（`RenderSliverAnchoredMasonry.performLayout`）

列表是"只有 1 列的瀑布流"，两者共用一个 render 对象；`RenderSliverAnchoredList` 只是把列数钉成 1。下面的"列"在代码里叫 lane。

每个 child 的 parentData 里存三样：所在列 `lane`、主轴偏移 `offset`、上次布局时的下标 `lastIndex`。
（另存一份是因为框架的 element 在重建时会改写 `layoutOffset`，不能拿它当事实来源。）

1. **选锚点**（用上一帧的几何）：每列里离锚线最近的那个 child 是该列的锚点；这些列锚点按下标排序取中间那个作"主锚点"。
   例外：某列的第一项就是全表开头且已经露在屏幕里，则锚住这一项（列表顶部露出时顶边不动，见 §5）。
   controller 设了 `pinnedIndex` 且那一项存活时，强制用它。
2. **A 遍**：按下标顺序把所有存活 child 重新 layout，在各自的列里从上往下临时堆起来。
3. **B 遍**：每列整体平移，使该列的锚点回到它原来的偏移。到这里，尺寸变化已经全部被推到锚点上方（或下方，对锚点之后的项）。
4. **向上补**：只要有哪一列的顶端还在缓存区之内，就建前一项，放进"顶端最靠下"的那一列（向下贪心的镜像）。
   这一项如果以前被排过，用记下来的列（`_laneMemo`：下标 → 列），这样往回滚看到的排布和当初一样。
5. **向下补**：只要有哪一列的底端还在缓存区之内，就建下一项，放进当前最短的列（并列时取最左，于是第一排从左到右排满）。
6. **回收**：两端完全离开缓存区的 child 回收，但每列至少留一个。
7. **对账顶部**：
   - 第 0 项存活且 `scrollOffset == 0`：所有列的顶端直接归零（此时顶部就在屏幕上，必须对齐）。
   - 第 0 项存活但还没滚到 0：以第 0 项所在的列为准，它的顶端不是 0 就上报校正（屏幕不动）。
     其它列若没对齐，**在用户滚动的同时**按"本帧滚动距离的一半"慢慢拉回，到顶时就齐了。
   - 第 0 项还没建出来，但偏移已经 ≤ 0（上面的内容比估计的多）：上报一次校正，按平均高度给上面留出空间。
8. **上报几何**：与 `RenderSliverList` 相同的方式（`estimateMaxScrollOffset`、`calculatePaintOffset`…）。

**远距离跳转**：滚动位置一下跳到所有存活 child 之外超过一屏（`jumpTo`、拖滚动条）时，不逐项建过去，而是按平均高度估一个下标重新起头；
跳到 0 时固定从第 0 项起头。`controller.jumpToIndex` 走同一条路，但下标是精确的。

**列数变化**：以主锚点为种子重排——主锚点保持原来的主轴偏移，新列号按它原先的横向相对位置换算（原来在最右边，新布局里还在最右边）；
它后面的项向下贪心，前面的项向上镜像贪心。于是原来中间那一排的 item 在新布局里仍然围着主锚点。
只改宽度不改列数时不重排，各列锚点照常保持。

## 4. 接口

向 `SliverList` / `SliverMasonryGrid` 的惯例看齐：同名的构造器、同样的 delegate、controller 是可选的。

```dart
SliverAnchoredList({required SliverChildDelegate delegate, double anchorAlignment = 0.5, SliverAnchorController? controller})
SliverAnchoredList.builder({required itemBuilder, itemCount, findChildIndexCallback, anchorAlignment, controller, …})
SliverAnchoredList.list({required children, anchorAlignment, controller, …})

SliverAnchoredMasonry.count({required delegate, required int crossAxisCount, mainAxisSpacing, crossAxisSpacing, anchorAlignment, controller})
SliverAnchoredMasonry.extent({required delegate, required double maxCrossAxisExtent, …})   // 列数随宽度变

class SliverAnchorController extends ChangeNotifier {   // anchorIndex / laneCount 变了会在帧末通知监听者
  int? get anchorIndex;      // 上一次布局的主锚点下标（读）
  int? get laneCount;        // 上一次布局的列数（读）
  int? pinnedIndex;          // 设：强制以某一项为锚点（那一项存活期间有效）
  bool jumpToIndex(int index, {double alignment = 0.0});   // 设：把某一项放到可见区域的某个比例位置；没挂到 sliver 上时返回 false
}
```

- `anchorAlignment`：锚线在"本 sliver 可见部分"里的位置，0 顶、0.5 中、1 底。聊天类界面可设 1.0。
- 头部插入/删除要保持位置，需要和 `SliverList` 一样给 child 带 key 并提供 `findChildIndexCallback`——
  这是框架用来认出"这是同一项、只是下标变了"的唯一途径，库没有另造机制。

## 5. 任务书里点名的几种情况

| 情况 | 行为 | 测试 |
|---|---|---|
| 锚点怎么选 | 默认视口中线；`anchorAlignment` 可配；`pinnedIndex` 可钉死 | `jumpToIndex and pinnedIndex` |
| 锚点自己变高 | 锚点的**顶边**不动，向下长 | `anchor itself resizes` |
| 拖动中 / 惯性滚动中发生变化 | 一样保持；不改 pixels，所以不打断手势和惯性 | `holds while dragging and during a fling` |
| 在列表顶部（offset=0） | 顶边不动，内容向下长（和 CSS scroll anchoring 在偏移 0 处不锚定是同一个取舍：否则顶上会露出空白） | `at the top the leading edge stays put` |
| 滚回顶部 / 滚到底部 | 顶部重新对齐到 0；能到达真正的末尾 | `offsets reconcile…`、`reaches the true end`、fuzz 收尾断言 |
| 头部插入 | 带 key + `findChildIndexCallback` 时锚点不动（大批插入、与存活区间重叠的小批插入、上方删除都测了） | `head insertion keeps the anchor` |
| 和其它 sliver 组合 | `SliverAppBar(pinned)` + `SliverToBoxAdapter` + 本 sliver + `SliverList` | `works between other slivers` |
| 瀑布流排布规则 | 第一排左到右，之后最短列 | `placement rule` |
| 瀑布流中心排不动 | 压在锚线上的每一项都不动 | `row at the anchor line stays…`、fuzz |
| 列数变化 | 主锚点屏幕位置不变；原中心排其它项仍在视口内（5→1 列时至少 2 个可见） | `lane count change 800→480/320/160, 320→800` |

## 6. 验证

- `flutter test`：35 个用例全过（example 另有 6 个截图用例）；`flutter analyze` 0 问题（Flutter 3.32.4）。
- **对照（红路径）**：同样的操作放在普通 `SliverList` 上，锚点位移 > 100px（用例 `red path: plain SliverList jumps`）。
- **变异检验**：把 B 遍那一行（各列平移回锚点）关掉，34 个里 19 个失败；恢复后全过。说明这些断言确实在检查锚定，而不是恒真。
- **随机压力**（`test/stress_test.dart`）：1/3/5 列 × 3 个种子，各 400 步随机"滚动 / 远跳 / 改高度"，每步断言：
  压在锚线上的项位移 ≤ 0.5px、存活项互不重叠、视口不空白、框架无异常；收尾断言回到顶部对齐、能到达末尾。
  这套压力测试当场抓出过两个真 bug（跳到 0 时没回到第 0 项；对账用的列随锚点变化导致校正来回振荡撞上布局轮次上限），都已修。
- 写 demo 的人（另一个 agent，只拿到公开接口）反馈了三个接口问题，已修并加了用例：同一帧内替换 sliver 时 controller 断言失败；
  controller 没有变更通知；`jumpToIndex` 未挂载时断言而不是空操作。
- **多尺寸截图**：`docs/shots/widget/` 30 张（6 种尺寸 × 列表中段 / 改高度前后 / 瀑布流中段 / 侧栏打开），由 `example/test/screenshots_test.dart` 生成。
  改高度前后两张逐像素比对：锚线以下差异为 0，以上有差异。
- 另测：`reverse: true`、横向、空表/短表/增长/缩短、KeepAlive（`TextField` 滚走再回来内容还在）、`animateTo` 途中改高度。

## 7. 已知限制（原型阶段，按影响大小排）

1. **瀑布流的排布依赖历史**。item 的列号一旦定下就不再变（否则变高一项会让别的项横向换列，比纵向跳更糟）。
   所以上方的项变高以后，布局不再等于"拿最终高度从头贪心排一遍"的结果，各列在顶部附近可能参差。回到顶部时各列会被对齐到 0，
   其中非基准列的残余错位是**看得见的一次小位移**（滚动途中已按速度的一半吸收了大部分）。
2. **滚动条位置是估算的**。总长度与当前偏移都基于"已见过的平均高度"，上方内容变化时滚动条拇指会轻微移动；内容本身不动。
   `ScrollController.offset` 因而不是"距离真正顶部的像素数"的可靠度量——要定位请用 `anchorIndex` / `jumpToIndex`。
3. **`animateTo` 的终点是偏移量而不是某一项**。动画途中上方内容变化，动画仍停在那个偏移数值上（已测不抛错、能到达），
   但对应的内容可能不是发起时想的那一项。要"滚到第 N 项"目前只有不带动画的 `jumpToIndex`；带动画的版本没做。
4. **横向排布不看文字方向**：瀑布流第 0 列总在左边，RTL 下没有镜像。
5. **每帧会重新 layout 所有存活 child**（`SliverList` 也是如此，但这里多一遍平移）。未做性能基准。
6. `_laneMemo`（下标→列号）随滚过的项数线性增长（每项一个 int），没有上限。
7. 未覆盖：语义树/无障碍顺序、`SliverChildDelegate` 没有 `childCount` 的无限列表下的远跳估算、嵌套 `NestedScrollView`、
   瀑布流里的 KeepAlive、`SliverMainAxisGroup`/`SliverCrossAxisGroup` 内部。
8. item 之间的纵向间距用 `mainAxisSpacing`（瀑布流）或放进 item 自己里面（列表没有间距参数）；外边距用 `SliverPadding`。
9. 没有在真机/模拟器上用真实触摸和真实图片加载验证过手感；全部结论来自 widget test。

## 8. 自己拍板的事（用户不在场）

- **两个组件做成一个 render 对象**：列表 = 1 列瀑布流。少一半代码，两边的锚定行为必然一致。
- **包名 `anchored_slivers`**：pub.dev 上未被占用（查过 API 返回 404）；类名用 `SliverAnchored*`，与 `SliverFixedExtentList` 这类"Sliver+修饰+形态"的命名一致。
- **偏移 0 处不锚定**（顶边不动）：见 §5。
- **列号不重排**：见 §7.1。
- **不引入第三方依赖**：没有复用 `flutter_staggered_grid_view` 的代码——它的历史只靠两个栈，换成从锚点向外排之后没有可复用的部分。
