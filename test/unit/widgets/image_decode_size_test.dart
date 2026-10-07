import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/art_core/widgets/images/image_decode_size.dart';

void main() {
  test('uses physical pixels and caps oversized card images', () {
    expect(imageDecodeWidth(320, 3), 960);
    expect(imageDecodeWidth(4000, 3), 2048);
    expect(imageDecodeWidth(0.1, 1), 1);
  });

  test('unbounded images keep natural sizing', () {
    expect(imageDecodeWidth(null, 3), isNull);
    expect(imageDecodeWidth(double.infinity, 3), isNull);
    expect(imageDecodeWidth(double.nan, 3), isNull);
    expect(imageDecodeWidth(0, 3), isNull);
    expect(imageDecodeWidth(100, double.nan), 100);
  });
}
