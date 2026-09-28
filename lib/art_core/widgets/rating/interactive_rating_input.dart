import 'package:flutter/material.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'rating_display_widget.dart';

/// Interactive rating input widget allowing users to select half-star increments
/// via tapping or dragging smoothly across stars.
class InteractiveRatingInput extends StatefulWidget {
  final double initialRating;
  final ValueChanged<double> onRatingChanged;
  final int maxRating;
  final double minRating;
  final double step;
  final double starSize;
  final double spacing;
  final Color filledColor;
  final Color? unfilledColor;

  const InteractiveRatingInput({
    super.key,
    this.initialRating = 5.0,
    required this.onRatingChanged,
    this.maxRating = 5,
    this.minRating = 0.5,
    this.step = 0.5,
    this.starSize = 44,
    this.spacing = 8,
    this.filledColor = AppColors.warning,
    this.unfilledColor,
  });

  @override
  State<InteractiveRatingInput> createState() => _InteractiveRatingInputState();
}

class _InteractiveRatingInputState extends State<InteractiveRatingInput> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = _snapRating(widget.initialRating);
  }

  @override
  void didUpdateWidget(covariant InteractiveRatingInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      setState(() {
        _currentRating = _snapRating(widget.initialRating);
      });
    }
  }

  double _snapRating(double rawRating) {
    if (widget.step <= 0) return rawRating.clamp(widget.minRating, widget.maxRating.toDouble());
    final snapped = (rawRating / widget.step).round() * widget.step;
    return snapped.clamp(widget.minRating, widget.maxRating.toDouble());
  }

  void _updateRatingFromOffset(Offset localOffset, Size size, bool isRtl) {
    if (size.width <= 0) return;
    final dx = isRtl ? (size.width - localOffset.dx) : localOffset.dx;
    final ratio = (dx / size.width).clamp(0.0, 1.0);
    final rawRating = ratio * widget.maxRating;
    final newRating = _snapRating(rawRating);

    if (newRating != _currentRating) {
      setState(() {
        _currentRating = newRating;
      });
      widget.onRatingChanged(newRating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              _updateRatingFromOffset(details.localPosition, renderBox.size, isRtl);
            }
          },
          onPanUpdate: (details) {
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              _updateRatingFromOffset(details.localPosition, renderBox.size, isRtl);
            }
          },
          child: RatingDisplayWidget(
            rating: _currentRating,
            maxRating: widget.maxRating,
            starSize: widget.starSize,
            spacing: widget.spacing,
            filledColor: widget.filledColor,
            unfilledColor: widget.unfilledColor,
          ),
        );
      },
    );
  }
}
