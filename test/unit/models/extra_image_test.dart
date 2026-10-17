import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';

void main() {
  Map<String, dynamic> item() => {
    'id': 'water',
    'name': 'Water',
    'price': 18,
    'category': 'drinks',
    'icon': 'local_drink',
  };

  test('image URL survives a separate symbolic icon and cache round trip', () {
    final extra = ExtraModel.fromJson({
      ...item(),
      'image_url': ' https://example.com/water.png ',
    });
    expect(extra.icon, 'local_drink');
    expect(extra.imageUrl, 'https://example.com/water.png');
    expect(ExtraModel.fromJson(extra.toJson()), extra);
    expect(extra, isNot(ExtraModel.fromJson(item())));
  });

  test('legacy image and icon URLs remain supported', () {
    for (final field in ['image', 'icon']) {
      expect(
        ExtraModel.fromJson({
          ...item(),
          field: 'https://example.com/water.png',
        }).imageUrl,
        'https://example.com/water.png',
      );
    }
  });

  test('missing, symbolic and unsafe paths use an icon fallback', () {
    for (final value in [
      null,
      '',
      'null',
      'local_drink',
      '/tmp/a.png',
      'file:///tmp/a.png',
      'data:image/png;base64,AA',
      'https:///missing-host',
    ]) {
      expect(
        ExtraModel.fromJson({...item(), 'image_url': value}).imageUrl,
        isNull,
      );
    }
  });
}
