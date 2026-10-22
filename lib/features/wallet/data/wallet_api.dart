import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/dio_provider.dart';

class CoinPackageDto {
  const CoinPackageDto({
    required this.code,
    required this.name,
    required this.coins,
    required this.priceAmount,
    required this.priceCurrency,
  });

  final String code;
  final String name;
  final int coins;
  final int priceAmount;
  final String priceCurrency;

  factory CoinPackageDto.fromJson(Map<String, dynamic> json) {
    return CoinPackageDto(
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      priceCurrency: (json['price_currency'] as String?) ?? 'USD',
    );
  }
}

class MembershipPackageDto {
  const MembershipPackageDto({
    required this.code,
    required this.name,
    required this.durationDays,
    required this.description,
    required this.priceAmount,
    required this.priceCurrency,
    required this.promoActive,
    required this.currentPriceAmount,
    required this.originalPriceAmount,
    required this.discountPercent,
    required this.promoSecondsRemaining,
    required this.promoEndsAt,
  });

  final String code;
  final String name;
  final int durationDays;
  final String description;
  final int priceAmount;
  final String priceCurrency;
  final bool promoActive;
  final int currentPriceAmount;
  final int originalPriceAmount;
  final int discountPercent;
  final int promoSecondsRemaining;
  final DateTime? promoEndsAt;

  factory MembershipPackageDto.fromJson(Map<String, dynamic> json) {
    final promoEndsAt = DateTime.tryParse((json['promo_ends_at'] as String?) ?? '');
    return MembershipPackageDto(
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      description: (json['description'] as String?) ?? '',
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      priceCurrency: (json['price_currency'] as String?) ?? 'USD',
      promoActive: json['promo_active'] == true,
      currentPriceAmount: (json['current_price_amount'] as num?)?.toInt() ?? ((json['price_amount'] as num?)?.toInt() ?? 0),
      originalPriceAmount: (json['original_price_amount'] as num?)?.toInt() ?? ((json['price_amount'] as num?)?.toInt() ?? 0),
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      promoSecondsRemaining: (json['promo_seconds_remaining'] as num?)?.toInt() ?? 0,
      promoEndsAt: promoEndsAt,
    );
  }
}

class WalletPagination {
  const WalletPagination({
    required this.currentPage,
    required this.perPage,
    required this.lastPage,
    required this.total,
  });

  final int currentPage;
  final int perPage;
  final int lastPage;
  final int total;

