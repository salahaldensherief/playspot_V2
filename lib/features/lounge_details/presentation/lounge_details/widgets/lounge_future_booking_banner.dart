import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';

class LoungeFutureBookingBanner extends StatelessWidget {
  final DateTime availableFrom;
  const LoungeFutureBookingBanner({super.key, required this.availableFrom});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
    child: Text(
      AppStrings.futureBookingsAvailableFrom.tr(
        args: [
          DateFormat.yMd(context.locale.languageCode).format(availableFrom),
        ],
      ),
    ),
  );
}
