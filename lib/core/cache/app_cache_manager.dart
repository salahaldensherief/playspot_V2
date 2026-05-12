import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Centralized cache manager for app media (images, videos, thumbnails)
///
/// Cache is automatically cleared after 7 days (stalePeriod)
///
/// Usage:
/// - For CachedNetworkImage: cacheManager: AppCacheManager.instance
/// - For CachedNetworkImageProvider: CachedNetworkImageProvider(url, cacheManager: AppCacheManager.instance)
/// - For video caching: AppCacheManager.instance.getSingleFile(videoUrl)
/// - For thumbnail caching: AppCacheManager.thumbnailCache.getSingleFile(thumbnailUrl)
class AppCacheManager {
  /// Private constructor to prevent instantiation
  AppCacheManager._();

  /// Cache key for main media cache
  static const String _cacheKey = 'appMediaCache';

  /// Cache key for video thumbnails
  static const String _thumbnailCacheKey = 'appThumbnailCache';

  /// Main cache manager instance for images and videos
  /// - stalePeriod: 7 days (files older than 7 days are considered stale)
  /// - maxNrOfCacheObjects: 200 (maximum number of cached files)
  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 200,
    ),
  );

  /// Separate cache for video thumbnails (smaller files, can keep more)
  /// - stalePeriod: 7 days
  /// - maxNrOfCacheObjects: 500 (thumbnails are small, can store more)
  static final CacheManager thumbnailCache = CacheManager(
    Config(
      _thumbnailCacheKey,
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 500,
    ),
  );

  /// Clear all caches (useful for logout or memory pressure)
  static Future<void> clearAllCaches() async {
    await instance.emptyCache();
    await thumbnailCache.emptyCache();
  }

  /// Remove a specific file from the main cache
  static Future<void> removeFile(String url) async {
    await instance.removeFile(url);
  }

  /// Remove a specific thumbnail from the thumbnail cache
  static Future<void> removeThumbnail(String url) async {
    await thumbnailCache.removeFile(url);
  }
}
