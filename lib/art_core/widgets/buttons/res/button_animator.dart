
import 'package:flutter/animation.dart';

class ButtonAnimator {
  final AnimationController controller;
  late final Animation<double> scaleAnimation;
  late final Animation<double> hoverAnimation;

  ButtonAnimator(TickerProvider vsync, Duration duration)
      : controller = AnimationController(vsync: vsync, duration: duration) {
    scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
    hoverAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  void onTapDown() => controller.forward();
  void onTapUp() => controller.reverse();
  void onTapCancel() => controller.reverse();
  void onHover(bool isHovering) {
    if (isHovering) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  void dispose() => controller.dispose();
}