  factory WalletPagination.fromJson(Map<String, dynamic> json) {
    return WalletPagination(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 20,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class WalletPage<T> {
  const WalletPage({required this.items, required this.pagination});

  final List<T> items;
  final WalletPagination pagination;
}

class PaymentOrderDto {
  const PaymentOrderDto({
    required this.paymentOrderId,
    required this.provider,
    required this.status,
    required this.itemType,
    required this.coins,
    required this.amount,
    required this.currency,
    required this.packageCode,
    required this.packageName,
    required this.paidAt,
    required this.createdAt,
  });

  final String paymentOrderId;
  final String provider;
  final String status;
  final String itemType;
  final int coins;
  final int amount;
  final String currency;
  final String packageCode;
  final String packageName;
  final DateTime? paidAt;
  final DateTime? createdAt;

  factory PaymentOrderDto.fromJson(Map<String, dynamic> json) {
    return PaymentOrderDto(
      paymentOrderId: (json['payment_order_id'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      itemType: (json['item_type'] as String?) ?? 'coins',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?) ?? '',
      packageCode: (json['package_code'] as String?) ?? '',
      packageName: (json['package_name'] as String?) ?? '',
      paidAt: DateTime.tryParse((json['paid_at'] as String?) ?? ''),
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

class CoinTransactionDto {
  const CoinTransactionDto({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.reason,
    required this.referenceType,
    required this.referenceId,
    required this.createdAt,
  });

  final int id;
  final String type;
  final int amount;
  final int balanceBefore;
  final int balanceAfter;
  final String reason;
  final String referenceType;
  final String referenceId;
  final DateTime? createdAt;

  factory CoinTransactionDto.fromJson(Map<String, dynamic> json) {
    return CoinTransactionDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: (json['type'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balanceBefore: (json['balance_before'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      reason: (json['reason'] as String?) ?? '',
      referenceType: (json['reference_type'] as String?) ?? '',
      referenceId: (json['reference_id'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

// DTO untuk Riwayat Konversi Koin
class CoinConversionDto {
  const CoinConversionDto({
    required this.id,
    required this.coinsConverted,
    required this.cashReceived,
    required this.createdAt,
  });

  final int id;
  final int coinsConverted;
  final num cashReceived;
  final DateTime? createdAt;

  factory CoinConversionDto.fromJson(Map<String, dynamic> json) {
    return CoinConversionDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      coinsConverted: (json['coins_converted'] as num?)?.toInt() ?? 0,
      cashReceived: (json['cash_received'] as num?)?.toDbl() ?? 0,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

// DTO untuk Riwayat Penarikan Saldo (Withdraw)
class WithdrawRequestDto {
  const WithdrawRequestDto({
    required this.id,
    required this.amountIdr,
    required this.walletType,
    required this.walletNumber,
    required this.accountName,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final num amountIdr;
  final String walletType;
  final String walletNumber;
  final String accountName;
  final String status;
  final DateTime? createdAt;

  factory WithdrawRequestDto.fromJson(Map<String, dynamic> json) {
    return WithdrawRequestDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      amountIdr: (json['amount_idr'] as num?)?.toDouble() ?? 0,
      walletType: (json['wallet_type'] as String?) ?? '',
      walletNumber: (json['wallet_number'] as String?) ?? '',
      accountName: (json['account_name'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

class CheckoutDto {
  const CheckoutDto({
    required this.paymentOrderId,
    required this.provider,
    required this.redirectUrl,
  });

  final String paymentOrderId;
  final String provider;
  final String? redirectUrl;

  factory CheckoutDto.fromJson(Map<String, dynamic> json) {
    return CheckoutDto(
      paymentOrderId: (json['payment_order_id'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
      redirectUrl: (json['redirect_url'] as String?)?.trim().isEmpty == true ? null : (json['redirect_url'] as String?),
    );
  }
}

class OrderStatusDto {
  const OrderStatusDto({
    required this.paymentOrderId,
    required this.provider,
    required this.status,
    required this.coins,
    required this.paidAt,
  });

  final String paymentOrderId;
  final String provider;
  final String status;
  final int coins;
  final DateTime? paidAt;

  factory OrderStatusDto.fromJson(Map<String, dynamic> json) {
    return OrderStatusDto(
      paymentOrderId: (json['payment_order_id'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      paidAt: DateTime.tryParse((json['paid_at'] as String?) ?? ''),
    );
  }
}

class WalletApi {
  WalletApi(this._dio);

  final Dio _dio;

  Future<List<CoinPackageDto>> packages() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/coin-packages');
    final map = res.data ?? <String, dynamic>{};
    final raw = map['data'];
    final items = raw is List ? raw.whereType<Map>().map((e) => CoinPackageDto.fromJson(e.cast<String, dynamic>())).toList() : <CoinPackageDto>[];
    return items;
  }

  Future<List<MembershipPackageDto>> membershipPackages() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/membership-packages');
    final map = res.data ?? <String, dynamic>{};
    final raw = map['data'];
    final items = raw is List ? raw.whereType<Map>().map((e) => MembershipPackageDto.fromJson(e.cast<String, dynamic>())).toList() : <MembershipPackageDto>[];
    return items;
  }

  Future<Map<String, bool>> enabledProviders() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/payments/providers');
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final enabled = (data['enabled'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return enabled.map((k, v) => MapEntry(k, v == true));
  }

  Future<WalletPage<PaymentOrderDto>> paymentOrders({int page = 1, int perPage = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/wallet/payment-orders',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final raw = data['items'];
    final items = raw is List ? raw.whereType<Map>().map((e) => PaymentOrderDto.fromJson(e.cast<String, dynamic>())).toList() : <PaymentOrderDto>[];
    final pagination = WalletPagination.fromJson((data['pagination'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{});
    return WalletPage(items: items, pagination: pagination);
  }

  Future<WalletPage<CoinTransactionDto>> coinTransactions({int page = 1, int perPage = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/wallet/coin-transactions',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final raw = data['items'];
    final items = raw is List ? raw.whereType<Map>().map((e) => CoinTransactionDto.fromJson(e.cast<String, dynamic>())).toList() : <CoinTransactionDto>[];
    final pagination = WalletPagination.fromJson((data['pagination'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{});
    return WalletPage(items: items, pagination: pagination);
  }

  // Ambil Riwayat Konversi Koin
  Future<WalletPage<CoinConversionDto>> coinConversions({int page = 1, int perPage = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/wallet/conversions',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final raw = data['items'];
    final items = raw is List ? raw.whereType<Map>().map((e) => CoinConversionDto.fromJson(e.cast<String, dynamic>())).toList() : <CoinConversionDto>[];
    final pagination = WalletPagination.fromJson((data['pagination'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{});
    return WalletPage(items: items, pagination: pagination);
  }

  // Ambil Riwayat Penarikan Saldo (Withdraw)
  Future<WalletPage<WithdrawRequestDto>> withdrawRequestsHistory({int page = 1, int perPage = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/wallet/withdrawals',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final raw = data['items'];
    final items = raw is List ? raw.whereType<Map>().map((e) => WithdrawRequestDto.fromJson(e.cast<String, dynamic>())).toList() : <WithdrawRequestDto>[];
    final pagination = WalletPagination.fromJson((data['pagination'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{});
    return WalletPage(items: items, pagination: pagination);
  }

  Future<CheckoutDto> checkout({required String packageCode, required String provider, String itemType = 'coins'}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/payments/checkout',
      data: {'item_type': itemType, 'package_code': packageCode, 'provider': provider},
    );
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CheckoutDto.fromJson(data);
  }

  Future<OrderStatusDto> orderStatus({required String paymentOrderId}) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/payments/orders/$paymentOrderId');
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return OrderStatusDto.fromJson(data);
  }

  Future<int> verifyGooglePlay({required String packageCode, required String productId, required String purchaseToken, String itemType = 'coins'}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/payments/google-play/verify',
      data: {'item_type': itemType, 'package_code': packageCode, 'product_id': productId, 'purchase_token': purchaseToken},
    );
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return (data['coins_balance'] as num?)?.toInt() ?? 0;
  }

  Future<int> verifyAppleReceipt({required String packageCode, required String productId, required String receiptData, String? transactionId, String itemType = 'coins'}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/payments/app-store/verify',
      data: {
        'item_type': itemType,
        'package_code': packageCode,
        'product_id': productId,
        'receipt_data': receiptData,
        if (transactionId != null && transactionId.trim().isNotEmpty) 'transaction_id': transactionId,
      },
    );
    final map = res.data ?? <String, dynamic>{};
    final data = (map['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return (data['coins_balance'] as num?)?.toInt() ?? 0;
  }

  // Endpoint untuk Menukar Koin ke Saldo Rupiah
  Future<void> convertCoins({required int coinsToConvert}) async {
    await _dio.post(
      '/v1/wallet/convert',
      data: {'coins_to_convert': coinsToConvert},
    );
  }

  // Endpoint untuk Tarik Saldo (Withdraw ke DANA/GoPay)
  Future<void> requestWithdraw({
    required String walletType,
    required String walletNumber,
    required String accountName,
    required double amountIdr,
  }) async {
    await _dio.post(
      '/v1/wallet/withdraw',
      data: {
        'wallet_type': walletType,
        'wallet_number': walletNumber,
        'account_name': accountName,
        'amount_idr': amountIdr,
      },
    );
  }
}

final walletApiProvider = Provider<WalletApi>((ref) {
  return WalletApi(ref.watch(dioProvider));
});
