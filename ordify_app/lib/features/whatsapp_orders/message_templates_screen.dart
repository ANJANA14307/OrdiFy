import 'package:flutter/material.dart';

import 'whatsapp_order_models.dart';
import 'whatsapp_orders_api.dart';

class MessageTemplatesScreen extends StatefulWidget {
  const MessageTemplatesScreen({super.key});

  @override
  State<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends State<MessageTemplatesScreen> {
  final _confirmation = TextEditingController();
  final _shipped = TextEditingController();
  final _delivered = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confirmation.dispose();
    _shipped.dispose();
    _delivered.dispose();
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
        _confirmation.text = config.templates.confirmation;
        _shipped.text = config.templates.shipped;
        _delivered.text = config.templates.delivered;
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
      await whatsappOrdersApi.saveTemplates(
        MessageTemplate(
          confirmation: _confirmation.text.trim(),
          shipped: _shipped.text.trim(),
          delivered: _delivered.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message templates saved')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isSaving = false;
      });
    }
  }

  String _preview(String input) => input
      .replaceAll('{name}', 'Aarav')
      .replaceAll('{order_id}', 'ORD-A1B2C3')
      .replaceAll('{total}', '1,250.00');

  Widget _templateField({
    required String title,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, height: 1.4),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF07120C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF34F087).withOpacity(0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LIVE PREVIEW',
                style: TextStyle(
                  color: Color(0xFF34F087),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _preview(controller.text),
                style: const TextStyle(color: Colors.white, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        title: const Text('Message Templates'),
        backgroundColor: const Color(0xFF07120C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _confirmation.text.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13271B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF34F087).withOpacity(0.22),
                    ),
                  ),
                  child: const Text(
                    'Available placeholders: {name}, {order_id}, {total}',
                    style: TextStyle(color: Color(0xFFDAF5E3), height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                _templateField(
                  title: 'Order confirmation',
                  hint: 'Use {name}, {order_id}, and {total}',
                  controller: _confirmation,
                ),
                const SizedBox(height: 22),
                _templateField(
                  title: 'Order shipped',
                  hint: 'Use {name}, {order_id}, and {total}',
                  controller: _shipped,
                ),
                const SizedBox(height: 22),
                _templateField(
                  title: 'Order delivered',
                  hint: 'Use {name}, {order_id}, and {total}',
                  controller: _delivered,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save templates'),
                  ),
                ),
              ],
            ),
    );
  }
}
