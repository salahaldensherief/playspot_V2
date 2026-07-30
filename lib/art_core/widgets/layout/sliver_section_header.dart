import 'package:flutter/material.dart';
import 'section_header.dart';

class SliverSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAllTap;
  final String? seeAllText;

  const SliverSectionHeader({
    super.key,
    required this.title,
    this.onSeeAllTap,
    this.seeAllText,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SectionHeader(
        title: title,
        onSeeAllTap: onSeeAllTap,
        seeAllText: seeAllText,
      ),
    );
  }
}
