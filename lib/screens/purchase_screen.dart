import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import '../services/license_service.dart';
import '../providers/license_provider.dart';

/// Play Console'da tanımlı ürün ve temel plan kimlikleri.
const String _kProductId = 'pro_lisans';
const String _kMonthlyBasePlanId = 'aylik';
const String _kYearlyBasePlanId = 'yillik';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isLoadingProducts = true;
  bool _isProcessing = false;
  String? _error;
  ProductDetails? _productDetails;

  // basePlanId -> teklif detayı
  final Map<String, SubscriptionOfferDetailsWrapper> _offers = {};

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (Object error) {
        setState(() => _error = 'Satın alma akışında hata: $error');
      },
    );
    _loadProducts();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _error = null;
    });

    final available = await _iap.isAvailable();
    if (!available) {
      setState(() {
        _isLoadingProducts = false;
        _error = 'Google Play Store\'a şu anda ulaşılamıyor.';
      });
      return;
    }

    final response = await _iap.queryProductDetails({_kProductId});

    if (response.error != null) {
      setState(() {
        _isLoadingProducts = false;
        _error = 'Ürünler yüklenemedi: ${response.error!.message}';
      });
      return;
    }

    if (response.productDetails.isEmpty) {
      setState(() {
        _isLoadingProducts = false;
        _error = 'Abonelik ürünü bulunamadı.';
      });
      return;
    }

    final details = response.productDetails.first;
    _productDetails = details;

    if (details is GooglePlayProductDetails) {
      final offerDetails =
          details.productDetails.subscriptionOfferDetails ?? [];
      for (final offer in offerDetails) {
        _offers[offer.basePlanId] = offer;
      }
    }

    setState(() => _isLoadingProducts = false);
  }

  Future<void> _buy(String basePlanId) async {
    final details = _productDetails;
    final offer = _offers[basePlanId];
    if (details == null || offer == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final purchaseParam = GooglePlayPurchaseParam(
      productDetails: details,
      offerToken: offer.offerToken,
    );

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Satın alma başlatılamadı: $e';
      });
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _kProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;

        case PurchaseStatus.error:
          setState(() {
            _isProcessing = false;
            _error =
                'Satın alma başarısız: ${purchase.error?.message ?? 'bilinmeyen hata'}';
          });
          break;

        case PurchaseStatus.canceled:
          setState(() => _isProcessing = false);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndActivate(purchase);
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    final purchaseToken = purchase.verificationData.serverVerificationData;

    try {
      final result = await LicenseService().verifyPurchase(
        productId: purchase.productID,
        purchaseToken: purchaseToken,
      );

      if (!mounted) return;

      ref.invalidate(licenseProvider);

      final active = result['active'] == true;
      setState(() => _isProcessing = false);

      if (active) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aboneliğiniz aktifleştirildi! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Abonelik doğrulandı ama aktif görünmüyor.');
      }
    } on LicenseDeniedException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'Doğrulama başarısız: ${e.reason}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'Doğrulama sırasında bir hata oluştu.';
      });
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    await _iap.restorePurchases();
  }

  String _priceFor(String basePlanId) {
    final offer = _offers[basePlanId];
    final phases = offer?.pricingPhases.pricingPhaseList ?? [];
    if (phases.isEmpty) return '-';
    return phases.first.formattedPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonelik Satın Al')),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 64,
                    color: Colors.indigo.shade600,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'WinDesign Craft Pro Lisans',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_offers.containsKey(_kMonthlyBasePlanId))
                    _buildPlanCard(
                      title: 'Aylık Abonelik',
                      price: _priceFor(_kMonthlyBasePlanId),
                      period: '/ ay',
                      onTap: () => _buy(_kMonthlyBasePlanId),
                    ),
                  const SizedBox(height: 12),
                  if (_offers.containsKey(_kYearlyBasePlanId))
                    _buildPlanCard(
                      title: 'Yıllık Abonelik',
                      price: _priceFor(_kYearlyBasePlanId),
                      period: '/ yıl',
                      highlight: true,
                      onTap: () => _buy(_kYearlyBasePlanId),
                    ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _isProcessing ? null : _restorePurchases,
                    child: const Text('Satın Almaları Geri Yükle'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? Colors.indigo.shade400 : Colors.grey.shade300,
          width: highlight ? 2 : 1,
        ),
        color: highlight ? Colors.indigo.shade50 : Colors.white,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$price $period'),
        trailing: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: highlight
                      ? Colors.indigo.shade600
                      : Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Satın Al'),
              ),
      ),
    );
  }
}
