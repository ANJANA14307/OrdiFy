import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ordify_app/core/network/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ordify_workspace_widgets.dart';

class InvoiceShareScreen extends StatefulWidget {
  const InvoiceShareScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<InvoiceShareScreen> createState() => _InvoiceShareScreenState();
}

class _InvoiceShareScreenState extends State<InvoiceShareScreen> {
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  Map<String, dynamic>? sharePayload;

  @override
  void initState() {
    super.initState();
    fetchInvoiceShare();
  }

  Map<String, dynamic> safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Future<void> fetchInvoiceShare() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get(
        '/invoices/order/${widget.orderId}/latest-share',
      );

      setState(() {
        sharePayload = Map<String, dynamic>.from(response.data as Map);
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        sharePayload = null;
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  Future<void> generateInvoice() async {
    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      await apiClient.post(
        '/invoices/generate',
        data: {'order_id': widget.orderId},
      );

      await fetchInvoiceShare();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice generated')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice generation failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> openUrl(String url) async {
    final cleanedUrl = url.trim();

    if (cleanedUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice URL is empty')),
      );
      return;
    }

    final uri = Uri.tryParse(cleanedUrl);

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid invoice URL')),
      );
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        await Clipboard.setData(ClipboardData(text: cleanedUrl));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open invoice. Link copied instead.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      await Clipboard.setData(ClipboardData(text: cleanedUrl));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open invoice. Link copied. $error'),
        ),
      );
    }
  }

  Future<void> markInvoiceSent(String channel) async {
    final payload = sharePayload;
    if (payload == null) return;

    final invoice = safeMap(payload['invoice']);
    final whatsapp = safeMap(payload['whatsapp']);
    final email = safeMap(payload['email']);

    final invoiceId = invoice['id'];

    if (invoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice ID not found')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await apiClient.post(
        '/invoices/$invoiceId/mark-sent',
        data: {
          'channel': channel,
          'recipient': channel == 'whatsapp' ? whatsapp['phone'] : email['to'],
          'subject': channel == 'email' ? email['subject'] : null,
          'message': channel == 'whatsapp' ? whatsapp['message'] : email['body'],
          'status': 'sent',
        },
      );

      await fetchInvoiceShare();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice marked as sent through $channel')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> sendInvoiceEmail() async {
    final payload = sharePayload;
    if (payload == null) return;

    final invoice = safeMap(payload['invoice']);
    final email = safeMap(payload['email']);

    final invoiceId = invoice['id'];
    final emailTo = email['to'];

    if (invoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice ID not found')),
      );
      return;
    }

    if (emailTo == null || emailTo.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer email not found')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await apiClient.post(
        '/invoices/$invoiceId/send-email',
        data: {'to': emailTo},
      );

      await fetchInvoiceShare();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice email sent')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email failed. Check RESEND_API_KEY or customer email. $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = sharePayload;

    final invoice = safeMap(payload?['invoice']);
    final order = safeMap(payload?['order']);
    final customer = safeMap(payload?['customer']);
    final whatsapp = safeMap(payload?['whatsapp']);
    final email = safeMap(payload?['email']);

    final pdfUrl = invoice['pdf_url']?.toString() ?? '';
    final orderNumber = order['order_number']?.toString() ?? 'Order';

    final amount = order['total_amount']?.toString() ?? '0';

    final customerName = customer['name']?.toString() ??
        customer['display_name']?.toString() ??
        customer['instagram_username']?.toString() ??
        'Customer';

    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [
              Color(0xFF16C76A),
              Color(0xFF0A2418),
              Color(0xFF050807),
            ],
            stops: [0.0, 0.36, 1.0],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : payload == null
                  ? _InvoiceMissingView(
                      errorMessage: errorMessage,
                      isSubmitting: isSubmitting,
                      onBack: () => context.pop(),
                      onGenerate: generateInvoice,
                      onRefresh: fetchInvoiceShare,
                    )
                  : RefreshIndicator(
                      onRefresh: fetchInvoiceShare,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                        children: [
                          _InvoiceHeader(
                            onBack: () => context.pop(),
                            onRefresh: fetchInvoiceShare,
                          ),
                          const SizedBox(height: 18),
                          OrdifyGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Invoice Command Center',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xFFFFC8C8),
                                        blurRadius: 9,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Open, copy, share and track invoice delivery from one place.',
                                  style: TextStyle(
                                    color: Color(0xFFE8FFF2),
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MiniMetric(
                                        icon: Icons.receipt_long_rounded,
                                        title: 'Order',
                                        value: orderNumber,
                                        color: const Color(0xFF34F087),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MiniMetric(
                                        icon: Icons.currency_rupee_rounded,
                                        title: 'Amount',
                                        value: amount,
                                        color: const Color(0xFF9DF6FF),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          OrdifyGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      height: 58,
                                      width: 58,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF34F087)
                                            .withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: Color(0xFF34F087),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Invoice PDF',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              shadows: [
                                                Shadow(
                                                  color: Color(0xFFFFC8C8),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            customerName,
                                            style: const TextStyle(
                                              color: Color(0xFFE8FFF2),
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.14),
                                    ),
                                  ),
                                  child: Text(
                                    pdfUrl.isEmpty
                                        ? 'No PDF link found'
                                        : pdfUrl,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFE8FFF2),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF34F087),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        onPressed: pdfUrl.isEmpty
                                            ? null
                                            : () => openUrl(pdfUrl),
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text(
                                          'Open',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF34F087),
                                          side: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.22),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        onPressed: pdfUrl.isEmpty
                                            ? null
                                            : () => copyText(
                                                  pdfUrl,
                                                  'Invoice link copied',
                                                ),
                                        icon: const Icon(Icons.copy_rounded),
                                        label: const Text(
                                          'Copy',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF34F087),
                                      side: BorderSide(
                                        color: Colors.white.withOpacity(0.22),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    onPressed:
                                        isSubmitting ? null : generateInvoice,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text(
                                      'Regenerate Invoice',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ShareCard(
                            icon: Icons.chat_rounded,
                            iconColor: const Color(0xFF34F087),
                            title: 'WhatsApp Share',
                            message: whatsapp['message']?.toString() ??
                                'No WhatsApp message found',
                            primaryLabel: 'Open WA',
                            primaryIcon: Icons.open_in_new_rounded,
                            onPrimary: whatsapp['url'] == null
                                ? null
                                : () => openUrl(whatsapp['url'].toString()),
                            onCopy: whatsapp['message'] == null
                                ? null
                                : () => copyText(
                                      whatsapp['message'].toString(),
                                      'WhatsApp message copied',
                                    ),
                            onMarkSent: isSubmitting
                                ? null
                                : () => markInvoiceSent('whatsapp'),
                          ),
                          const SizedBox(height: 16),
                          _ShareCard(
                            icon: Icons.email_rounded,
                            iconColor: const Color(0xFF9DF6FF),
                            title: 'Email Share',
                            message:
                                'To: ${email['to'] ?? 'No email'}\nSubject: ${email['subject'] ?? 'Invoice'}\n\n${email['body'] ?? 'No email body found'}',
                            primaryLabel: 'Send',
                            primaryIcon: Icons.send_rounded,
                            onPrimary: isSubmitting ? null : sendInvoiceEmail,
                            onCopy: email['body'] == null
                                ? null
                                : () => copyText(
                                      email['body'].toString(),
                                      'Email body copied',
                                    ),
                            onMarkSent: isSubmitting
                                ? null
                                : () => markInvoiceSent('email'),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _InvoiceMissingView extends StatelessWidget {
  const _InvoiceMissingView({
    required this.errorMessage,
    required this.isSubmitting,
    required this.onBack,
    required this.onGenerate,
    required this.onRefresh,
  });

  final String? errorMessage;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onGenerate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        _InvoiceHeader(
          onBack: onBack,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: 18),
        OrdifyGlassCard(
          child: Column(
            children: [
              Container(
                height: 78,
                width: 78,
                decoration: BoxDecoration(
                  color: const Color(0xFF34F087).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 42,
                  color: Color(0xFF34F087),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Invoice not found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Color(0xFFFFC8C8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? 'Generate an invoice for this order.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF34F087),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: isSubmitting ? null : onGenerate,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    isSubmitting ? 'Generating...' : 'Generate Invoice',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  const _InvoiceHeader({
    required this.onBack,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share & track',
                style: TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Invoice Hub',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Color(0xFFFFC8C8),
                      blurRadius: 9,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE8FFF2),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onCopy,
    required this.onMarkSent,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback? onCopy;
  final VoidCallback? onMarkSent;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Color(0xFFFFC8C8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.14),
              ),
            ),
            child: Text(
              message,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE8FFF2),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF34F087),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: onPrimary,
                  icon: Icon(primaryIcon),
                  label: Text(
                    primaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF34F087),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.22),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text(
                    'Copy',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF34F087),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.22),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: onMarkSent,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text(
                'Mark Sent',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}