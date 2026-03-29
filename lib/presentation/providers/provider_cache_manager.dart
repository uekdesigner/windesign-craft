// lib/presentation/providers/provider_cache_manager.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🚨 YENİ: Global provider cache management
class ProviderCacheManager {
  static final ProviderCacheManager _instance =
      ProviderCacheManager._internal();
  factory ProviderCacheManager() => _instance;

  ProviderCacheManager._internal();

  final Map<String, DateTime> _providerLastUsed = {};
  final Map<String, dynamic> _providerCache = {};

  // 🚨 TEMİZLİK: Belirli aralıklarla eski cache'leri temizle
  void cleanOldCache({Duration maxAge = const Duration(minutes: 30)}) {
    final now = DateTime.now();
    _providerLastUsed.removeWhere((key, lastUsed) {
      if (now.difference(lastUsed) > maxAge) {
        print('🧹 Cleaning old cache: $key');
        _providerCache.remove(key);
        return true;
      }
      return false;
    });
  }

  // Cache'e veri ekle
  void setCache(String key, dynamic data) {
    _providerCache[key] = data;
    _providerLastUsed[key] = DateTime.now();
  }

  // Cache'ten veri al
  dynamic getCache(String key) {
    _providerLastUsed[key] = DateTime.now();
    return _providerCache[key];
  }

  // Belirli bir cache'i temizle
  void clearCache(String key) {
    _providerCache.remove(key);
    _providerLastUsed.remove(key);
  }

  // Tüm cache'i temizle
  void clearAllCache() {
    _providerCache.clear();
    _providerLastUsed.clear();
    print('🧹 All provider cache cleared');
  }
}

// 🚨 YENİ: Cache manager provider'ı
final cacheManagerProvider = Provider<ProviderCacheManager>((ref) {
  return ProviderCacheManager();
});
