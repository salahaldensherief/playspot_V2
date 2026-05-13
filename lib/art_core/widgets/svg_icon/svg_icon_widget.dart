import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SvgIconWidget extends StatelessWidget {
  final String path;
  final double width;
  final double height;
  final Color? color;
  final VoidCallback? onTap;
  final bool matchTextDirection;

  const SvgIconWidget({
    super.key,
    this.matchTextDirection = true,
    required this.path,
    this.width = 24.0,
    this.height = 24.0,
    this.color,
    this.onTap,
  });

  Widget _buildNetworkSvg() {
    return SvgPicture.network(
      path,
      width: width,
      height: height,
      color: color,
      matchTextDirection: matchTextDirection,
    );
  }

  Widget _buildAssetSvg() {
    return SvgPicture.asset(
      path,
      width: width,
      height: height,
      color: color,
      matchTextDirection: matchTextDirection,
    );
  }



  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: path.startsWith("http") ? _buildNetworkSvg() : _buildAssetSvg(),
    );
  }
}
