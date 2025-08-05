import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

const _mapCacheKey = 'mapCacheKey';

class MyCacheManager {
  static final custom = CacheManager(
    Config(
      _mapCacheKey,
      stalePeriod: const Duration(days: 7), // expired in 7 days
      maxNrOfCacheObjects: 500, // batas jumlah file cache 500 ubin
    ),
  );
}

class CustomCachedTileProvider extends TileProvider {
  CustomCachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coords, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coords, options),
      cacheManager: MyCacheManager.custom,
    );
  }
}