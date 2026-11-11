class MessageTemplate {
  final String confirmation;
  final String shipped;
  final String delivered;

  const MessageTemplate({
    required this.confirmation,
    required this.shipped,
    required this.delivered,
  });

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      confirmation: json['confirmation']?.toString() ?? '',
      shipped: json['shipped']?.toString() ?? '',
      delivered: json['delivered']?.toString() ?? '',
    );
  }
}

class WhatsAppConfig {
  final String phoneNumber;
  final String phoneNumberId;
  final bool isEnabled;
  final String status;
  final String? error;
  final String orderMessageTemplate;
  final String? orderLink;
  final MessageTemplate templates;

  const WhatsAppConfig({
    required this.phoneNumber,
    required this.phoneNumberId,
    required this.isEnabled,
    required this.status,
    required this.error,
    required this.orderMessageTemplate,
    required this.orderLink,
    required this.templates,
  });

  factory WhatsAppConfig.fromJson(Map<String, dynamic> json) {
    final templates = json['templates'];
    return WhatsAppConfig(
      phoneNumber: json['phone_number']?.toString() ?? '',
      phoneNumberId: json['phone_number_id']?.toString() ?? '',
      isEnabled: json['is_enabled'] == true,
      status: json['status']?.toString() ?? 'pending',
      error: json['error']?.toString(),
      orderMessageTemplate: json['order_message_template']?.toString() ?? '',
      orderLink: json['order_link']?.toString(),
      templates: MessageTemplate.fromJson(
        templates is Map ? Map<String, dynamic>.from(templates) : const {},
      ),
    );
  }
}

class ParseResult {
  final bool isValid;
  final List<String> errors;
  final String? productName;
  final String? code;
  final int? availableStock;
  final int? deliveryDays;
  final String? messageError;

  const ParseResult({
    required this.isValid,
    required this.errors,
    required this.productName,
    required this.code,
    required this.availableStock,
    required this.deliveryDays,
    required this.messageError,
  });

  factory ParseResult.fromJson(Map<String, dynamic> json) {
    final errors = json['errors'];
    return ParseResult(
      isValid: json['valid'] == true,
      errors: errors is List ? errors.map((e) => e.toString()).toList() : [],
      productName: json['product_name']?.toString(),
      code: json['code']?.toString(),
      availableStock: int.tryParse(json['available_stock']?.toString() ?? ''),
      deliveryDays: int.tryParse(json['delivery_days']?.toString() ?? ''),
      messageError: json['message_error']?.toString(),
    );
  }
}

class SocialOrder {
  final String id;
  final String customerPhone;
  final String customerName;
  final String productCode;
  final int quantity;
  final String status;
  final String? productId;
  final String? variantId;
  final String? pincode;
  final String? address;
  final String? paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;
  final String? orderId;
  final String? createdAt;
  final ParseResult validation;
  final List<Map<String, dynamic>> messages;

  const SocialOrder({
    required this.id,
    required this.customerPhone,
    required this.customerName,
    required this.productCode,
    required this.quantity,
    required this.status,
    required this.productId,
    required this.variantId,
    required this.pincode,
    required this.address,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.discount,
    required this.total,
    required this.orderId,
    required this.createdAt,
    required this.validation,
    required this.messages,
  });

  factory SocialOrder.fromJson(Map<String, dynamic> json) {
    final validation = json['validation_result'];
    final rawMessages = json['messages'];
    return SocialOrder(
      id: json['id']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Customer',
      productCode: json['product_code']?.toString() ?? '—',
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'failed_validation',
      productId: json['product_id']?.toString(),
      variantId: json['variant_id']?.toString(),
      pincode: json['delivery_pincode']?.toString(),
      address: json['shipping_address']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      subtotal: _number(json['subtotal']),
      deliveryFee: _number(json['delivery_fee']),
      tax: _number(json['tax_amount']),
      discount: _number(json['discount_amount']),
      total: _number(json['total_amount']),
      orderId: json['order_id']?.toString(),
      createdAt: json['created_at']?.toString(),
      validation: ParseResult.fromJson(
        validation is Map ? Map<String, dynamic>.from(validation) : const {},
      ),
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map((message) => Map<String, dynamic>.from(message))
                .toList()
          : const [],
    );
  }

  static double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;
}
