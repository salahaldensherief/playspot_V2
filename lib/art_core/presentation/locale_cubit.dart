import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'package:playspot/core/cache/preference_manager.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(Locale(PreferenceManager().currentLang()));

  Future<void> setLocale(BuildContext context, String languageCode) async {
    if (state.languageCode == languageCode) return;

    final newLocale = Locale(languageCode);
    await PreferenceManager().saveLanguage(languageCode);
    if (context.mounted) {
      await context.setLocale(newLocale);
    }
    emit(newLocale);

    if (context.mounted) {
      context.goNamed(RouterKeys.splash);
    }
  }

  void toggleLocale(BuildContext context) {
    final newCode = state.languageCode == 'ar' ? 'en' : 'ar';
    setLocale(context, newCode);
  }
}
