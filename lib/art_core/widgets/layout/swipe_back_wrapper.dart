import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SwipeBackWrapper extends StatelessWidget {
  final Widget child;

  const SwipeBackWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        // If swiping right starting near the left edge (within 50 pixels)
        if (details.delta.dx > 8 && (details.globalPosition.dx - details.delta.dx) < 50) {
          if (context.canPop()) {
            context.pop();
          }
        }
      },
      child: child,
    );
  }
}
