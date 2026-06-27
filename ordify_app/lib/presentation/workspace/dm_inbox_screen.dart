import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'orders_screen.dart';

class DMInboxScreen extends StatefulWidget {
  const DMInboxScreen({super.key});

  @override
  State<DMInboxScreen> createState() => _DMInboxScreenState();
}

class _DMInboxScreenState extends State<DMInboxScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _connectedInstagram;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await apiClient.get('/instagram/dms');
      final data = Map<String, dynamic>.from(response.data as Map);

      final rawConversations = data['conversations'];

      List<Map<String, dynamic>> conversations = [];

      if (rawConversations is List) {
        conversations = rawConversations
            .where((item) => item is Map)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _connectedInstagram = _toMap(data['connected_instagram']);
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  int _unreadCount(Map<String, dynamic> conversation) {
    final value = conversation['unread_count'];

    if (value is int) return value;

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06130F),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadConversations,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              if (_isLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const _DMLoadingCard(),
                    childCount: 6,
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (_conversations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final conversation = _conversations[index];

                      return _buildConversationCard(conversation);
                    },
                    childCount: _conversations.length,
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final username = _text(
      _connectedInstagram?['username'],
      fallback: 'Instagram',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Instagram DMs',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _RoundIconButton(
                icon: Icons.refresh_rounded,
                onTap: _loadConversations,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0B2A1E),
                  Color(0xFF103E2C),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF39FF88).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.mark_chat_unread_rounded,
                    color: Color(0xFF39FF88),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$username',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Convert Instagram conversations into OrdiFy orders.',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.4,
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
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final threadId = _text(conversation['id'], fallback: 'Unknown thread');
    final customerName = _text(
      conversation['preview_sender_username'],
      fallback: 'Instagram Customer',
    );
    final previewMessage = _text(
      conversation['preview_message'],
      fallback: 'No message preview available',
    );
    final updatedTime = _text(
      conversation['updated_time'],
      fallback: 'Recently active',
    );
    final unread = _unreadCount(conversation);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DMThreadScreen(
                threadId: threadId,
                previewCustomerName: customerName,
                connectedInstagram: _connectedInstagram,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1C16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF39FF88).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF39FF88),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      previewMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      updatedTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF39FF88),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        unread.toString(),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF06130F),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'DM',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 86,
            width: 86,
            decoration: BoxDecoration(
              color: const Color(0xFF39FF88).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: Color(0xFF39FF88),
              size: 42,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'No DM conversations yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Instagram is connected, but Meta is not returning readable DM threads right now. When conversations become available, they will appear here automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _loadConversations,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh DMs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF39FF88),
              foregroundColor: const Color(0xFF06130F),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 52,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load Instagram DMs',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _loadConversations,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF39FF88),
              foregroundColor: const Color(0xFF06130F),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DMThreadScreen extends StatefulWidget {
  const DMThreadScreen({
    super.key,
    required this.threadId,
    required this.previewCustomerName,
    required this.connectedInstagram,
  });

  final String threadId;
  final String previewCustomerName;
  final Map<String, dynamic>? connectedInstagram;

  @override
  State<DMThreadScreen> createState() => _DMThreadScreenState();
}

class _DMThreadScreenState extends State<DMThreadScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _connectedInstagram;
  Map<String, dynamic>? _linkedOrder;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  Future<void> _loadThread() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await apiClient.get('/instagram/dms/${widget.threadId}/messages');
      final data = Map<String, dynamic>.from(response.data as Map);

      final rawMessages = data['messages'];

      List<Map<String, dynamic>> messages = [];

      if (rawMessages is List) {
        messages = rawMessages
            .where((item) => item is Map)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _connectedInstagram = _toMap(data['connected_instagram']) ?? widget.connectedInstagram;
        _linkedOrder = _toMap(data['linked_order']);
        _messages = messages;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  Map<String, dynamic> _senderFromMessage(Map<String, dynamic> message) {
    final sender = message['from'];

    if (sender is Map) {
      return Map<String, dynamic>.from(sender);
    }

    return {};
  }

  bool _isSellerMessage(Map<String, dynamic> message) {
    final sender = _senderFromMessage(message);

    final senderId = _text(sender['id']);
    final senderUsername = _text(sender['username']);
    final senderName = _text(sender['name']);

    final businessId = _text(_connectedInstagram?['user_id']);
    final businessUsername = _text(_connectedInstagram?['username']);

    if (senderId.isNotEmpty && businessId.isNotEmpty && senderId == businessId) {
      return true;
    }

    if (senderUsername.isNotEmpty &&
        businessUsername.isNotEmpty &&
        senderUsername == businessUsername) {
      return true;
    }

    if (senderName.isNotEmpty &&
        businessUsername.isNotEmpty &&
        senderName == businessUsername) {
      return true;
    }

    return false;
  }

  String _guessCustomerUsername() {
    final businessId = _text(_connectedInstagram?['user_id']);
    final businessUsername = _text(_connectedInstagram?['username']);

    for (final message in _messages) {
      final sender = _senderFromMessage(message);

      final senderId = _text(sender['id']);
      final senderUsername = _text(sender['username']);
      final senderName = _text(sender['name']);

      final isBusinessById = senderId.isNotEmpty && businessId.isNotEmpty && senderId == businessId;
      final isBusinessByUsername = senderUsername.isNotEmpty &&
          businessUsername.isNotEmpty &&
          senderUsername == businessUsername;
      final isBusinessByName = senderName.isNotEmpty &&
          businessUsername.isNotEmpty &&
          senderName == businessUsername;

      if (!isBusinessById && !isBusinessByUsername && !isBusinessByName) {
        if (senderUsername.isNotEmpty) return senderUsername.replaceAll('@', '');
        if (senderName.isNotEmpty) return senderName.replaceAll('@', '');
      }
    }

    if (widget.previewCustomerName.trim().isNotEmpty &&
        widget.previewCustomerName != 'Instagram Customer') {
      return widget.previewCustomerName.replaceAll('@', '');
    }

    return 'instagram_customer';
  }

  String _guessCustomerDisplayName() {
    for (final message in _messages) {
      final sender = _senderFromMessage(message);
      final senderName = _text(sender['name']);
      final senderUsername = _text(sender['username']);

      if (senderName.isNotEmpty) return senderName;
      if (senderUsername.isNotEmpty) return senderUsername;
    }

    return widget.previewCustomerName;
  }

  List<String> _messageIds() {
    return _messages
        .map((message) => _text(message['id']))
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<void> _openConvertSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ConvertDMToOrderSheet(
          threadId: widget.threadId,
          messageIds: _messageIds(),
          guessedInstagramUsername: _guessCustomerUsername(),
          guessedDisplayName: _guessCustomerDisplayName(),
        );
      },
    );

    if (created == true) {
      await _loadThread();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DM converted to order successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openLinkedOrder() async {
    final orderId = _text(_linkedOrder?['id']);

    if (orderId.isEmpty) return;

    try {
      final response = await apiClient.get('/orders/$orderId');
      final data = response.data;

      Map<String, dynamic> order = {};

      if (data is Map) {
        final map = Map<String, dynamic>.from(data);

        if (map['order'] is Map) {
          order = Map<String, dynamic>.from(map['order'] as Map);
        } else {
          order = map;
        }
      }

      if (!mounted) return;

      if (order.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Linked order details not found'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(order: order),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open linked order: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerTitle = _guessCustomerUsername();

    return Scaffold(
      backgroundColor: const Color(0xFF06130F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(customerTitle),
            if (_linkedOrder != null) _buildLinkedOrderChip(),
            Expanded(
              child: _buildBody(),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String customerTitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$customerTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'DM Thread • ${widget.threadId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _RoundIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadThread,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedOrderChip() {
    final orderNumber = _text(
      _linkedOrder?['order_number'],
      fallback: 'Linked Order',
    );
    final status = _text(
      _linkedOrder?['status'],
      fallback: 'active',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openLinkedOrder,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF39FF88).withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF39FF88).withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.link_rounded,
                color: Color(0xFF39FF88),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$orderNumber linked • $status',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF39FF88),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF39FF88),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        itemCount: 7,
        itemBuilder: (context, index) {
          return const _MessageLoadingBubble();
        },
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 46,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load messages',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF39FF88),
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                'No messages found',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This thread is available, but Meta did not return messages for it yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayMessages = _messages.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      itemCount: displayMessages.length,
      itemBuilder: (context, index) {
        final message = displayMessages[index];
        final isSeller = _isSellerMessage(message);

        return _buildMessageBubble(message, isSeller);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isSeller) {
    final text = _text(
      message['message'],
      fallback: '[Attachment or unsupported message]',
    );
    final createdTime = _text(message['created_time']);

    return Align(
      alignment: isSeller ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSeller ? const Color(0xFF39FF88) : const Color(0xFF0B1C16),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isSeller ? 18 : 4),
            bottomRight: Radius.circular(isSeller ? 4 : 18),
          ),
          border: isSeller ? null : Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: GoogleFonts.poppins(
                color: isSeller ? const Color(0xFF06130F) : Colors.white,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (createdTime.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                createdTime,
                style: GoogleFonts.poppins(
                  color: isSeller ? const Color(0xFF06130F).withOpacity(0.65) : Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF06130F),
        border: Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openConvertSheet,
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Convert DM to Order'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF39FF88),
            foregroundColor: const Color(0xFF06130F),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class ConvertDMToOrderSheet extends StatefulWidget {
  const ConvertDMToOrderSheet({
    super.key,
    required this.threadId,
    required this.messageIds,
    required this.guessedInstagramUsername,
    required this.guessedDisplayName,
  });

  final String threadId;
  final List<String> messageIds;
  final String guessedInstagramUsername;
  final String guessedDisplayName;

  @override
  State<ConvertDMToOrderSheet> createState() => _ConvertDMToOrderSheetState();
}

class _ConvertDMToOrderSheetState extends State<ConvertDMToOrderSheet> {
  final TextEditingController _instagramUsernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customVariantController = TextEditingController();

  bool _isLoadingProducts = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _products = [];
  final List<_DMOrderItem> _items = [
    _DMOrderItem(),
  ];

  @override
  void initState() {
    super.initState();

    _instagramUsernameController.text = widget.guessedInstagramUsername;
    _displayNameController.text = widget.guessedDisplayName;
    _notesController.text = 'Order created from Instagram DM';

    _loadProducts();
  }

  @override
  void dispose() {
    _instagramUsernameController.dispose();
    _displayNameController.dispose();
    _notesController.dispose();
    _customVariantController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _errorMessage = null;
    });

    try {
      final response = await apiClient.get('/products?page=1&limit=50');
      final data = Map<String, dynamic>.from(response.data as Map);

      final rawProducts = data['products'];

      List<Map<String, dynamic>> products = [];

      if (rawProducts is List) {
        products = rawProducts
            .where((item) => item is Map)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoadingProducts = false;
      });
    }
  }

  String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  int _intValue(dynamic value) {
    if (value is int) return value;

    if (value is double) return value.toInt();

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  double _doubleValue(dynamic value) {
    if (value is double) return value;

    if (value is int) return value.toDouble();

    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  Map<String, dynamic>? _productById(String? productId) {
    if (productId == null) return null;

    for (final product in _products) {
      if (_text(product['id']) == productId) {
        return product;
      }
    }

    return null;
  }

  double _orderTotal() {
    double total = 0;

    for (final item in _items) {
      final product = _productById(item.productId);

      if (product == null) continue;

      final price = _doubleValue(product['price']);

      total += price * item.quantity;
    }

    return total;
  }

  String? _validateForm() {
    final username = _instagramUsernameController.text.trim();

    if (username.isEmpty) {
      return 'Instagram username is required';
    }

    if (_items.isEmpty) {
      return 'Add at least one product';
    }

    for (final item in _items) {
      if (item.productId == null || item.productId!.isEmpty) {
        return 'Select product for every item';
      }

      final product = _productById(item.productId);
      final stock = _intValue(product?['stock_count']);

      if (stock <= 0) {
        return '${_text(product?['name'], fallback: 'Selected product')} is out of stock';
      }

      if (item.quantity <= 0) {
        return 'Quantity must be at least 1';
      }

      if (item.quantity > stock) {
        return 'Only $stock stock available for ${_text(product?['name'], fallback: 'selected product')}';
      }
    }

    return null;
  }

  Future<void> _submitOrder() async {
    final validationError = _validateForm();

    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });

      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final itemsPayload = _items.map((item) {
        return {
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_price': null,
          'variant_notes': item.variantNotesController.text.trim().isEmpty
              ? null
              : item.variantNotesController.text.trim(),
        };
      }).toList();

      final payload = {
        'thread_id': widget.threadId,
        'message_ids': widget.messageIds,
        'instagram_username': _instagramUsernameController.text.trim().replaceAll('@', ''),
        'display_name': _displayNameController.text.trim().isEmpty
            ? _instagramUsernameController.text.trim().replaceAll('@', '')
            : _displayNameController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'custom_variant': _customVariantController.text.trim().isEmpty
            ? null
            : _customVariantController.text.trim(),
        'items': itemsPayload,
      };

      await apiClient.post(
        '/instagram/orders/from-dm',
        data: payload,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF06130F),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Convert DM to Order',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingProducts
                  ? const _ConvertSheetLoading()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomerSection(),
                          const SizedBox(height: 18),
                          _buildProductSection(),
                          const SizedBox(height: 18),
                          _buildNotesSection(),
                          const SizedBox(height: 18),
                          _buildTotalBox(),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorBox(),
                          ],
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
            ),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return _SheetCard(
      title: 'Customer',
      icon: Icons.person_rounded,
      child: Column(
        children: [
          _DarkTextField(
            controller: _instagramUsernameController,
            label: 'Instagram username',
            hint: 'example_customer',
            prefixText: '@',
          ),
          const SizedBox(height: 12),
          _DarkTextField(
            controller: _displayNameController,
            label: 'Display name',
            hint: 'Customer name',
          ),
        ],
      ),
    );
  }

  Widget _buildProductSection() {
    return _SheetCard(
      title: 'Products',
      icon: Icons.inventory_2_rounded,
      child: Column(
        children: [
          for (int index = 0; index < _items.length; index++)
            _buildProductItem(index),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _items.add(_DMOrderItem());
              });
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add another product'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF39FF88),
              side: const BorderSide(color: Color(0xFF39FF88)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(int index) {
    final item = _items[index];
    final selectedProduct = _productById(item.productId);

    final stock = _intValue(selectedProduct?['stock_count']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.productId,
                  dropdownColor: const Color(0xFF0B1C16),
                  decoration: _inputDecoration('Select product'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  items: _products.map((product) {
                    final productId = _text(product['id']);
                    final name = _text(product['name'], fallback: 'Product');
                    final price = _doubleValue(product['price']);
                    final productStock = _intValue(product['stock_count']);
                    final inStock = productStock > 0;

                    return DropdownMenuItem<String>(
                      value: productId,
                      enabled: inStock,
                      child: Opacity(
                        opacity: inStock ? 1 : 0.45,
                        child: Text(
                          '$name • ₹${price.toStringAsFixed(2)} • Stock $productStock',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      item.productId = value;
                    });
                  },
                ),
              ),
              if (_items.length > 1) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      item.dispose();
                      _items.removeAt(index);
                    });
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuantityStepper(
                  quantity: item.quantity,
                  maxQuantity: stock <= 0 ? 1 : stock,
                  onChanged: (value) {
                    setState(() {
                      item.quantity = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedProduct == null
                      ? 'Choose product'
                      : 'Line total ₹${(_doubleValue(selectedProduct['price']) * item.quantity).toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DarkTextField(
            controller: item.variantNotesController,
            label: 'Item note',
            hint: 'Size, color, DM note',
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _SheetCard(
      title: 'Order Notes',
      icon: Icons.notes_rounded,
      child: Column(
        children: [
          _DarkTextField(
            controller: _notesController,
            label: 'Notes',
            hint: 'Order note',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _DarkTextField(
            controller: _customVariantController,
            label: 'Custom variant',
            hint: 'Optional custom variant',
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF39FF88).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF39FF88).withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Text(
            'Order Total',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '₹${_orderTotal().toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              color: const Color(0xFF39FF88),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Text(
        _errorMessage ?? '',
        style: GoogleFonts.poppins(
          color: Colors.redAccent,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF06130F),
        border: Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitOrder,
          icon: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF06130F),
                  ),
                )
              : const Icon(Icons.check_circle_rounded),
          label: Text(_isSubmitting ? 'Creating Order...' : 'Create Order from DM'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF39FF88),
            foregroundColor: const Color(0xFF06130F),
            disabledBackgroundColor: Colors.white24,
            disabledForegroundColor: Colors.white54,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        color: Colors.white54,
        fontSize: 12,
      ),
      filled: true,
      fillColor: const Color(0xFF07130F),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF39FF88)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _DMOrderItem {
  String? productId;
  int quantity = 1;
  final TextEditingController variantNotesController = TextEditingController();

  void dispose() {
    variantNotesController.dispose();
  }
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1C16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF39FF88),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixText,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? prefixText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 13,
        ),
        labelStyle: GoogleFonts.poppins(
          color: Colors.white54,
          fontSize: 12,
        ),
        hintStyle: GoogleFonts.poppins(
          color: Colors.white30,
          fontSize: 12,
        ),
        filled: true,
        fillColor: const Color(0xFF07130F),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF39FF88)),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.maxQuantity,
    required this.onChanged,
  });

  final int quantity;
  final int maxQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF07130F),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: quantity <= 1
                ? null
                : () {
                    onChanged(quantity - 1);
                  },
            icon: const Icon(
              Icons.remove_rounded,
              color: Colors.white70,
            ),
          ),
          Expanded(
            child: Text(
              quantity.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: quantity >= maxQuantity
                ? null
                : () {
                    onChanged(quantity + 1);
                  },
            icon: const Icon(
              Icons.add_rounded,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(
          icon,
          color: Colors.white70,
          size: 21,
        ),
      ),
    );
  }
}

class _DMLoadingCard extends StatelessWidget {
  const _DMLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1C16),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            _SkeletonBox(height: 52, width: 52, radius: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SkeletonBox(height: 13, width: 150, radius: 8),
                  SizedBox(height: 10),
                  _SkeletonBox(height: 11, width: double.infinity, radius: 8),
                  SizedBox(height: 8),
                  _SkeletonBox(height: 11, width: 190, radius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageLoadingBubble extends StatelessWidget {
  const _MessageLoadingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: const _SkeletonBox(
          height: 58,
          width: 230,
          radius: 18,
        ),
      ),
    );
  }
}

class _ConvertSheetLoading extends StatelessWidget {
  const _ConvertSheetLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: const [
        _SkeletonBox(height: 120, width: double.infinity, radius: 22),
        SizedBox(height: 16),
        _SkeletonBox(height: 170, width: double.infinity, radius: 22),
        SizedBox(height: 16),
        _SkeletonBox(height: 110, width: double.infinity, radius: 22),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.width,
    required this.radius,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}