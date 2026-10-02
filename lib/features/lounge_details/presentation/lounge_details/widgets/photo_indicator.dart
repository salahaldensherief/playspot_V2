import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:playspot/art_core/app_strings.dart';

class PhotoIndicator extends StatelessWidget {
  final int? totalImages;
  const PhotoIndicator({super.key, this.totalImages});

  @override
  Widget build(BuildContext context) {
    final count = totalImages ?? 0;
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined, size: 20),
          Text(
            '${AppStrings.viewPhotos.tr()} · $count',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
