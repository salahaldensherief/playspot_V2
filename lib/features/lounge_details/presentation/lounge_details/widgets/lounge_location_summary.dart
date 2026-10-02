import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/widgets/buttons/directions_button.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';

class LoungeLocationSummary extends StatelessWidget {
  final LoungeModel lounge;
  const LoungeLocationSummary({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    final address = (lounge.address ?? '').trim();
    final city = (lounge.city ?? '').trim();
    final distance = lounge.getFormattedDistance(
      isArabic: context.locale.languageCode == 'ar',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (address.isNotEmpty || city.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(address.isNotEmpty ? address : city)),
            ],
          ),
        if (distance.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              (lounge.distanceIsApproximate
                      ? 'lounge_distance_estimate'
                      : 'lounge_distance_summary')
                  .tr(namedArgs: {'distance': distance}),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        if (lounge.lat != null && lounge.lng != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DirectionsButton(
              lat: lounge.lat,
              lng: lounge.lng,
              isFullWidth: true,
            ),
          ),
      ],
    );
  }
}
