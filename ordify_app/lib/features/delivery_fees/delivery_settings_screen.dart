import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'delivery_models.dart';
import 'zone_editor_screen.dart';

class DeliverySettingsScreen extends StatefulWidget {
  const DeliverySettingsScreen({super.key});

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  final _flatFeeController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _subtotalController = TextEditingController(text: '1000');

  String _ruleType = 'flat_fee';
  List<DeliveryZone> _zones = [];
  DeliveryQuote? _quote;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isQuoting = false;
  bool _hasSettings = false;
  String? _errorMessage;
  String? _quoteError;
  String? _pincodeError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _flatFeeController.dispose();
    _thresholdController.dispose();
    _pincodeController.dispose();
    _subtotalController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await apiClient.get('/delivery-fees/settings');
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawSettings = data['settings'];
      if (rawSettings is Map) {
        final settings = DeliveryRule.fromJson(
          Map<String, dynamic>.from(rawSettings),
        );
        _ruleType = settings.ruleType;
        _flatFeeController.text = settings.flatFee.toString();
        _thresholdController.text =
            settings.freeDeliveryThreshold?.toString() ?? '';
        _zones = settings.zones;
        _hasSettings = true;
      } else {
        _hasSettings = false;
        _ruleType = 'flat_fee';
        _flatFeeController.clear();
        _thresholdController.clear();
        _zones = [];
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _errorMessageFor(error);
        _isLoading = false;
      });
    }
  }

  String _errorMessageFor(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        if (detail is List) {
          return detail
              .whereType<Map>()
              .map((item) => item['msg']?.toString())
              .whereType<String>()
              .join('\n');
        }
        return detail.toString();
      }
    }
    return error.toString();
  }

  Future<void> _saveSettings() async {
    final flatFee = double.tryParse(_flatFeeController.text.trim());
    if (_ruleType != 'pincode_zone' && (flatFee == null || flatFee < 0)) {
      _showMessage('Enter a valid delivery fee');
      return;
    }

    double? threshold;
    if (_ruleType == 'free_above_minimum') {
      threshold = double.tryParse(_thresholdController.text.trim());
      if (threshold == null || threshold < 0) {
        _showMessage('Enter a valid minimum order amount');
        return;
      }
    }
    if (_ruleType == 'pincode_zone' && _zones.isEmpty) {
      _showMessage('Add at least one delivery zone');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _quoteError = null;
    });
    try {
      final response = await apiClient.put(
        '/delivery-fees/settings',
        data: {
          'rule_type': _ruleType,
          'flat_fee': flatFee ?? 0,
          'free_delivery_threshold': threshold,
          'zones': _zones.map((zone) => zone.toJson()).toList(),
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final saved = DeliveryRule.fromJson(
        Map<String, dynamic>.from(data['settings'] as Map),
      );
      if (!mounted) return;
      setState(() {
        _ruleType = saved.ruleType;
        _flatFeeController.text = saved.flatFee.toString();
        _thresholdController.text =
            saved.freeDeliveryThreshold?.toString() ?? '';
        _zones = saved.zones;
        _hasSettings = true;
        _isSaving = false;
      });
      _showMessage('Delivery settings saved');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _errorMessageFor(error);
        _isSaving = false;
      });
    }
  }

  Future<void> _testQuote() async {
    final pincode = _pincodeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pincode)) {
      setState(() {
        _pincodeError = 'Enter a valid 6-digit pincode';
        _quote = null;
        _quoteError = null;
      });
      return;
    }

    final subtotal = double.tryParse(_subtotalController.text.trim());
    if (subtotal == null || subtotal < 0) {
      _showMessage('Enter a valid test subtotal');
      return;
    }

    setState(() {
      _isQuoting = true;
      _pincodeError = null;
      _quoteError = null;
      _quote = null;
    });
    try {
      final response = await apiClient.post(
        '/delivery-fees/quote',
        data: {'pincode': pincode, 'subtotal': subtotal},
      );
      final quote = DeliveryQuote.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _isQuoting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _quoteError = _errorMessageFor(error);
        _isQuoting = false;
      });
    }
  }

  Future<void> _editZone({int? index}) async {
    final editedZone = await Navigator.of(context).push<DeliveryZone>(
      MaterialPageRoute(
        builder: (_) =>
            ZoneEditorScreen(initialZone: index == null ? null : _zones[index]),
      ),
    );
    if (!mounted || editedZone == null) return;
    setState(() {
      if (index == null) {
        _zones = [..._zones, editedZone];
      } else {
        final updated = List<DeliveryZone>.from(_zones);
        updated[index] = editedZone;
        _zones = updated;
      }
      _quote = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1711),
        foregroundColor: Colors.white,
        title: Text(
          'Delivery Charges',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF34F087)),
              )
            : _errorMessage != null && !_hasSettings
            ? _loadErrorView()
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  if (!_hasSettings) ...[
                    _infoCard(
                      icon: Icons.info_outline_rounded,
                      title: 'No delivery rules yet',
                      message:
                          'Choose a rule, configure its fee, then save your settings.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Choose a delivery rule',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ruleCard(
                    value: 'flat_fee',
                    title: 'Flat fee',
                    subtitle: 'Charge the same fee for every order.',
                    icon: Icons.local_shipping_outlined,
                    child: _amountField(
                      controller: _flatFeeController,
                      label: 'Delivery fee',
                      hint: '50',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ruleCard(
                    value: 'free_above_minimum',
                    title: 'Free delivery above minimum',
                    subtitle:
                        'Use the flat fee below the minimum order amount.',
                    icon: Icons.free_cancellation_outlined,
                    child: Column(
                      children: [
                        _amountField(
                          controller: _flatFeeController,
                          label: 'Fee below minimum',
                          hint: '50',
                        ),
                        const SizedBox(height: 12),
                        _amountField(
                          controller: _thresholdController,
                          label: 'Minimum order amount for free delivery',
                          hint: '999',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ruleCard(
                    value: 'pincode_zone',
                    title: 'Pincode / zone-based',
                    subtitle: 'Set fees and delivery times by service area.',
                    icon: Icons.map_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._zones.indexed.map((entry) {
                          final index = entry.$1;
                          final zone = entry.$2;
                          return Card(
                            color: Colors.white.withValues(alpha: 0.06),
                            child: ListTile(
                              onTap: () => _editZone(index: index),
                              title: Text(
                                zone.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${zone.pincodes.length} pincodes · ${zone.estimatedDeliveryDays} days',
                                style: const TextStyle(color: Colors.white60),
                              ),
                              trailing: Text(
                                '₹${zone.fee.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF34F087),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              leading: IconButton(
                                tooltip: 'Remove zone',
                                onPressed: () {
                                  setState(() {
                                    _zones = List<DeliveryZone>.from(_zones)
                                      ..removeAt(index);
                                    _quote = null;
                                    _quoteError = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          );
                        }),
                        OutlinedButton.icon(
                          onPressed: () => _editZone(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Zone'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF34F087),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF34F087),
                        foregroundColor: const Color(0xFF052113),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Delivery Rules',
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _infoCard(
                      icon: Icons.error_outline,
                      title: 'Could not save settings',
                      message: _errorMessage!,
                      child: TextButton(
                        onPressed: _loadSettings,
                        child: const Text('Reload settings'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Test a pincode',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _infoCard(
                    icon: Icons.calculate_outlined,
                    title: 'Backend quote preview',
                    message:
                        'Enter a pincode and subtotal to preview the backend-calculated fee.',
                    child: Column(
                      children: [
                        TextField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Pincode',
                            errorText: _pincodeError,
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _amountField(
                          controller: _subtotalController,
                          label: 'Test subtotal',
                          hint: '1000',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isQuoting ? null : _testQuote,
                            child: _isQuoting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Get Quote'),
                          ),
                        ),
                        if (_quote != null) ...[
                          const SizedBox(height: 12),
                          if (!_quote!.isDeliverable)
                            Text(
                              _quote!.message ?? 'Pincode is not deliverable',
                              style: const TextStyle(
                                color: Color(0xFFFF7D88),
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            _quoteResult(_quote!),
                        ],
                        if (_quoteError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _quoteError!,
                            style: const TextStyle(
                              color: Color(0xFFFF7D88),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: _isQuoting ? null : _testQuote,
                            child: const Text('Retry quote'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _loadErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Color(0xFFFF7D88), size: 40),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _loadSettings, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _ruleCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final selected = _ruleType == value;
    return InkWell(
      onTap: () => setState(() {
        _ruleType = value;
        _quote = null;
        _quoteError = null;
      }),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF101A16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF34F087) : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF34F087)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? const Color(0xFF34F087) : Colors.white54,
                ),
              ],
            ),
            if (selected) ...[const SizedBox(height: 14), child],
          ],
        ),
      ),
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: '₹ ',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101A16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF34F087)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.white60)),
          if (child != null) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }

  Widget _quoteResult(DeliveryQuote quote) {
    final fee = quote.deliveryFee == 0
        ? 'FREE'
        : '₹${quote.deliveryFee.toStringAsFixed(2)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery fee: $fee',
          style: const TextStyle(
            color: Color(0xFF34F087),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Estimated total: ₹${quote.total.toStringAsFixed(2)}'
          '${quote.estimatedDeliveryDays == null ? '' : ' · ${quote.estimatedDeliveryDays} days'}',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
