import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'ordify_workspace_widgets.dart';

class AiToolsScreen extends StatefulWidget {
  const AiToolsScreen({super.key});

  @override
  State<AiToolsScreen> createState() => _AiToolsScreenState();
}

class _AiToolsScreenState extends State<AiToolsScreen> {
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic> aiData = {};
  List<dynamic> suggestions = [];
  List<dynamic> priorityActions = [];

  @override
  void initState() {
    super.initState();
    fetchSuggestions();
  }

  Future<void> fetchSuggestions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/ai/suggestions');

      final rawData = response.data;
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        aiData = data;
        suggestions = List<dynamic>.from(data['suggestions'] ?? []);
        priorityActions = List<dynamic>.from(
          data['priority_actions'] ?? [],
        );
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        aiData = {};
        suggestions = [];
        priorityActions = [];
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  String textValue(dynamic value) {
    return value?.toString() ?? '0';
  }

  Future<void> openAiTool(AiToolType type) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0B1510),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (_) => AiGeneratorSheet(
        type: type,
        businessData: aiData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthScore = textValue(aiData['business_health_score']);

    final summary = aiData['summary']?.toString() ??
        'OrdiFy AI will analyze your orders, stock, payments, and customers.';

    return Scaffold(
      backgroundColor: ordifyBg,
      body: OrdifyBackground(
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: ordifyGreen,
                  ),
                )
              : RefreshIndicator(
                  color: ordifyGreen,
                  backgroundColor: const Color(0xFF0B1510),
                  onRefresh: fetchSuggestions,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      26,
                      20,
                      145,
                    ),
                    children: [
                      _Header(onRefresh: fetchSuggestions),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _AiWarningCard(
                          onRetry: fetchSuggestions,
                        ),
                      ],

                      const SizedBox(height: 20),

                      const _GlowText(
                        'Create with OrdiAI',
                        fontSize: 22,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Choose a tool and let AI prepare useful content for your business.',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 14),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.05,
                        children: [
                          _AiToolCard(
                            icon: Icons.inventory_2_rounded,
                            title: 'Product Description',
                            subtitle: 'Write attractive product details',
                            color: ordifyGreen,
                            onTap: () => openAiTool(
                              AiToolType.productDescription,
                            ),
                          ),
                          _AiToolCard(
                            icon: Icons.photo_camera_rounded,
                            title: 'Instagram Caption',
                            subtitle: 'Create captions and hashtags',
                            color: const Color(0xFFFF8AC5),
                            onTap: () => openAiTool(
                              AiToolType.instagramCaption,
                            ),
                          ),
                          _AiToolCard(
                            icon: Icons.chat_bubble_rounded,
                            title: 'Customer Reply',
                            subtitle: 'Prepare a friendly response',
                            color: const Color(0xFF9DF6FF),
                            onTap: () => openAiTool(
                              AiToolType.customerReply,
                            ),
                          ),
                          _AiToolCard(
                            icon: Icons.analytics_rounded,
                            title: 'Sales Analysis',
                            subtitle: 'Understand your performance',
                            color: ordifyYellow,
                            onTap: () => openAiTool(
                              AiToolType.salesAnalysis,
                            ),
                          ),
                          _AiToolCard(
                            icon: Icons.warehouse_rounded,
                            title: 'Inventory Advice',
                            subtitle: 'Get stock recommendations',
                            color: const Color(0xFFB788FF),
                            onTap: () => openAiTool(
                              AiToolType.inventoryAdvice,
                            ),
                          ),
                          _AiToolCard(
                            icon: Icons.auto_awesome_rounded,
                            title: 'Ask OrdiAI',
                            subtitle: 'Ask a business question',
                            color: const Color(0xFF47A7FF),
                            onTap: () => openAiTool(
                              AiToolType.generalChat,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      OrdifyGlassCard(
                        radius: 30,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _GlowText(
                              'Business Summary',
                              fontSize: 23,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              summary,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                height: 1.45,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ordifyGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: ordifyGreen.withOpacity(0.24),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.health_and_safety_rounded,
                                    color: ordifyGreen,
                                    size: 34,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Business Health Score',
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$healthScore%',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xFFFFC8C8),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      GestureDetector(
                        onTap: () {
                          context.push('/instagram-dms');
                        },
                        child: OrdifyGlassCard(
                          radius: 28,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                height: 54,
                                width: 54,
                                decoration: BoxDecoration(
                                  color: ordifyGreen.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(19),
                                ),
                                child: const Icon(
                                  Icons.mark_chat_unread_rounded,
                                  color: ordifyGreen,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const _GlowText(
                                      'Instagram Messages',
                                      fontSize: 16,
                                      soft: true,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'View customer messages and convert conversations into orders.',
                                      style: GoogleFonts.inter(
                                        color: Colors.white54,
                                        height: 1.4,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                height: 38,
                                width: 38,
                                decoration: BoxDecoration(
                                  color: ordifyGreen,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: ordifyGreenDark,
                                  size: 21,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      const _GlowText(
                        'Important Tasks',
                        fontSize: 22,
                      ),

                      const SizedBox(height: 12),

                      if (priorityActions.isEmpty)
                        const _EmptyCard(
                          icon: Icons.task_alt_rounded,
                          title: 'No urgent tasks',
                          subtitle:
                              'Keep adding orders and payments to receive more recommendations.',
                        )
                      else
                        ...priorityActions.map(
                          (action) => _PriorityCard(
                            text: action.toString(),
                          ),
                        ),

                      const SizedBox(height: 22),

                      const _GlowText(
                        'Smart Suggestions',
                        fontSize: 22,
                      ),

                      const SizedBox(height: 12),

                      if (suggestions.isEmpty)
                        const _EmptyCard(
                          icon: Icons.auto_awesome_rounded,
                          title: 'No suggestions yet',
                          subtitle:
                              'Add products, customers, orders, and payments to unlock suggestions.',
                        )
                      else
                        ...suggestions.map((suggestion) {
                          if (suggestion is Map) {
                            return _SuggestionCard(
                              suggestion:
                                  Map<String, dynamic>.from(suggestion),
                            );
                          }

                          return _PriorityCard(
                            text: suggestion.toString(),
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

enum AiToolType {
  productDescription,
  instagramCaption,
  customerReply,
  salesAnalysis,
  inventoryAdvice,
  generalChat,
}

extension AiToolTypeDetails on AiToolType {
  String get title {
    switch (this) {
      case AiToolType.productDescription:
        return 'Product Description';
      case AiToolType.instagramCaption:
        return 'Instagram Caption';
      case AiToolType.customerReply:
        return 'Customer Reply';
      case AiToolType.salesAnalysis:
        return 'Sales Analysis';
      case AiToolType.inventoryAdvice:
        return 'Inventory Advice';
      case AiToolType.generalChat:
        return 'Ask OrdiAI';
    }
  }

  String get apiType {
    switch (this) {
      case AiToolType.productDescription:
        return 'product_description';
      case AiToolType.instagramCaption:
        return 'instagram_caption';
      case AiToolType.customerReply:
        return 'customer_reply';
      case AiToolType.salesAnalysis:
        return 'sales_analysis';
      case AiToolType.inventoryAdvice:
        return 'inventory_advice';
      case AiToolType.generalChat:
        return 'chat';
    }
  }

  IconData get icon {
    switch (this) {
      case AiToolType.productDescription:
        return Icons.inventory_2_rounded;
      case AiToolType.instagramCaption:
        return Icons.photo_camera_rounded;
      case AiToolType.customerReply:
        return Icons.chat_bubble_rounded;
      case AiToolType.salesAnalysis:
        return Icons.analytics_rounded;
      case AiToolType.inventoryAdvice:
        return Icons.warehouse_rounded;
      case AiToolType.generalChat:
        return Icons.auto_awesome_rounded;
    }
  }
}

class AiGeneratorSheet extends StatefulWidget {
  const AiGeneratorSheet({
    super.key,
    required this.type,
    required this.businessData,
  });

  final AiToolType type;
  final Map<String, dynamic> businessData;

  @override
  State<AiGeneratorSheet> createState() => _AiGeneratorSheetState();
}

class _AiGeneratorSheetState extends State<AiGeneratorSheet> {
  bool isGenerating = false;
  String? result;
  String? errorMessage;

  final productNameController = TextEditingController();
  final categoryController = TextEditingController();
  final priceController = TextEditingController();
  final featuresController = TextEditingController();
  final audienceController = TextEditingController();
  final offerController = TextEditingController();
  final toneController = TextEditingController();

  final customerMessageController = TextEditingController();
  final productContextController = TextEditingController();

  final salesSummaryController = TextEditingController();
  final inventorySummaryController = TextEditingController();

  final questionController = TextEditingController();
  final businessContextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fillAutomaticContext();
  }

  void fillAutomaticContext() {
    if (widget.type == AiToolType.salesAnalysis) {
      salesSummaryController.text = buildSalesSummary();
    }

    if (widget.type == AiToolType.inventoryAdvice) {
      inventorySummaryController.text = buildInventorySummary();
    }

    if (widget.type == AiToolType.generalChat) {
      businessContextController.text = buildBusinessContext();
    }
  }

  String buildSalesSummary() {
    return '''
Total revenue: ₹${widget.businessData['total_revenue'] ?? 0}
Total orders: ${widget.businessData['total_orders'] ?? 0}
Paid orders: ${widget.businessData['paid_orders'] ?? 0}
Pending payments: ${widget.businessData['pending_payments'] ?? 0}
Business health score: ${widget.businessData['business_health_score'] ?? 0}%
'''.trim();
  }

  String buildInventorySummary() {
    return '''
Total products: ${widget.businessData['total_products'] ?? 'Not available'}
Low-stock products: ${widget.businessData['low_stock_products'] ?? 0}
Top product: ${widget.businessData['top_product'] ?? 'Not available'}
Business health score: ${widget.businessData['business_health_score'] ?? 0}%
'''.trim();
  }

  String buildBusinessContext() {
    return '''
Business summary: ${widget.businessData['summary'] ?? 'No summary available'}
Revenue: ₹${widget.businessData['total_revenue'] ?? 0}
Orders: ${widget.businessData['total_orders'] ?? 0}
Paid orders: ${widget.businessData['paid_orders'] ?? 0}
Pending payments: ${widget.businessData['pending_payments'] ?? 0}
Low-stock products: ${widget.businessData['low_stock_products'] ?? 0}
'''.trim();
  }

  @override
  void dispose() {
    productNameController.dispose();
    categoryController.dispose();
    priceController.dispose();
    featuresController.dispose();
    audienceController.dispose();
    offerController.dispose();
    toneController.dispose();
    customerMessageController.dispose();
    productContextController.dispose();
    salesSummaryController.dispose();
    inventorySummaryController.dispose();
    questionController.dispose();
    businessContextController.dispose();
    super.dispose();
  }

  Map<String, dynamic> buildRequestData() {
    final data = <String, dynamic>{
      'type': widget.type.apiType,
    };

    switch (widget.type) {
      case AiToolType.productDescription:
        data.addAll({
          'product_name': productNameController.text.trim(),
          'category': categoryController.text.trim(),
          'price': priceController.text.trim(),
          'features': featuresController.text.trim(),
          'audience': audienceController.text.trim(),
        });
        break;

      case AiToolType.instagramCaption:
        data.addAll({
          'product_name': productNameController.text.trim(),
          'offer': offerController.text.trim(),
          'audience': audienceController.text.trim(),
          'tone': toneController.text.trim(),
        });
        break;

      case AiToolType.customerReply:
        data.addAll({
          'customer_message': customerMessageController.text.trim(),
          'product_context': productContextController.text.trim(),
          'tone': toneController.text.trim(),
        });
        break;

      case AiToolType.salesAnalysis:
        data['summary'] = salesSummaryController.text.trim();
        break;

      case AiToolType.inventoryAdvice:
        data['inventory_summary'] =
            inventorySummaryController.text.trim();
        break;

      case AiToolType.generalChat:
        data.addAll({
          'question': questionController.text.trim(),
          'business_context': businessContextController.text.trim(),
        });
        break;
    }

    return data;
  }

  bool validate() {
    switch (widget.type) {
      case AiToolType.productDescription:
      case AiToolType.instagramCaption:
        return productNameController.text.trim().isNotEmpty;

      case AiToolType.customerReply:
        return customerMessageController.text.trim().isNotEmpty;

      case AiToolType.salesAnalysis:
        return salesSummaryController.text.trim().isNotEmpty;

      case AiToolType.inventoryAdvice:
        return inventorySummaryController.text.trim().isNotEmpty;

      case AiToolType.generalChat:
        return questionController.text.trim().isNotEmpty;
    }
  }

  String validationMessage() {
    switch (widget.type) {
      case AiToolType.productDescription:
      case AiToolType.instagramCaption:
        return 'Enter a product name';

      case AiToolType.customerReply:
        return 'Enter the customer message';

      case AiToolType.salesAnalysis:
        return 'Add a sales summary';

      case AiToolType.inventoryAdvice:
        return 'Add inventory information';

      case AiToolType.generalChat:
        return 'Enter your question';
    }
  }

  Future<void> generate() async {
    if (!validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationMessage()),
        ),
      );
      return;
    }

    setState(() {
      isGenerating = true;
      errorMessage = null;
      result = null;
    });

    try {
      final response = await apiClient.post(
        '/ai/generate',
        data: buildRequestData(),
      );

      final rawData = response.data;
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        result = data['result']?.toString() ??
            'AI did not return a response.';
        isGenerating = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
        isGenerating = false;
      });
    }
  }

  Future<void> copyResult() async {
    final value = result;

    if (value == null || value.trim().isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI result copied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: ordifyGreen.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    widget.type.icon,
                    color: ordifyGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.type.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ...buildFields(),

            if (errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  errorMessage!,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            if (result != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ordifyGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: ordifyGreen.withOpacity(0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: ordifyGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Result',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: copyResult,
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: ordifyGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      result!,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        height: 1.5,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isGenerating ? null : generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ordifyGreen,
                  foregroundColor: ordifyGreenDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: isGenerating
                    ? const SizedBox(
                        height: 19,
                        width: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ordifyGreenDark,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  isGenerating
                      ? 'Generating...'
                      : result == null
                          ? 'Generate'
                          : 'Generate Again',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildFields() {
    switch (widget.type) {
      case AiToolType.productDescription:
        return [
          _AiInput(
            controller: productNameController,
            label: 'Product name',
            hint: 'Example: Premium Cotton Shirt',
          ),
          _AiInput(
            controller: categoryController,
            label: 'Category',
            hint: 'Example: Clothing',
          ),
          _AiInput(
            controller: priceController,
            label: 'Price',
            hint: 'Example: ₹799',
            keyboardType: TextInputType.number,
          ),
          _AiInput(
            controller: featuresController,
            label: 'Main features',
            hint: 'Example: Soft cotton, regular fit, breathable',
            maxLines: 3,
          ),
          _AiInput(
            controller: audienceController,
            label: 'Target customers',
            hint: 'Example: College students',
          ),
        ];

      case AiToolType.instagramCaption:
        return [
          _AiInput(
            controller: productNameController,
            label: 'Product name',
            hint: 'Example: Oversized Black Hoodie',
          ),
          _AiInput(
            controller: offerController,
            label: 'Offer',
            hint: 'Example: 10% launch discount',
          ),
          _AiInput(
            controller: audienceController,
            label: 'Target customers',
            hint: 'Example: College students',
          ),
          _AiInput(
            controller: toneController,
            label: 'Caption style',
            hint: 'Example: Trendy and friendly',
          ),
        ];

      case AiToolType.customerReply:
        return [
          _AiInput(
            controller: customerMessageController,
            label: 'Customer message',
            hint: 'Paste the customer message here',
            maxLines: 4,
          ),
          _AiInput(
            controller: productContextController,
            label: 'Product details',
            hint: 'Add price, stock, sizes, or delivery details',
            maxLines: 4,
          ),
          _AiInput(
            controller: toneController,
            label: 'Reply style',
            hint: 'Example: Friendly and professional',
          ),
        ];

      case AiToolType.salesAnalysis:
        return [
          _AiInput(
            controller: salesSummaryController,
            label: 'Sales information',
            hint: 'Your business numbers will appear here',
            maxLines: 8,
          ),
        ];

      case AiToolType.inventoryAdvice:
        return [
          _AiInput(
            controller: inventorySummaryController,
            label: 'Inventory information',
            hint: 'Add stock and product details',
            maxLines: 8,
          ),
        ];

      case AiToolType.generalChat:
        return [
          _AiInput(
            controller: questionController,
            label: 'Your question',
            hint: 'Example: How can I increase sales this week?',
            maxLines: 3,
          ),
          _AiInput(
            controller: businessContextController,
            label: 'Business information',
            hint: 'Optional business context',
            maxLines: 7,
          ),
        ];
    }
  }
}

class _AiInput extends StatelessWidget {
  const _AiInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.inter(
            color: ordifyGreen,
            fontWeight: FontWeight.w700,
          ),
          hintStyle: GoogleFonts.inter(
            color: Colors.white30,
            fontSize: 12,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: ordifyGreen,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _AiToolCard extends StatelessWidget {
  const _AiToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 45,
                width: 45,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 10,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onRefresh,
  });

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: ordifyGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: ordifyGreenDark,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart business assistant',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'OrdiAI',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: ordifyGreen.withOpacity(0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: ordifyGreen.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ordifyGreen.withOpacity(0.30),
            ),
          ),
          child: Text(
            'Gemini',
            style: GoogleFonts.inter(
              color: ordifyGreen,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _AiWarningCard extends StatelessWidget {
  const _AiWarningCard({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: ordifyYellow,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Business suggestions could not be loaded.',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.inter(
                color: ordifyGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: OrdifyGlassCard(
        radius: 26,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: ordifyYellow.withOpacity(0.18),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: ordifyYellow,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  height: 1.35,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
  });

  final Map<String, dynamic> suggestion;

  Color get color {
    final priority = suggestion['priority']?.toString() ?? '';

    if (priority == 'high') {
      return const Color(0xFFFF5E73);
    }

    if (priority == 'medium') {
      return ordifyYellow;
    }

    return ordifyGreen;
  }

  IconData get icon {
    final type = suggestion['type']?.toString() ?? '';

    if (type == 'stock') return Icons.inventory_2_rounded;
    if (type == 'payment') return Icons.payments_rounded;
    if (type == 'growth') return Icons.trending_up_rounded;
    if (type == 'sales') return Icons.campaign_rounded;
    if (type == 'customer') return Icons.people_alt_rounded;
    if (type == 'health') {
      return Icons.health_and_safety_rounded;
    }

    return Icons.auto_awesome_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final title =
        suggestion['title']?.toString() ?? 'Suggestion';

    final message =
        suggestion['message']?.toString() ?? '';

    final action =
        suggestion['action']?.toString() ?? '';

    final priority = suggestion['priority']
            ?.toString()
            .toUpperCase() ??
        'INFO';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: OrdifyGlassCard(
        radius: 28,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _GlowText(
                    title,
                    fontSize: 17,
                    soft: true,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: color.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    priority,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.white70,
                height: 1.4,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (action.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        action,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          height: 1.35,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      radius: 28,
      child: Column(
        children: [
          Icon(
            icon,
            color: ordifyGreen,
            size: 54,
          ),
          const SizedBox(height: 16),
          _GlowText(
            title,
            fontSize: 20,
            soft: true,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowText extends StatelessWidget {
  const _GlowText(
    this.text, {
    required this.fontSize,
    this.soft = false,
  });

  final String text;
  final double fontSize;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(
            color: soft
                ? const Color(0xFFFFC8C8)
                : const Color(0xFFFFD6D6),
            blurRadius: soft ? 8 : 12,
          ),
          Shadow(
            color: ordifyGreen.withOpacity(0.25),
            blurRadius: soft ? 8 : 14,
          ),
        ],
      ),
    );
  }
}

class AiScreen extends AiToolsScreen {
  const AiScreen({super.key});
}

class AIScreen extends AiToolsScreen {
  const AIScreen({super.key});
}

class AIPage extends AiToolsScreen {
  const AIPage({super.key});
}