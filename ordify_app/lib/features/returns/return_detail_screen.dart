import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'return_models.dart';
import 'returns_api.dart';

const _flow = ['return_requested', 'approved', 'item_received', 'inspected'];

const _labels = {
  'return_requested': 'Return requested',
  'approved': 'Approved',
  'item_received': 'Item received',
  'inspected': 'Inspected',
  'refund_issued': 'Refund issued',
  'exchange_created': 'Exchange created',
  'rejected': 'Rejected',
};

class ReturnDetailScreen extends StatefulWidget {
  const ReturnDetailScreen({required this.returnId, super.key});

  final String returnId;

  @override
  State<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends State<ReturnDetailScreen> {
  final _picker = ImagePicker();
  ReturnRequest? _request;
  bool _loading = true;
  bool _saving = false;
  bool _allowRefund = true;
  bool _allowExchange = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await returnsApi.getReturn(widget.returnId);
      final policy = await returnsApi.getPolicy();
      if (!mounted) return;
      setState(() {
        _request = request;
        _allowRefund = policy?['allow_refund'] != false;
        _allowExchange = policy?['allow_exchange'] == true;
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

  Future<void> _act(
    String action, {
    Map<String, dynamic> values = const {},
  }) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await returnsApi.act(widget.returnId, {
        'action': action,
        ...values,
      });
      if (!mounted) return;
      setState(() {
        _request = updated;
        _saving = false;
      });
      _message('${_labels[updated.status] ?? updated.status} updated');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = returnsErrorMessage(error);
        _saving = false;
      });
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject return'),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _act('reject', values: {'reason': reason});
  }

