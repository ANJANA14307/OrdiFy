import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'whatsapp_order_models.dart';
import 'whatsapp_orders_api.dart';

class WhatsAppSetupScreen extends StatefulWidget {
  const WhatsAppSetupScreen({super.key});

  @override
  State<WhatsAppSetupScreen> createState() => _WhatsAppSetupScreenState();
}

class _WhatsAppSetupScreenState extends State<WhatsAppSetupScreen> {
  final _phoneController = TextEditingController();
  final _phoneIdController = TextEditingController();
  WhatsAppConfig? _config;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final config = await whatsappOrdersApi.getConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _phoneController.text = config.phoneNumber;
        _phoneIdController.text = config.phoneNumberId;
        _enabled = config.isEnabled;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final config = await whatsappOrdersApi.saveConfig(
        phoneNumber: _phoneController.text.trim(),
        phoneNumberId: _phoneIdController.text.trim(),
        isEnabled: _enabled,
      );
      if (!mounted) return;
      setState(() {
        _config = config;
        _isSaving = false;
      });
      _notify('WhatsApp settings saved');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isSaving = false;
      });
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _notify('$label copied');
  }

  Future<void> _openLink() async {
    final link = _config?.orderLink;
    if (link == null || link.isEmpty) return;
    final opened = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) _notify('Could not open WhatsApp');
  }

  void _notify(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Color _statusColor(String status) {
    if (status == 'connected') return const Color(0xFF34F087);
    if (status == 'error') return const Color(0xFFFF687A);
    return const Color(0xFFFFC857);
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final status = config?.status ?? 'pending';
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        title: const Text('WhatsApp Ordering'),
        backgroundColor: const Color(0xFF07120C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && config == null
          ? _LoadError(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_rounded,
                            color: Color(0xFF34F087),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Connection status',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          _StatusBadge(
                            label: status.toUpperCase(),
                            color: _statusColor(status),
                          ),
                        ],
                      ),
                      if (config?.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          config!.error!,
                          style: const TextStyle(
                            color: Color(0xFFFF9AA6),
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _InputField(
                        controller: _phoneController,
                        title: 'Business WhatsApp number',
                        hint: '+919876543210',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _InputField(
                        controller: _phoneIdController,
                        title: 'WhatsApp Cloud API phone number ID',
                        hint: 'Meta phone number ID',
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _enabled,
                        activeColor: const Color(0xFF34F087),
                        title: const Text(
                          'Enable WhatsApp ordering',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Accept and validate incoming ORDER messages.',
                          style: TextStyle(color: Colors.white60),
                        ),
                        onChanged: (value) => setState(() => _enabled = value),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFF9AA6)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_isSaving ? 'Saving...' : 'Save setup'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The Meta access token and webhook verification are configured on the backend.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer order format',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        config?.orderMessageTemplate ??
                            'ORDER <PRODUCT-CODE> / QTY 1 / NAME Your Name / PHONE +91XXXXXXXXXX / PIN 123456 / ADDRESS Full delivery address / PAYMENT COD',
                        style: const TextStyle(
                          color: Color(0xFFD8E8DE),
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: config == null
                            ? null
                            : () => _copy(
                                config.orderMessageTemplate,
                                'Order message template',
                              ),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy template'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share-ready order link',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        config?.orderLink ??
                            'Save your business number to generate a link.',
                        style: const TextStyle(
                          color: Color(0xFF9DF6FF),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: config?.orderLink == null
                                ? null
                                : () => _copy(config!.orderLink!, 'Order link'),
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copy link'),
                          ),
                          FilledButton.icon(
                            onPressed: config?.orderLink == null
                                ? null
                                : _openLink,
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open WhatsApp'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Panel(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF34F087),
                        ),
                        title: const Text(
                          'Message templates',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Edit confirmation, shipped, and delivered messages.',
                          style: TextStyle(color: Colors.white60),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white70,
                        ),
                        onTap: () =>
                            context.push('/whatsapp-ordering/templates'),
                      ),
                      const Divider(color: Colors.white12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.inbox_rounded,
                          color: Color(0xFF9DF6FF),
                        ),
                        title: const Text(
                          'Incoming order inbox',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Review validation and customer confirmations.',
                          style: TextStyle(color: Colors.white60),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white70,
                        ),
                        onTap: () => context.push('/whatsapp-orders'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF101A14),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    ),
    child: child,
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.title,
    required this.hint,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String title;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: title,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
