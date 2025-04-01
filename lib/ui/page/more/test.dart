import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:tsukuyomi_list/tsukuyomi_list.dart';

class ChatItem {
  final String id;
  final String msg;
  bool isLoading;
  double width;
  double height;

  ChatItem({
    required this.id,
    required this.msg,
    this.isLoading = true,
    this.width = 0,
    this.height = 0,
  });
}

class TestPage extends StatefulWidget {
  const TestPage({
    super.key,
  });

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  ScrollController scrollController = ScrollController();
  TsukuyomiListController? tsukuyomiListController;

  List<ChatItem> chatListContents = List.generate(
    30,
    (index) => ChatItem(
      id: index.toString(),
      msg: 'Message $index',
    ),
  );

  @override
  void initState() {
    super.initState();

      tsukuyomiListController = TsukuyomiListController();


    for (var item in chatListContents) {
      Future.delayed(Duration(seconds: Random().nextInt(3) + 3), () {
        setState(() {
          item.isLoading = false;
          item.width = Random().nextInt(100) + 50.0;
          item.height = Random().nextInt(100) + 50.0;
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _insertNewItem(int pos) {
    setState(() {
      final newIndex = chatListContents
              .map((item) => int.parse(item.id))
              .reduce((max, value) => max > value ? max : value) +
          1;
      final newItem = ChatItem(
        id: newIndex.toString(),
        msg: 'Message $newIndex',
      );
        tsukuyomiListController!
            .onInsertItem(pos, () => chatListContents.insert(pos, newItem));

      Future.delayed(Duration(seconds: Random().nextInt(3) + 3), () {
        setState(() {
          newItem.isLoading = false;
          newItem.width = Random().nextInt(100) + 50.0;
          newItem.height = Random().nextInt(100) + 50.0;
        });
      });
    });
  }

  Widget _renderList() {
    itemBuilder(context, index) => Align(
          key: Key(chatListContents[index].id),
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onLongPress: () {
              setState(() {
                chatListContents[index].isLoading = true;
                chatListContents[index].width = 0;
                chatListContents[index].height = 0;
              });
              Future.delayed(Duration(seconds: Random().nextInt(3) + 3), () {
                setState(() {
                  chatListContents[index].isLoading = false;
                  chatListContents[index].width = Random().nextInt(100) + 50.0;
                  chatListContents[index].height = Random().nextInt(100) + 50.0;
                });
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Card(
                child: chatListContents[index].isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        width: chatListContents[index].width,
                        height: chatListContents[index].height,
                        color: Colors.blue,
                        child: Center(
                          // 使用新的序号显示
                          child: Text(
                            chatListContents[index].id,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );

    return TsukuyomiList.builder(
            itemCount: chatListContents.length,
            itemBuilder: itemBuilder,
            controller: tsukuyomiListController,
            physics: null,
            anchor: null,
            trailing: true,
            debugMask: true,
            ignorePointer: false,
            scrollDirection: Axis.vertical,
            initialScrollIndex: chatListContents.length > 10 ? 10 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.fromMediaQuery(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('测试页面'),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        child: _renderList(),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: () => _insertNewItem(0),
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  int selectedPosition = 0;
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              '选择插入位置: $selectedPosition',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Slider(
                            value: selectedPosition.toDouble(),
                            min: 0,
                            max: chatListContents.length.toDouble(),
                            divisions: chatListContents.length,
                            label: selectedPosition.toString(),
                            onChanged: (double value) {
                              setState(() {
                                selectedPosition = value.round();
                              });
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _insertNewItem(selectedPosition);
                              },
                              child: const Text('确认插入'),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('添加'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                if (chatListContents.isNotEmpty) {
                  tsukuyomiListController!.onRemoveItem(
                    1,
                    () => chatListContents.removeAt(1),
                  );
                }
              });
            },
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  int selectedPosition = 0;
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              '选择删除位置: $selectedPosition',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Slider(
                            value: selectedPosition.toDouble(),
                            min: 0,
                            max: (chatListContents.length - 1).toDouble(),
                            divisions: chatListContents.isEmpty ? 1 : chatListContents.length - 1,
                            label: selectedPosition.toString(),
                            onChanged: (double value) {
                              setState(() {
                                selectedPosition = value.round();
                              });
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                if (chatListContents.isNotEmpty) {
                                  tsukuyomiListController!.onRemoveItem(
                                    selectedPosition,
                                    () => chatListContents.removeAt(selectedPosition),
                                  );
                                }
                              },
                              child: const Text('确认删除'),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
            icon: const Icon(Icons.delete),
            label: const Text('删除'),
          ),
        ],
      ),
    );
  }
}