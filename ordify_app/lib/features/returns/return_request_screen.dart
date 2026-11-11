import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'return_models.dart';
import 'returns_api.dart';

class ReturnRequestScreen extends StatefulWidget {
  const ReturnRequestScreen({required this.orderId, super.key});

  final String orderId;

  @override
  State<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends State<ReturnRequestScreen> {
  final _commentController = TextEditingController();
  final _picker = ImagePicker();
  Map<String, dynamic> _eligibility = {};
  List<ReturnItem> _items = [];
  final Map<String, int> _quantities = {};
  final List<String> _photos = [];
  String _reason = 'damaged';
  String _outcome = 'refund';
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await returnsApi.getEligibility(widget.orderId);
      if (!mounted) return;
      final items = (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => ReturnItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      setState(() {
        _eligibility = data;
        _items = items;
        final policy = data['policy'];
        if (policy is Map &&
            policy['allow_refund'] == false &&
            policy['allow_exchange'] == true) {
          _outcome = 'exchange';
        } else {
          _outcome = 'refund';
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

  Future<void> _addPhoto() async {
    if (_photos.length >= 5) {
      _message('You can add up to five photos');
      return;
    }
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (image == null || !mounted) return;
      setState(() => _submitting = true);
      final url = await returnsApi.uploadPhoto(image);
      if (!mounted) return;
      setState(() {
        _photos.add(url);
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _message('Photo upload failed: ${returnsErrorMessage(error)}');
    }
  }

  Future<void> _submit() async {
    final selectedItems = _items
        .where(
          (item) => item.eligible && (_quantities[item.orderItemId] ?? 0) > 0,
        )
        .map(
          (item) => {
            'order_item_id': item.orderItemId,
            'quantity': _quantities[item.orderItemId],
          },
        )
        .toList();
    if (selectedItems.isEmpty) {
      _message('Select at least one eligible item');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final request = await returnsApi.createRequest(widget.orderId, {
        'items': selectedItems,
        'reason': _reason,
        'comment': _commentController.text.trim(),
        'photos': _photos,
        'preferred_outcome': _outcome,
      });
      if (!mounted) return;
      setState(() => _submitting = false);
      _message('Return request submitted');
      context.go('/returns/${request.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = returnsErrorMessage(error);
        _submitting = false;
      });
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050807),
    appBar: AppBar(
      title: const Text('Request return'),
      backgroundColor: const Color(0xFF07120C),
      foregroundColor: Colors.white,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _eligibility.isEmpty
        ? _RequestMessage(
            title: 'Could not check eligibility',
            message: _error!,
            onRetry: _load,
          )
        : _eligibility['eligible'] != true
        ? _RequestMessage(
            title: 'Return not available',
            message:
                _eligibility['reason']?.toString() ??
                'This order is not eligible for return.',
            onRetry: _load,
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              if ((_eligibility['policy']?['policy_text']?.toString() ?? '')
                  .isNotEmpty)
                _RequestCard(
                  child: Text(
                    _eligibility['policy']['policy_text'].toString(),
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
              _RequestCard(
                title: 'Choose items and quantity',
                child: Column(children: _items.map(_itemTile).toList()),
              ),
              _RequestCard(
                title: 'Reason',
                child: DropdownButtonFormField<String>(
                  value: _reason,
                  items: const [
                    DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                    DropdownMenuItem(
                      value: 'wrong_item',
                      child: Text('Wrong item'),
                    ),
                    DropdownMenuItem(
                      value: 'not_as_described',
                      child: Text('Not as described'),
                    ),
                    DropdownMenuItem(
                      value: 'size_or_fit',
                      child: Text('Size or fit'),
                    ),
                    DropdownMenuItem(
                      value: 'changed_mind',
                      child: Text('Changed my mind'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _reason = value);
                  },
                ),
              ),
              _RequestCard(
                title: 'Comment',
                child: TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    hintText: 'Add helpful details',
                  ),
                ),
              ),
              _RequestCard(
                title: 'Photos (optional)',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._photos.map(
                      (url) => InputChip(
                        label: Text('Photo ${_photos.indexOf(url) + 1}'),
                        onDeleted: () => setState(() => _photos.remove(url)),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Add photo'),
                      onPressed: _submitting ? null : _addPhoto,
                    ),
                  ],
                ),
              ),
              _RequestCard(
                title: 'Preferred outcome',
                child: Column(
                  children: [
                    if (_eligibility['policy']?['allow_refund'] != false)
                      RadioListTile<String>(
                        value: 'refund',
                        groupValue: _outcome,
                        title: const Text('Refund'),
                        onChanged: (value) => setState(() => _outcome = value!),
                      ),
                    if (_eligibility['policy']?['allow_exchange'] == true)
                      RadioListTile<String>(
                        value: 'exchange',
                        groupValue: _outcome,
                        title: const Text('Exchange'),
                        onChanged: (value) => setState(() => _outcome = value!),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.assignment_return_outlined),
                label: Text(
                  _submitting ? 'Submitting…' : 'Submit return request',
                ),
              ),
            ],
          ),
  );

  Widget _itemTile(ReturnItem item) {
    final selectedQuantity = _quantities[item.orderItemId] ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.productName),
      subtitle: Text(
        item.eligible
            ? '${item.variantCode.isEmpty ? '' : '${item.variantCode} • '}${item.quantity} available • ₹${item.unitPrice.toStringAsFixed(2)}'
            : item.ineligibleReason ?? 'Not eligible for return',
      ),
      leading: Checkbox(
        value: selectedQuantity > 0,
        onChanged: !item.eligible
            ? null
            : (selected) => setState(() {
                _quantities[item.orderItemId] = selected == true ? 1 : 0;
              }),
      ),
      trailing: item.eligible
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: selectedQuantity <= 0
                      ? null
                      : () => setState(
                          () => _quantities[item.orderItemId] =
                              selectedQuantity - 1,
                        ),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$selectedQuantity'),
                IconButton(
                  onPressed: selectedQuantity >= item.quantity
                      ? null
                      : () => setState(
                          () => _quantities[item.orderItemId] =
                              selectedQuantity + 1,
                        ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            )
          : const Icon(Icons.block, color: Colors.white54),
      isThreeLine: !item.eligible,
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.child, this.title});
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF101A14),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    ),
  );
}

class _RequestMessage extends StatelessWidget {
  const _RequestMessage({
    required this.title,
    required this.message,
    required this.onRetry,
  });
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
