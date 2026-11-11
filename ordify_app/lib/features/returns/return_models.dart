class ReturnPolicy {
  const ReturnPolicy({
    required this.returnWindowDays,
    required this.eligibleConditions,
    required this.nonReturnableProductIds,
    required this.allowRefund,
    required this.allowExchange,
    required this.policyText,
  });

  final int returnWindowDays;
  final List<String> eligibleConditions;
  final List<String> nonReturnableProductIds;
  final bool allowRefund;
  final bool allowExchange;
  final String policyText;

  factory ReturnPolicy.fromJson(Map<String, dynamic> json) => ReturnPolicy(
    returnWindowDays: _number(json['return_window_days']).toInt(),
    eligibleConditions: (json['eligible_conditions'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    nonReturnableProductIds:
        (json['non_returnable_product_ids'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
    allowRefund: json['allow_refund'] != false,
    allowExchange: json['allow_exchange'] == true,
    policyText: json['policy_text']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'return_window_days': returnWindowDays,
    'eligible_conditions': eligibleConditions,
    'non_returnable_product_ids': nonReturnableProductIds,
    'allow_refund': allowRefund,
    'allow_exchange': allowExchange,
    'policy_text': policyText,
  };
}

class InspectionResult {
  const InspectionResult({
    required this.status,
    required this.items,
    this.notes,
    this.photos = const [],
  });

  final String status;
  final List<ReturnItem> items;
  final String? notes;
  final List<String> photos;
}

class ReturnItem {
  const ReturnItem({
    required this.orderItemId,
    required this.productId,
    required this.productName,
    required this.variantCode,
    required this.unitPrice,
    required this.quantity,
    this.eligible = true,
    this.ineligibleReason,
    this.acceptedQuantity,
  });

  final String orderItemId;
  final String productId;
  final String productName;
  final String variantCode;
  final double unitPrice;
  final int quantity;
  final bool eligible;
  final String? ineligibleReason;
  final int? acceptedQuantity;

  factory ReturnItem.fromJson(Map<String, dynamic> json) => ReturnItem(
    orderItemId: json['order_item_id']?.toString() ?? '',
    productId: json['product_id']?.toString() ?? '',
    productName: json['product_name']?.toString() ?? 'Product',
    variantCode: json['variant_code']?.toString() ?? '',
    unitPrice: _number(json['unit_price']),
    quantity: _number(json['quantity']).toInt(),
    eligible: json['eligible'] == true,
    ineligibleReason: json['ineligible_reason']?.toString(),
    acceptedQuantity: json['accepted_quantity'] == null
        ? null
        : _number(json['accepted_quantity']).toInt(),
  );
}

class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.status,
    required this.reason,
    required this.preferredOutcome,
    required this.items,
    this.comment,
    this.photos = const [],
    this.inspectionResult,
    this.inspectionNotes,
    this.inspectionPhotos = const [],
    this.refundAmount,
    this.rejectionReason,
    this.exchangeOrderId,
    this.messages = const [],
  });

  final String id;
  final String orderId;
  final String status;
  final String reason;
  final String preferredOutcome;
  final List<ReturnItem> items;
  final String? comment;
  final List<String> photos;
  final String? inspectionResult;
  final String? inspectionNotes;
  final List<String> inspectionPhotos;
  final double? refundAmount;
  final String? rejectionReason;
  final String? exchangeOrderId;
  final List<Map<String, dynamic>> messages;

  factory ReturnRequest.fromJson(Map<String, dynamic> json) => ReturnRequest(
    id: json['id']?.toString() ?? '',
    orderId: json['order_id']?.toString() ?? '',
    status: json['status']?.toString() ?? 'return_requested',
    reason: json['reason']?.toString() ?? '',
    preferredOutcome: json['preferred_outcome']?.toString() ?? 'refund',
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ReturnItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    comment: json['comment']?.toString(),
    photos: (json['photos'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    inspectionResult: json['inspection_result']?.toString(),
    inspectionNotes: json['inspection_notes']?.toString(),
    inspectionPhotos: (json['inspection_photos'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    refundAmount: json['refund_amount'] == null
        ? null
        : _number(json['refund_amount']),
    rejectionReason: json['rejection_reason']?.toString(),
    exchangeOrderId: json['exchange_order_id']?.toString(),
    messages: (json['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((message) => Map<String, dynamic>.from(message))
        .toList(),
  );
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
