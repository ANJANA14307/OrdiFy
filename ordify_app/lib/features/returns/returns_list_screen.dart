import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'return_models.dart';
import 'returns_api.dart';

const _returnStatuses = <String, String>{
  'all': 'All',
  'return_requested': 'Requested',
  'approved': 'Approved',
  'item_received': 'Received',
  'inspected': 'Inspected',
  'refund_issued': 'Refunded',
  'exchange_created': 'Exchanged',
  'rejected': 'Rejected',
};

class ReturnsListScreen extends StatefulWidget {
  const ReturnsListScreen({super.key});

  @override
  State<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends State<ReturnsListScreen> {
  final _searchController = TextEditingController();
  List<ReturnRequest> _returns = [];
  bool _loading = true;
  String? _error;
  String _status = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await returnsApi.getReturns();
      if (!mounted) return;
      setState(() {
        _returns = result;
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

  List<ReturnRequest> get _filtered => _returns.where((request) {
    final matchesStatus = _status == 'all' || request.status == _status;
    final searchable = [
      request.orderId,
      request.id,
      ...request.items.map((item) => item.productName),
    ].join(' ').toLowerCase();
    return matchesStatus && searchable.contains(_search.trim().toLowerCase());
  }).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050807),
    appBar: AppBar(
      title: const Text('Returns'),
      backgroundColor: const Color(0xFF07120C),
      foregroundColor: Colors.white,
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _ReturnsMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load returns',
            message: _error!,
            onRetry: _load,
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    hintText: 'Search order, return, or product',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _returnStatuses.entries.map((entry) {
                      final selected = _status == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _status = entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                if (_filtered.isEmpty)
                  const _ReturnsMessage(
                    icon: Icons.assignment_return_outlined,
                    title: 'No return requests',
                    message: 'New return requests will appear here.',
                  )
                else
                  ..._filtered.map(
                    (request) => _ReturnCard(
                      request: request,
                      onTap: () async {
                        await context.push('/returns/${request.id}');
                        if (mounted) _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.request, required this.onTap});
  final ReturnRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF101A14),
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: onTap,
      title: Text(
        'Order ${request.orderId.substring(0, request.orderId.length > 8 ? 8 : request.orderId.length)}',
      ),
      subtitle: Text(
        '${request.items.map((item) => item.productName).join(', ')} • ${request.items.fold<int>(0, (total, item) => total + item.quantity)} item(s)',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _StatusPill(status: request.status),
          const SizedBox(height: 5),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _returnStatuses[status] ?? status.replaceAll('_', ' ');
    final color = status == 'rejected'
        ? Colors.redAccent
        : status == 'refund_issued' || status == 'exchange_created'
        ? const Color(0xFF34F087)
        : const Color(0xFFFFC857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReturnsMessage extends StatelessWidget {
  const _ReturnsMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 18),
    child: Column(
      children: [
        Icon(icon, size: 40, color: const Color(0xFF34F087)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ],
    ),
  );
}
