import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:playspot/core/cache/preference_manager.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(Locale(PreferenceManager().currentLang()));

  void setLocale(BuildContext context, String languageCode) {
    final newLocale = Locale(languageCode);
    PreferenceManager().saveLanguage(languageCode);
    context.setLocale(newLocale);
    emit(newLocale);
  }

  void toggleLocale(BuildContext context) {
    final newCode = state.languageCode == 'ar' ? 'en' : 'ar';
    setLocale(context, newCode);
  }
}
