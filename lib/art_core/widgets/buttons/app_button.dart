
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_animator.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_behavior.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_content.dart';
import 'package:playspot/art_core/widgets/buttons/res/button_style_config.dart';
import '../../theme/app_colors.dart'; // ✅ المسار صح

class AppButton extends StatefulWidget {
  final ButtonConfig buttonConfig;
  final ButtonBehavior behavior;
  final ButtonContent content;

  AppButton({
    super.key,
    ButtonConfig? buttonConfig,
    this.behavior = const TapBehavior(isEnabled: false),
    this.content = const ButtonContent(label: 'Button'),
  }) : buttonConfig = buttonConfig ?? ButtonConfig();

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late ButtonAnimator _animator;

  @override
  void initState() {
    super.initState();
    _animator = ButtonAnimator(this, widget.buttonConfig.animationDuration);
  }

  @override
  void dispose() {
    _animator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _animator.onTapDown(),
      onTapUp: (details) => _animator.onTapUp(),
      onTapCancel: () => _animator.onTapCancel(),
      onTap: () => widget.behavior.handleTap(context),
      child: AnimatedBuilder(
        animation: _animator.controller,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.behavior.isEnabled ? _animator.scaleAnimation.value : 1.0,
            child: MouseRegion(
              onEnter: (_) => _animator.onHover(true),
              onExit: (_) => _animator.onHover(false),
              child: Container(
                width: widget.buttonConfig.width,
                height: widget.buttonConfig.height,
                padding: widget.buttonConfig.padding,
                margin: widget.buttonConfig.margin,
                decoration: _buildDecoration(),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(widget.buttonConfig.borderRadius),
                    splashColor: widget.buttonConfig.backgroundColor.withOpacity(0.3),
                    highlightColor: widget.buttonConfig.backgroundColor.withOpacity(0.1),
                    child: Center(child: _buildChild()),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Decoration _buildDecoration() {
    if (widget.buttonConfig.isOutlined) {
      return BoxDecoration(
        color: widget.buttonConfig.backgroundColor == AppColors.primary
            ? Colors.transparent
            : widget.buttonConfig.backgroundColor,
        border: Border.all(
          color: widget.behavior.isEnabled
              ? (widget.buttonConfig.borderColor ?? widget.buttonConfig.backgroundColor)
              : widget.buttonConfig.disabledColor,
          width: .3,
        ),
        borderRadius: BorderRadius.circular(widget.buttonConfig.borderRadius),
      );
    }
    else {
      return BoxDecoration(
        gradient: widget.behavior.isEnabled  // 👈
            ? widget.buttonConfig.gradient
            : null,
        color: widget.buttonConfig.gradient != null
            ? null
            : widget.behavior.isEnabled
            ? widget.buttonConfig.backgroundColor
            : widget.buttonConfig.disabledColor,
        borderRadius: BorderRadius.circular(widget.buttonConfig.borderRadius),
        boxShadow: widget.behavior.isEnabled
            ? [
          if (widget.buttonConfig.glowColor != null)  // 👈
            BoxShadow(
              color: widget.buttonConfig.glowColor!.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            )
          else
            BoxShadow(
              color: AppColors.black.withOpacity(0.1),
              blurRadius: 6.0,
              offset: const Offset(0, 5),
            ),
        ]
            : null,
      );
    }
  }
  Widget _buildChild() {
    return AnimatedSwitcher(
      duration: widget.buttonConfig.animationDuration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: widget.behavior.isLoading
          ? CupertinoActivityIndicator(
        key: const ValueKey('loading'),
        color: widget.buttonConfig.loadingColor,radius: 15,
        // strokeWidth: 2.0,
      )
          : ButtonContentWidget(
        key: const ValueKey('content'),
        content: ButtonContent(
          label: widget.content.label,
          icon: widget.content.icon,
          body: widget.content.body,
        ),
        textStyle: widget.buttonConfig.textStyle.copyWith(
          color: !widget.behavior.isEnabled && widget.buttonConfig.isOutlined
              ? widget.buttonConfig.disabledColor
              : null,
        ),
      ),
    );
  }
}