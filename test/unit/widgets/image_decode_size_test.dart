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

  test('fill-width images use their bounded parent for decode sizing', () {
    expect(imageDecodeWidth(double.infinity, 3, fallbackWidth: 320), 960);
    expect(imageDecodeWidth(null, 2, fallbackWidth: 240), 480);
    expect(imageDecodeWidth(120, 2, fallbackWidth: 320), 240);
    expect(imageDecodeWidth(0, 2, fallbackWidth: 320), isNull);
    expect(imageDecodeWidth(double.infinity, 2, fallbackWidth: double.infinity), isNull);
  });
}
