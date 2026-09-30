import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/art_core/theme/app_colors.dart';
import 'package:playspot/art_core/widgets/layout/app_loader.dart';
import 'package:playspot/art_core/widgets/text/app_text.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import '../booking_cubit.dart';
import '../booking_state.dart';
import 'time_slot_tile.dart';

part 'time_slot_grid_state.dart';
part 'time_slot_grid_availability.dart';
part 'time_slot_grid_waitlist.dart';

class TimeSlotGrid extends StatefulWidget {
  final LoungeModel lounge;

  const TimeSlotGrid({super.key, required this.lounge});

  @override
  State<TimeSlotGrid> createState() => _TimeSlotGridState();
}