  Future<void> _inspect() async {
    final request = _request!;
    final quantities = <String, TextEditingController>{
      for (final item in request.items)
        item.orderItemId: TextEditingController(text: item.quantity.toString()),
    };
    final photos = <String>[];
    String? notes;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Inspect returned items'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...request.items.map((item) {
                    final controller = quantities[item.orderItemId]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} (requested ${item.quantity})',
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Accept',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextField(
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Inspection notes',
                    ),
                    onChanged: (value) => notes = value,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: photos.length >= 5
                          ? null
                          : () async {
                              try {
                                final image = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 82,
                                );
                                if (image == null) return;
                                final url = await returnsApi.uploadPhoto(image);
                                setDialogState(() => photos.add(url));
                              } catch (error) {
                                if (mounted) {
                                  _message(
                                    'Photo upload failed: ${returnsErrorMessage(error)}',
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text('Add inspection photo (${photos.length}/5)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final inspectedItems = <Map<String, dynamic>>[];
                var accepted = 0;
                var requested = 0;
                for (final item in request.items) {
                  final quantity = int.tryParse(
                    quantities[item.orderItemId]!.text.trim(),
                  );
                  if (quantity == null ||
                      quantity < 0 ||
                      quantity > item.quantity) {
                    _message(
                      'Accepted quantities must be from 0 to requested amount',
                    );
                    return;
                  }
                  requested += item.quantity;
                  accepted += quantity;
                  inspectedItems.add({
                    'order_item_id': item.orderItemId,
                    'accepted_quantity': quantity,
                  });
                }
                final inspectionResult = accepted == 0
                    ? 'rejected'
                    : accepted == requested
                    ? 'accepted'
                    : 'partially_accepted';
                Navigator.pop(dialogContext, {
                  'inspection_result': inspectionResult,
                  'inspected_items': inspectedItems,
                  'notes': notes,
                  'photos': photos,
                });
              },
              child: const Text('Complete inspection'),
            ),
          ],
        ),
      ),
    );
    for (final controller in quantities.values) {
      controller.dispose();
    }
    if (result != null) await _act('inspect', values: result);
  }

  Future<void> _issueRefund() async {
    final request = _request!;
    final maximum = request.items.fold<double>(
      0,
      (total, item) => total + item.unitPrice * (item.acceptedQuantity ?? 0),
    );
    final controller = TextEditingController(text: maximum.toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record completed refund'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Refund amount',
            prefixText: '₹ ',
            helperText:
                'Enter the amount already refunded. Maximum accepted item value: ₹${maximum.toStringAsFixed(2)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('Confirm refund recorded'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null) return;
    await _act('issue_refund', values: {'refund_amount': amount});
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        title: const Text('Return details'),
        backgroundColor: const Color(0xFF07120C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : request == null
          ? _DetailError(
              message: _error ?? 'Return request not found',
              onRetry: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Card(
                    color: Colors.red.withOpacity(.2),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!),
                    ),
                  ),
                _DetailCard(
                  title: 'Order ${request.orderId}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${_labels[request.status] ?? request.status}',
                      ),
                      Text('Reason: ${request.reason.replaceAll('_', ' ')}'),
                      Text('Preferred outcome: ${request.preferredOutcome}'),
                      if (request.comment?.isNotEmpty == true)
                        Text('Comment: ${request.comment}'),
                      if (request.rejectionReason != null)
                        Text('Rejection reason: ${request.rejectionReason}'),
                      if (request.refundAmount != null)
                        Text(
                          'Refund recorded: ₹${request.refundAmount!.toStringAsFixed(2)}',
                        ),
                      if (request.exchangeOrderId != null)
                        Text('Exchange order: ${request.exchangeOrderId}'),
                    ],
                  ),
                ),
                _DetailCard(
                  title: 'Return items',
                  child: Column(
                    children: request.items.map((item) {
                      final accepted = item.acceptedQuantity;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.productName),
                        subtitle: Text(
                          '${item.variantCode.isEmpty ? '' : '${item.variantCode} • '}${item.quantity} requested${accepted == null ? '' : ' • $accepted accepted'}',
                        ),
                        trailing: Text('₹${item.unitPrice.toStringAsFixed(2)}'),
                      );
                    }).toList(),
                  ),
                ),
                _DetailCard(
                  title: 'Return progress',
                  child: Column(
                    children: [
                      ..._flow.map(
                        (status) => _TimelineStep(
                          label: _labels[status]!,
                          active:
                              request.status != 'rejected' &&
                              _flow.indexOf(status) <=
                                  (request.status == 'refund_issued' ||
                                          request.status == 'exchange_created'
                                      ? _flow.length - 1
                                      : _flow.indexOf(request.status)),
                          terminal: request.status == 'rejected',
                        ),
                      ),
                      if (request.status == 'rejected')
                        const _TimelineStep(
                          label: 'Rejected',
                          active: true,
                          terminal: true,
                        ),
                      if (request.status == 'refund_issued')
                        const _TimelineStep(
                          label: 'Refund issued',
                          active: true,
                        ),
                      if (request.status == 'exchange_created')
                        const _TimelineStep(
                          label: 'Exchange created',
                          active: true,
                        ),
                      const SizedBox(height: 10),
                      ...request.messages.map(
                        (message) => Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${message['message'] ?? message['status'] ?? 'Updated'} • ${message['at'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (request.photos.isNotEmpty)
                  _DetailCard(
                    title: 'Request photos',
                    child: _ReturnPhotos(urls: request.photos),
                  ),
                if (request.inspectionPhotos.isNotEmpty)
                  _DetailCard(
                    title: 'Inspection photos',
                    child: _ReturnPhotos(urls: request.inspectionPhotos),
                  ),
                if (request.inspectionNotes?.isNotEmpty == true)
                  _DetailCard(
                    title: 'Inspection notes',
                    child: Text(request.inspectionNotes!),
                  ),
                const Card(
                  color: Color(0xFF18251D),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Stock will be restored only after inspection, for accepted quantities.',
                      style: TextStyle(color: Color(0xFF34F087)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._actions(request),
              ],
            ),
    );
  }

  List<Widget> _actions(ReturnRequest request) {
    final actions = <Widget>[];
    if (request.status == 'return_requested') {
      actions.add(
        _ActionButton(
          label: 'Approve',
          onPressed: _saving ? null : () => _act('approve'),
        ),
      );
      actions.add(
        _ActionButton(
          label: 'Reject',
          outlined: true,
          onPressed: _saving ? null : _reject,
        ),
      );
    } else if (request.status == 'approved') {
      actions.add(
        _ActionButton(
          label: 'Mark item received',
          onPressed: _saving ? null : () => _act('mark_received'),
        ),
      );
      actions.add(
        _ActionButton(
          label: 'Reject',
          outlined: true,
          onPressed: _saving ? null : _reject,
        ),
      );
    } else if (request.status == 'item_received') {
      actions.add(
        _ActionButton(
          label: 'Inspect items',
          onPressed: _saving ? null : _inspect,
        ),
      );
    } else if (request.status == 'inspected' &&
        request.inspectionResult != 'rejected') {
      if (_allowRefund) {
        actions.add(
          _ActionButton(
            label: 'Record refund',
            onPressed: _saving ? null : _issueRefund,
          ),
        );
      }
      if (_allowExchange) {
        actions.add(
          _ActionButton(
            label: 'Create exchange',
            outlined: true,
            onPressed: _saving ? null : () => _act('create_exchange'),
          ),
        );
      }
    }
    if (_saving) {
      actions.insert(
        0,
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return actions;
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.active,
    this.terminal = false,
  });
  final String label;
  final bool active;
  final bool terminal;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      active ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
      color: terminal
          ? Colors.redAccent
          : active
          ? const Color(0xFF34F087)
          : Colors.white30,
    ),
    title: Text(
      label,
      style: TextStyle(color: active ? Colors.white : Colors.white54),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(onPressed: onPressed, child: Text(label))
          : FilledButton(onPressed: onPressed, child: Text(label)),
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ReturnPhotos extends StatelessWidget {
  const _ReturnPhotos({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 110,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: urls.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          urls[index],
          width: 110,
          height: 110,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            width: 110,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    ),
  );
}
