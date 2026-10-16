import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/core/cache/preference_manager.dart';

class LocaleCubit extends Cubit<Locale> {
  final PreferenceManager _preferences;

  LocaleCubit({PreferenceManager? preferenceManager})
    : _preferences = preferenceManager ?? PreferenceManager(),
      super(Locale((preferenceManager ?? PreferenceManager()).currentLang()));

  Future<void> setLocale(BuildContext context, String languageCode) async {
    if (state.languageCode == languageCode) return;

    final newLocale = Locale(languageCode);
    await _preferences.saveLanguage(languageCode);
    if (isClosed) return;
    if (context.mounted) {
      await context.setLocale(newLocale);
    }
    if (!isClosed) emit(newLocale);
  }

  void toggleLocale(BuildContext context) {
    final newCode = state.languageCode == 'ar' ? 'en' : 'ar';
    setLocale(context, newCode);
  }
}
