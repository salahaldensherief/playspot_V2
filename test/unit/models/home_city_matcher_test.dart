import 'package:flutter_test/flutter_test.dart';
import 'package:playspot/features/home/presentation/home_city_matcher.dart';

void main() {
  const cities = ['Cairo', 'Alexandria', 'Giza', 'Mansoura'];

  test('matches English and Arabic city names to the backend value', () {
    expect(
      HomeCityMatcher.match('Stanley, Alexandria Governorate', cities),
      'Alexandria',
    );
    expect(
      HomeCityMatcher.match('سيدي جابر، الإسكندرية', cities),
      'Alexandria',
    );
    expect(HomeCityMatcher.match('Nasr City, Cairo', cities), 'Cairo');
  });

  test('leaves unknown locations unfiltered', () {
    expect(HomeCityMatcher.match('Port Said, Egypt', cities), isNull);
  });
}
