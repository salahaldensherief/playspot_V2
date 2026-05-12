
import 'package:flutter/material.dart';

import '../../text/app_text.dart';

class ButtonContent {
  final String ?label;
  final Widget? icon;
  final Widget? body;

  const ButtonContent({ this.label, this.icon , this.body});
}

class ButtonContentWidget extends StatelessWidget {
  final ButtonContent content;
  final TextStyle? textStyle;

  const ButtonContentWidget({super.key, required this.content, this.textStyle});

  @override
  Widget build(BuildContext context) {
    if (content.body != null) return content.body!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (content.icon != null) ...[
          content.icon!,
          const SizedBox(width: 8.0),
        ],
        Flexible(
          child: AppText(
            text: content.label ?? 'Button',
            style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
