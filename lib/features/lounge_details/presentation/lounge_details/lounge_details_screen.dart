import 'package:flutter/material.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'lounge_details_screen_state.dart';

class LoungeDetailsScreen extends StatefulWidget {
  final LoungeModel? lounge;
  final String? loungeId;
  final String? heroTag;
  const LoungeDetailsScreen({
    super.key,
    this.lounge,
    this.loungeId,
    this.heroTag,
  });
  @override
  State<LoungeDetailsScreen> createState() => LoungeDetailsScreenState();
}
