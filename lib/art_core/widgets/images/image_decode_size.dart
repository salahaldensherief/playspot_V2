int? imageDecodeWidth(double? logicalWidth, double devicePixelRatio) {
  if (logicalWidth == null || !logicalWidth.isFinite || logicalWidth <= 0) {
    return null;
  }
  final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  return (logicalWidth * ratio).ceil().clamp(1, 2048).toInt();
}
