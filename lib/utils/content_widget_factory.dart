import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/ui/widget/ref_view.dart';

import 'kv_store.dart';

class MaskedContainer extends StatefulWidget {
  final Widget child;

  MaskedContainer({required this.child});

  @override
  State<MaskedContainer> createState() => _MaskedContainerState();
}

class _MaskedContainerState extends State<MaskedContainer> {
  bool _isMasked = true;

  void _toggleMask() {
    setState(() {
      _isMasked = !_isMasked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleMask,
      child: Stack(
        children: [
          widget.child,
          if (_isMasked)
            Positioned.fill(
              child: Container(
                color: Theme.of(context).colorScheme.primary,
                //child: ImageFiltered(
                //  imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                //),
              ),
            ),
        ],
      ),
    );
  }
}

class ContentWidgetFactory extends WidgetFactory {
  final int inRefView;
  final String? poUserHash;
  final LRUCache<int, Future<RefHtml>>? refCache;
  final bool inPopView;
  final bool isThreadFirstOrForumPreview;
  final bool refMustCollapsed;
  late BuildOp refOp;
  late BuildOp hidableOp;
  final Function(File image, Object? heroTag)? onImageEdit;

  ContentWidgetFactory(
      {required this.inRefView,
      required this.poUserHash,
      required this.refCache,
      required this.inPopView,
      this.refMustCollapsed = false,
      this.isThreadFirstOrForumPreview = false,
      this.onImageEdit}) {
    refOp = BuildOp(
      onRenderBlock: (meta, child) {
        return RefView(
          inRefView: inRefView,
          inPopView: inPopView,
          refId: int.tryParse(
              refPattern.allMatches(meta.element.text).first.group(2) ?? '')!,
          poUserHash: poUserHash,
          refCache: refCache,
          isThreadFirstOrForumPreview: isThreadFirstOrForumPreview,
          mustCollapsed: refMustCollapsed,
          onImageEdit: onImageEdit,
        );
      },
    );
    hidableOp = BuildOp.inline(
      onRenderInlineBlock: (tree, child) {
        return MaskedContainer(child: child);
      },
    );
  }

  static final refPattern = RegExp('>>(No.)?(\\d+)');

  @override
  void parse(BuildTree meta) {
    final e = meta.element;
    if (e.localName == 'font' &&
        e.attributes['color'] == '#789922' &&
        refPattern.hasMatch(e.text)) {
      meta.register(refOp);
      return;
    } else if (e.localName == 'hidable') {
      meta.register(hidableOp);
      return;
    }
    super.parse(meta);
  }
}
