import 'package:flutter/material.dart';

import '../../text/app_text.dart';

class ButtonContent {
  final String? label;
  final Widget? icon;
  final Widget? body;
  final int? maxLines;

  const ButtonContent({
    this.label,
    this.icon,
    this.body,
    this.maxLines = 1,
  });
}

class ButtonContentWidget extends StatelessWidget {
  final ButtonContent content;
  final TextStyle? textStyle;

  const ButtonContentWidget({super.key, required this.content, this.textStyle});

  @override
  Widget build(BuildContext context) {
    if (content.body != null) return content.body!;
    final maxLines = content.maxLines ?? 1;
    final textWidget = AppText(
      text: content.label ?? 'Button',
      textAlign: TextAlign.center,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (content.icon != null) ...[
          content.icon!,
          const SizedBox(width: 6.0),
        ],
        Flexible(
          child: maxLines == 1
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: textWidget,
                )
              : textWidget,
        ),
      ],
    );
  }
}
