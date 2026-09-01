import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en'));

  void setLocale(BuildContext context, String languageCode) {
    final newLocale = Locale(languageCode);
    context.setLocale(newLocale);
    emit(newLocale);
  }

  void toggleLocale(BuildContext context) {
    final newCode = state.languageCode == 'ar' ? 'en' : 'ar';
    setLocale(context, newCode);
  }
}
