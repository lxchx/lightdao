import 'dart:ui';
import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/ui/widget/ref_view.dart';

class PopRefViewPage extends StatelessWidget {
  const PopRefViewPage({
    super.key,
    required this.refId,
    this.poUserHash,
  });

  final int refId;
  final String? poUserHash;

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.fromMediaQuery(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pop(context);
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
          child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                child: LayoutBuilder(builder: (context, constraints) {
                  return ListView(
                    children: [
                      // 为了在ListView中居中
                      Container(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48,
                        ),
                        child: Center(
                          child: RefView(
                            refId: refId,
                            inRefView: 0,
                            inPopView: true,
                            poUserHash: poUserHash,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              )),
        ),
      ),
    );
  }
}
