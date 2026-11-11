import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'returns_api.dart';

const _green = Color(0xFF34F087);
const _background = Color(0xFF050807);
const _conditions = <String, String>{
  'unused': 'Unused',
  'unworn': 'Unworn',
  'original_packaging': 'Original packaging',
  'tags_attached': 'Tags attached',
  'proof_of_purchase': 'Proof of purchase',
};

class ReturnPolicyScreen extends StatefulWidget {
  const ReturnPolicyScreen({super.key});

  @override
  State<ReturnPolicyScreen> createState() => _ReturnPolicyScreenState();
}

class _ReturnPolicyScreenState extends State<ReturnPolicyScreen> {
  final _daysController = TextEditingController(text: '7');
  final _textController = TextEditingController();
  final Set<String> _selectedConditions = {};
  final Set<String> _nonReturnableIds = {};
  List<Map<String, dynamic>> _products = [];
  bool _allowRefund = true;
  bool _allowExchange = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _daysController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final policy = await returnsApi.getPolicy();
      final productResponse = await apiClient.get('/products');
      final productData = productResponse.data as Map;
      if (!mounted) return;
      setState(() {
        _products = (productData['products'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (policy != null) {
          _daysController.text =
              policy['return_window_days']?.toString() ?? '7';
          _textController.text = policy['policy_text']?.toString() ?? '';
          _selectedConditions
            ..clear()
            ..addAll(
              (policy['eligible_conditions'] as List? ?? const []).map(
                (value) => value.toString(),
              ),
            );
          _nonReturnableIds
            ..clear()
            ..addAll(
              (policy['non_returnable_product_ids'] as List? ?? const []).map(
                (value) => value.toString(),
              ),
            );
          _allowRefund = policy['allow_refund'] != false;
          _allowExchange = policy['allow_exchange'] == true;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = returnsErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final days = int.tryParse(_daysController.text.trim());
    if (days == null || days < 1 || days > 365) {
      _message('Return window must be between 1 and 365 days');
      return;
    }
    if (_textController.text.trim().isEmpty) {
      _message('Enter the customer-facing policy text');
      return;
    }
    if (!_allowRefund && !_allowExchange) {
      _message('Enable refund or exchange');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await returnsApi.savePolicy({
        'return_window_days': days,
        'eligible_conditions': _selectedConditions.toList(),
        'non_returnable_product_ids': _nonReturnableIds.toList(),
        'allow_refund': _allowRefund,
        'allow_exchange': _allowExchange,
        'policy_text': _textController.text.trim(),
      });
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Return policy saved');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = returnsErrorMessage(error);
        _saving = false;
      });
    }
  }

  Future<void> _chooseProducts() async {
    final selected = Set<String>.from(_nonReturnableIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101A14),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Non-returnable products',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: _products.map((product) {
                      final id = product['id'].toString();
                      return CheckboxListTile(
                        value: selected.contains(id),
                        activeColor: _green,
                        title: Text(
                          product['name']?.toString() ?? 'Product',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onChanged: (value) => setSheetState(() {
                          value == true
                              ? selected.add(id)
                              : selected.remove(id);
                        }),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('Save selection'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _nonReturnableIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      title: const Text('Return Policy'),
      backgroundColor: const Color(0xFF07120C),
      foregroundColor: Colors.white,
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _products.isEmpty
        ? _ErrorState(message: _error!, onRetry: _load)
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) _ErrorBanner(message: _error!),
              _Section(
                title: 'Return window',
                child: TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Days after delivery',
                    suffixText: 'days',
                  ),
                ),
              ),
              _Section(
                title: 'Eligible conditions',
                child: Column(
                  children: _conditions.entries.map((entry) {
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: _green,
                      title: Text(entry.value),
                      value: _selectedConditions.contains(entry.key),
                      onChanged: (value) => setState(() {
                        value == true
                            ? _selectedConditions.add(entry.key)
                            : _selectedConditions.remove(entry.key);
                      }),
                    );
                  }).toList(),
                ),
              ),
              _Section(
                title: 'Non-returnable products',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${_nonReturnableIds.length} selected'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _chooseProducts,
                ),
              ),
              _Section(
                title: 'Available outcomes',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: _green,
                      title: const Text('Refund'),
                      value: _allowRefund,
                      onChanged: (value) =>
                          setState(() => _allowRefund = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: _green,
                      title: const Text('Exchange'),
                      value: _allowExchange,
                      onChanged: (value) =>
                          setState(() => _allowExchange = value),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'Policy shown to customers',
                child: TextField(
                  controller: _textController,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    hintText: 'Explain your return and exchange policy',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving…' : 'Save policy'),
              ),
            ],
          ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF101A14),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.red.withOpacity(.2),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(message, style: const TextStyle(color: Colors.white)),
    ),
  );
}
