int? imageDecodeWidth(
  double? logicalWidth,
  double devicePixelRatio, {
  double? fallbackWidth,
}) {
  final width = logicalWidth != null && logicalWidth.isFinite
      ? logicalWidth
      : fallbackWidth;
  if (width == null || !width.isFinite || width <= 0) {
    return null;
  }
  final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  return (width * ratio).ceil().clamp(1, 2048).toInt();
}
