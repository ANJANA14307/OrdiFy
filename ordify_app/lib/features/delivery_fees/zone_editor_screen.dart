import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'delivery_models.dart';

class ZoneEditorScreen extends StatefulWidget {
  final DeliveryZone? initialZone;

  const ZoneEditorScreen({super.key, this.initialZone});

  @override
  State<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends State<ZoneEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _feeController;
  late final TextEditingController _daysController;
  final List<String> _pincodes = [];
  String? _pincodeError;

  @override
  void initState() {
    super.initState();
    final zone = widget.initialZone;
    _nameController = TextEditingController(text: zone?.name ?? '');
    _pincodeController = TextEditingController();
    _feeController = TextEditingController(text: zone?.fee.toString() ?? '');
    _daysController = TextEditingController(
      text: zone?.estimatedDeliveryDays.toString() ?? '3',
    );
    _pincodes.addAll(zone?.pincodes ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pincodeController.dispose();
    _feeController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _addPincodes(String input) {
    final entries = input
        .split(RegExp(r'[,;\s]+'))
        .where((item) => item.isNotEmpty);
    final invalid = <String>[];
    final added = <String>[];

    for (final entry in entries) {
      if (!RegExp(r'^\d{6}$').hasMatch(entry)) {
        invalid.add(entry);
      } else if (!_pincodes.contains(entry) && !added.contains(entry)) {
        added.add(entry);
      }
    }

    setState(() {
      _pincodes.addAll(added);
      _pincodeController.clear();
      _pincodeError = invalid.isEmpty
          ? null
          : 'Invalid pincode${invalid.length > 1 ? 's' : ''}: ${invalid.join(', ')}';
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_pincodes.isEmpty) {
      setState(() => _pincodeError = 'Add at least one 6-digit pincode');
      return;
    }
    final fee = double.parse(_feeController.text.trim());
    final days = int.parse(_daysController.text.trim());
    Navigator.pop(
      context,
      DeliveryZone(
        name: _nameController.text.trim(),
        pincodes: List<String>.from(_pincodes),
        fee: fee,
        estimatedDeliveryDays: days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1711),
        foregroundColor: Colors.white,
        title: Text(
          widget.initialZone == null
              ? 'Add Delivery Zone'
              : 'Edit Delivery Zone',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _field(
                controller: _nameController,
                label: 'Zone name',
                hint: 'Bengaluru',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Zone name is required'
                    : null,
              ),
              const SizedBox(height: 18),
              Text(
                'Pincodes',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add or paste comma-separated pincodes',
                        hintStyle: const TextStyle(color: Colors.white38),
                        errorText: _pincodeError,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onSubmitted: _addPincodes,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _addPincodes(_pincodeController.text),
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF34F087),
                    ),
                  ),
                ],
              ),
              if (_pincodes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _pincodes
                      .map(
                        (pincode) => InputChip(
                          label: Text(pincode),
                          onDeleted: () {
                            setState(() => _pincodes.remove(pincode));
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _feeController,
                      label: 'Delivery fee',
                      hint: '50',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final fee = double.tryParse(value ?? '');
                        return fee == null || fee < 0
                            ? 'Enter a valid fee'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _daysController,
                      label: 'Delivery days',
                      hint: '3',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final days = int.tryParse(value ?? '');
                        return days == null || days < 1 || days > 90
                            ? 'Enter 1–90 days'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF34F087),
                    foregroundColor: const Color(0xFF052113),
                  ),
                  child: const Text('Save Zone'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
