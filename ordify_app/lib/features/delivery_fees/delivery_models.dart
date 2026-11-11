class DeliveryZone {
  final String name;
  final List<String> pincodes;
  final double fee;
  final int estimatedDeliveryDays;

  const DeliveryZone({
    required this.name,
    required this.pincodes,
    required this.fee,
    required this.estimatedDeliveryDays,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    final fee = json['fee'];
    final days = json['estimated_delivery_days'];
    final pincodes = json['pincodes'];
    return DeliveryZone(
      name: json['name']?.toString() ?? '',
      pincodes: pincodes is List
          ? pincodes.map((value) => value.toString()).toList()
          : const [],
      fee: fee is num ? fee.toDouble() : double.tryParse('$fee') ?? 0,
      estimatedDeliveryDays: days is num
          ? days.toInt()
          : int.tryParse('$days') ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'pincodes': pincodes,
    'fee': fee,
    'estimated_delivery_days': estimatedDeliveryDays,
  };
}

class DeliveryRule {
  final String ruleType;
  final double flatFee;
  final double? freeDeliveryThreshold;
  final List<DeliveryZone> zones;

  const DeliveryRule({
    required this.ruleType,
    required this.flatFee,
    required this.freeDeliveryThreshold,
    required this.zones,
  });

  factory DeliveryRule.fromJson(Map<String, dynamic> json) {
    final fee = json['flat_fee'];
    final threshold = json['free_delivery_threshold'];
    final zones = json['zones'];
    return DeliveryRule(
      ruleType: json['rule_type']?.toString() ?? 'flat_fee',
      flatFee: fee is num ? fee.toDouble() : double.tryParse('$fee') ?? 0,
      freeDeliveryThreshold: threshold == null
          ? null
          : threshold is num
          ? threshold.toDouble()
          : double.tryParse('$threshold'),
      zones: zones is List
          ? zones
                .whereType<Map>()
                .map(
                  (zone) =>
                      DeliveryZone.fromJson(Map<String, dynamic>.from(zone)),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'rule_type': ruleType,
    'flat_fee': flatFee,
    'free_delivery_threshold': freeDeliveryThreshold,
    'zones': zones.map((zone) => zone.toJson()).toList(),
  };
}

class DeliveryQuote {
  final bool isDeliverable;
  final String pincode;
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;
  final int? estimatedDeliveryDays;
  final String? message;

  const DeliveryQuote({
    required this.isDeliverable,
    required this.pincode,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.discount,
    required this.total,
    required this.estimatedDeliveryDays,
    required this.message,
  });

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    double amount(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    }

    final days = json['estimated_delivery_days'];
    return DeliveryQuote(
      isDeliverable: json['is_deliverable'] == true,
      pincode: json['pincode']?.toString() ?? '',
      subtotal: amount('subtotal'),
      deliveryFee: amount('delivery_fee'),
      tax: amount('tax'),
      discount: amount('discount'),
      total: amount('total'),
      estimatedDeliveryDays: days is num ? days.toInt() : int.tryParse('$days'),
      message: json['message']?.toString(),
    );
  }
}
