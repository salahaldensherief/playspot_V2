import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application widgets use AppText for visible text', () {
    final violations = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('app_text.dart')) continue;
      if (RegExp(r'\bText\s*\(').hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty);
  });

  test('declared strings exist in both Arabic and English', () {
    Map<String, dynamic> translations(String language) =>
        jsonDecode(File('assets/lang/$language.json').readAsStringSync())
            as Map<String, dynamic>;
    final english = translations('en');
    final arabic = translations('ar');
    expect(english.keys.toSet(), arabic.keys.toSet());

    final constants = File('lib/art_core/app_strings.dart').readAsStringSync();
    final stringValues = RegExp(
      r'''static const(?: String)? \w+\s*=\s*['"]([^'"]+)['"]''',
    ).allMatches(constants).map((match) => match.group(1)!).toSet();
    final missing = stringValues.difference(english.keys.toSet())
      ..remove('PlaySpot');
    expect(missing, isEmpty);
  });
}
