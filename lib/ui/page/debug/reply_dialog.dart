import 'package:flutter/material.dart';

/// 一个专门用于调试和验证复杂回复弹窗布局的页面。
///
/// 这个页面包含一个按钮，用于弹出一个测试对话框。
/// 该对话框精确地复刻了最终解决方案中的布局逻辑，
/// 包括全屏/非全屏切换、安全区处理、键盘响应以及动态内容调整。
class ReplyDialogTestPage extends StatefulWidget {
  const ReplyDialogTestPage({super.key});

  @override
  State<ReplyDialogTestPage> createState() => _ReplyDialogTestPageState();
}

class _ReplyDialogTestPageState extends State<ReplyDialogTestPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回复弹窗调试页'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showTestReplyDialog(context),
                icon: const Icon(Icons.bug_report),
                label: const Text('打开测试弹窗'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '测试指南:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('1. 在弹窗内切换"全屏模式"。'),
                      Text('2. 切换"显示标题/作者"测试动画。'),
                      Text('3. 切换"显示短语选择器"，观察全屏下输入框是否被顶起。'),
                      Text('4. 在非全屏下，切换"强制内容溢出"测试滚动。'),
                      Text('5. 在两种模式下点击输入框，测试键盘交互。'),
                      Text('6. 观察顶部内容是否始终在安全区内。'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTestReplyDialog(BuildContext pageContext) {
    // 弹窗内部状态
    bool isFullscreen = false;
    bool showTitleAndAuthor = false;
    bool showPhrasePicker = false;
    bool forceOverflow = false; // 用于在非全屏模式下测试滚动

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            final view = View.of(context);
            final systemTopPadding = MediaQueryData.fromView(view).padding.top;

            //======= UI 构建辅助函数 (与真实弹窗逻辑解耦) =======

            Widget buildTopBar() {
              return Row(
                children: [
                  // 左侧菜单，为了布局对齐
                  MenuAnchor(
                    menuChildren: <Widget>[
                      MenuItemButton(
                        onPressed: () => setState(
                          () => showTitleAndAuthor = !showTitleAndAuthor,
                        ),
                        child: Text(showTitleAndAuthor ? '隐藏标题/作者' : '显示标题/作者'),
                      ),
                      MenuItemButton(
                        onPressed: () => setState(
                          () => showPhrasePicker = !showPhrasePicker,
                        ),
                        child: Text(showPhrasePicker ? '隐藏短语选择器' : '显示短语选择器'),
                      ),
                      if (!isFullscreen)
                        MenuItemButton(
                          onPressed: () =>
                              setState(() => forceOverflow = !forceOverflow),
                          child: Text(forceOverflow ? '取消内容溢出' : '强制内容溢出'),
                        ),
                    ],
                    builder: (_, MenuController controller, Widget? child) {
                      return IconButton(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: const Icon(Icons.more_vert),
                      );
                    },
                  ),
                  const Spacer(),
                  Container(
                    height: 3,
                    width: 50,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => isFullscreen = !isFullscreen),
                    icon: Icon(
                      isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                  ),
                ],
              );
            }

            Widget buildAnimatedTitleAndAuthorSection() {
              return AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: showTitleAndAuthor
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 2,
                              child: TextField(
                                decoration: InputDecoration(labelText: '标题'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              flex: 1,
                              child: TextField(
                                decoration: InputDecoration(labelText: '作者'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            }

            Widget buildTextField() {
              return isFullscreen
                  ? const Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: TextField(
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            labelText: '全屏输入框',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(16),
                      child: TextField(
                        maxLines: 5,
                        minLines: 3,
                        decoration: InputDecoration(
                          labelText: '非全屏输入框',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    );
            }

            Widget buildBottomControls() {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: null,
                      icon: Icon(Icons.emoji_emotions_outlined),
                    ),
                    IconButton(
                      onPressed: null,
                      icon: Icon(Icons.photo_outlined),
                    ),
                    IconButton(onPressed: null, icon: Icon(Icons.mic_outlined)),
                    IconButton(onPressed: null, icon: Icon(Icons.attach_file)),
                    ElevatedButton(onPressed: null, child: Text('发送')),
                  ],
                ),
              );
            }

            Widget buildPhrasePicker() {
              return AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Container(
                  height: showPhrasePicker ? 150 : 0,
                  color: Colors.teal.withAlpha(25),
                  child: const Center(child: Text('短语选择器区域')),
                ),
              );
            }

            //======= 最终布局逻辑 (精确复刻) =======
            Widget finalLayout;
            if (isFullscreen) {
              finalLayout = Padding(
                padding: EdgeInsets.only(top: systemTopPadding),
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  resizeToAvoidBottomInset: true,
                  body: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: buildTopBar()),
                        SliverToBoxAdapter(
                          child: buildAnimatedTitleAndAuthorSection(),
                        ),
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Column(
                            children: [
                              buildTextField(),
                              buildBottomControls(),
                              buildPhrasePicker(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              finalLayout = Padding(
                padding: EdgeInsets.only(
                  top: systemTopPadding,
                  bottom: viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildTopBar(),
                        buildAnimatedTitleAndAuthorSection(),
                        buildTextField(),
                        buildBottomControls(),
                        buildPhrasePicker(),
                        if (forceOverflow)
                          Container(
                            height: 200,
                            color: Colors.red.withAlpha(25),
                            alignment: Alignment.center,
                            child: const Text('用于强制溢出的额外内容'),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return finalLayout;
          },
        );
      },
    );
  }
}
