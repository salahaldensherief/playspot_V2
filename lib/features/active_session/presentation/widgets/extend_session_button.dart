import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../art_core/app_strings.dart';
import '../../../../art_core/theme/app_colors.dart';
import '../../../../art_core/widgets/buttons/app_button.dart';
import '../../../../art_core/widgets/buttons/res/button_behavior.dart';
import '../../../../art_core/widgets/buttons/res/button_content.dart';
import '../../../../art_core/widgets/buttons/res/button_style_config.dart';
import '../active_session_cubit.dart';
import '../active_session_state.dart';
import 'extension_bottom_sheet.dart';
part 'extend_session_button_state.dart';

class ExtendSessionButton extends StatefulWidget {
  const ExtendSessionButton({super.key});
  @override
  State<ExtendSessionButton> createState() => _ExtendSessionButtonState();
}
