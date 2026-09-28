import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';

/// Read-only rating display widget supporting full, half, and empty stars.
class RatingDisplayWidget extends StatelessWidget {
  final double rating;
  final int maxRating;
  final double starSize;
  final double spacing;
  final Color filledColor;
  final Color? unfilledColor;
  final bool useExactFill;

  const RatingDisplayWidget({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.starSize = 16,
    this.spacing = 2,
    this.filledColor = AppColors.warning,
    this.unfilledColor,
    this.useExactFill = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUnfilledColor =
        unfilledColor ?? AppColors.withOpacity(Colors.white, 0.15);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final diff = rating - index;
        Widget starWidget;

        if (useExactFill) {
          final fillFraction = diff.clamp(0.0, 1.0);
          starWidget = Stack(
            children: [
              Icon(
                Icons.star_rounded,
                size: starSize,
                color: effectiveUnfilledColor,
              ),
              if (fillFraction > 0)
                ClipRect(
                  child: Align(
                    alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                    widthFactor: fillFraction,
                    child: Icon(
                      Icons.star_rounded,
                      size: starSize,
                      color: filledColor,
                    ),
                  ),
                ),
            ],
          );
        } else {
          // Conditional icon rendering: full, half, empty
          if (diff >= 0.75) {
            starWidget = Icon(
              Icons.star_rounded,
              size: starSize,
              color: filledColor,
            );
          } else if (diff >= 0.25) {
            final halfIcon = Icon(
              Icons.star_half_rounded,
              size: starSize,
              color: filledColor,
            );
            starWidget = isRtl
                ? Transform.scale(
                    scaleX: -1.0,
                    child: halfIcon,
                  )
                : halfIcon;
          } else {
            starWidget = Icon(
              Icons.star_rounded,
              size: starSize,
              color: effectiveUnfilledColor,
            );
          }
        }

        if (index < maxRating - 1 && spacing > 0) {
          return Padding(
            padding: EdgeInsets.only(
              right: isRtl ? 0 : spacing,
              left: isRtl ? spacing : 0,
            ),
            child: starWidget,
          );
        }

        return starWidget;
      }),
    );
  }
}
