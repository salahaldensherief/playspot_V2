
import '../../../core/constants/app_config.dart';

class FontsManager {
  static String get fontFamily => AppConfig.isArabic ? _arabicFontFamily : _englishFontFamily;

  // Fonts
  static const String _arabicFontFamily = _familyMontserrat;
  static const String _englishFontFamily = "Orbitron";
  static const String _familyMontserrat = 'SourceSans3';


}
