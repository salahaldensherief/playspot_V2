
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/cache/app_cache_manager.dart';
import '../../theme/app_colors.dart';

class AppImage extends StatelessWidget {
  /// The URL or path of the image (e.g., HTTP URL, asset path, or file path).
  final String urlImg;

  /// Optional height of the image.
  final double? height;

  /// Optional width of the image.
  final double? width;

  /// Widget to display if the image fails to load.
  final Widget? errorWidget;

  /// Widget to display while the image is loading.
  final Widget? placeholderWidget;

  /// How the image should be inscribed into the available space.
  final BoxFit fit;

  /// Border radius for the image container.
  final double borderRadius;

  /// Optional border color for the error or placeholder container.
  final Color? borderColor;

  /// Optional color filter to apply to the image.
  final Color? color;

  /// Optional background color for the image container.
  final Color? backgroundColor;

  /// Optional shape of the image container (e.g., circle or rectangle).
  final BoxShape? boxShape;

  /// Enable zoom functionality when tapping the image.
  final bool enableZoom, useFirstNameIfError, useLogo60IXIfError;

  /// Minimum scale for zooming.
  final double minScale;

  /// Maximum scale for zooming.
  final double maxScale;

  /// Initial scale when zoomed.
  final double initialScale;

  final String? errorImagePath, nameIfError;

  const AppImage({
    super.key,
    this.urlImg = '',
    this.height,
    this.width,
    this.errorWidget,
    this.placeholderWidget,
    this.fit = BoxFit.contain,
    this.borderRadius = 8.0,
    this.borderColor,
    this.color,
    this.boxShape,
    this.errorImagePath,
    this.nameIfError,
    this.enableZoom = false,
    this.useFirstNameIfError = false,
    this.useLogo60IXIfError = false,
    this.minScale = 0.8,
    this.maxScale = 3.0,
    this.initialScale = 1.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        color: backgroundColor,
        width: width,
        height: height,
        child: enableZoom
            ? GestureDetector(
          onTap: () => _showZoomDialog(context),
          child: _buildImageBasedOnSource(),
        )
            : _buildImageBasedOnSource(),
      ),
    );
  }

  /// Shows a dialog with zoomable image only
  void _showZoomDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PhotoView.customChild(
              minScale: PhotoViewComputedScale.contained * minScale,
              maxScale: PhotoViewComputedScale.covered * maxScale,
              initialScale: PhotoViewComputedScale.contained * initialScale,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              child: PhotoViewGestureDetectorScope(
                axis: Axis.vertical,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {},
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! > 200) {
                      Navigator.pop(context);
                    }
                  },
                  child: Hero(tag: 'image', child: _getImageWidget()),
                ),
              ),
            ),
            Positioned(
              top: 60,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.8,
              end: 1.0,
            ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _getImageWidget() {
    if (urlImg.startsWith('http')) {
      return _buildNetworkImage();
    } else if (urlImg.startsWith('assets')) {
      return Image.asset(urlImg, fit: BoxFit.contain);
    } else {
      return Image.file(File(urlImg), fit: BoxFit.contain);
    }
  }

  /// Determines the appropriate ImageProvider based on the source

  /// Determines the image source and delegates to the appropriate builder.
  Widget _buildImageBasedOnSource() {
    if (urlImg.trim().isEmpty) {
      return _buildError();
    }
    if (urlImg.startsWith('http')) {
      return _buildNetworkImage();
    }
    return _buildLocalImage();
  }

  /// Builds the network image using CachedNetworkImage with 7-day disk cache.
  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: urlImg,
      cacheManager: AppCacheManager.instance,

      width: width,
      height: height,
      fit: fit,
      color: color,
      placeholder: (_, _) => placeholderWidget ?? _buildPlaceholder(),
      errorWidget: (_, _, _) => errorWidget ?? _buildError(),
      fadeInDuration: const Duration(milliseconds: 300),
      // Faster, smoother fade
      fadeOutDuration: const Duration(milliseconds: 200),
      // Enhanced caching configuration - only if valid dimensions
      // memCacheWidth: (width != null && width!.isFinite) ? width!.toInt() : null,
      // memCacheHeight: (height != null && height!.isFinite)
      //     ? height!.toInt()
      //     : null,

    );
  }

  /// Builds the local image (asset or file) based on the path.
  Widget _buildLocalImage({String? path}) {
    final isAsset =
        urlImg.startsWith('assets') || (path?.startsWith('assets') ?? false);
    final imageWidget = isAsset
        ? Image.asset(
      path ?? urlImg,
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (_, _, _) => errorWidget ?? _buildError(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
    )
        : Image.file(
      File(urlImg),
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (_, _, _) => errorWidget ?? _buildError(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
    return imageWidget;
  }

  /// Builds a shimmer placeholder while the image loads.
  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: boxShape == BoxShape.circle
              ? null
              : BorderRadius.circular(borderRadius),
          shape: boxShape ?? BoxShape.rectangle,
        ),
      ),
    );
  }

  /// Builds an error widgets if the image fails to load or the URL is invalid.
  Widget _buildError() {
    if (errorWidget != null) {
      return errorWidget!;
    }
    if (useLogo60IXIfError) {
      return Icon(
        TablerIcons.device_gamepad,
        weight: width,
        color: color,

      );
    }
    if (useFirstNameIfError) {
      return _buildImageForFirstName();
    }
    if (errorImagePath != null && errorImagePath!.isNotEmpty) {
      return Image.asset(
        errorImagePath!,
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: (_, _, _) => _buildDefaultErrorContainer(),
      );
    }
    return _buildDefaultErrorContainer();
  }

  Widget _buildDefaultErrorContainer() {
    return Container(
      height: height,
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: borderColor?.withAlpha(64) ?? Colors.grey.withOpacity(0.25),
        borderRadius: boxShape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
        shape: boxShape ?? BoxShape.rectangle,
      ),
      child: FittedBox(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
          size: (height ?? 150) * 0.3,
        ),
      ),
    );
  }

  Widget _buildImageForFirstName() {
    final isCircle = boxShape == BoxShape.circle;
    return Container(
      height: height,
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: borderColor?.withAlpha(64) ?? Colors.grey.withOpacity(0.25),
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        shape: boxShape ?? BoxShape.rectangle,
      ),
      child: FittedBox(
        child: Text(
           nameIfError ==null || nameIfError!.isEmpty  ? "G":nameIfError?.substring(0, 1).toUpperCase() ?? "G",
       style: TextStyle(
    color: AppColors.primary,
         fontWeight: FontWeight.w600,
         fontSize: 20.sp,
       )
        ),
      ),
    );
  }
}
