import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/session/elevote_preferences.dart';
import '../../../core/utils/toast_service.dart';
import '../data/elecom_mobile_api.dart';

class EleVoteChatScreen extends StatefulWidget {
  const EleVoteChatScreen({super.key});

  @override
  State<EleVoteChatScreen> createState() => _EleVoteChatScreenState();
}

class _EleVoteChatScreenState extends State<EleVoteChatScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<_EleVoteMessage> _messages = <_EleVoteMessage>[];
  bool _loadingHistory = true;
  bool _sending = false;
  bool _clearingChat = false;
  bool _suggestionsOpen = false;

  // ── Polling ──────────────────────────────────────────────────────────────
  Timer? _pollTimer;
  bool _showScrollDown = false;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final nearBottom = pos.maxScrollExtent - pos.pixels < 120;
    final shouldShow = !nearBottom;
    if (_showScrollDown != shouldShow) {
      setState(() => _showScrollDown = shouldShow);
    }
  }

  bool _polling = false;       // true while a poll request is in-flight
  bool _isLive = false;        // drives the live indicator dot
  int _lastMessageId = 0;      // highest message id we have seen
  bool _takeover = false;      // true when admin has suppressed EleVote AI
  static const _pollInterval = Duration(seconds: 3);

  static const List<String> _suggestions = [
    'What is ELECOM?',
    'How do I vote?',
    'Can I change my vote after submitting?',
    'How can I view my receipt?',
    'When will election results be announced?',
    'Why can I only vote for USG and SITE candidates?',
    'What should I do if face verification fails?',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus && _suggestionsOpen) {
        setState(() => _suggestionsOpen = false);
      }
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await _api.getEleVoteHistory();
      final raw = res['messages'];
      final loaded = _parseMessages(raw);
      if (!mounted) return;
      final maxId = _maxId(loaded);
      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
        // If server returned real ids, use them. Otherwise use a sentinel
        // large enough that since_id=N returns nothing on first poll.
        _lastMessageId = maxId > 0 ? maxId : 0;
        _loadingHistory = false;
      });
      _scrollToBottom(force: true, jump: true);
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
      _startPolling();
    }
  }

  // ── Polling helpers ──────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Converts raw API message list into typed _EleVoteMessage objects,
  /// preserving the server-assigned id and mapping role="admin" correctly.
  List<_EleVoteMessage> _parseMessages(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final roleStr = (item['role'] ?? '').toString();
          final idVal = item['id'];
          final id = idVal is int ? idVal : int.tryParse(idVal.toString()) ?? 0;
          _EleVoteRole role;
          switch (roleStr) {
            case 'assistant':
              role = _EleVoteRole.assistant;
            case 'admin':
              role = _EleVoteRole.admin;
            default:
              role = _EleVoteRole.user;
          }
          final senderPhotoUrl =
              (item['sender_photo_url'] ?? '').toString().trim();
          final senderName =
              (item['sender_name'] ?? '').toString().trim();
          return _EleVoteMessage(
            id: id,
            role: role,
            text: (item['content'] ?? '').toString(),
            senderPhotoUrl: senderPhotoUrl.isNotEmpty ? senderPhotoUrl : null,
            senderName: senderName.isNotEmpty ? senderName : null,
          );
        })
        .where((m) => m.text.trim().isNotEmpty)
        .toList();
  }

  int _maxId(List<_EleVoteMessage> messages) =>
      messages.fold(0, (max, m) => m.id > max ? m.id : max);

  /// Incremental poll: only fetches messages newer than the last known id.
  /// Skips if a send is in-flight, another poll is running, or widget gone.
  Future<void> _poll() async {
    if (_polling || _sending || !mounted) return;
    _polling = true;
    try {
      final res = await _api.getEleVoteHistorySince(_lastMessageId);
      if (!mounted) return;

      // Update takeover state whenever the server tells us
      final serverTakeover = res['takeover_active'];
      if (serverTakeover is bool && serverTakeover != _takeover) {
        setState(() => _takeover = serverTakeover);
      }

      final incoming = _parseMessages(res['messages']);
      if (incoming.isEmpty) return;

      // De-duplicate: only keep messages with an id strictly greater than
      // the highest id we already have. This prevents re-adding messages
      // that were returned by the full history load (id=0 or already present).
      final existingIds = _messages.map((m) => m.id).toSet();
      final newMessages = incoming
          .where((m) => m.id > 0 && !existingIds.contains(m.id))
          .toList();

      if (newMessages.isEmpty) return;

      final hasAdminMsg =
          newMessages.any((m) => m.role == _EleVoteRole.admin);
      final newMax = _maxId(newMessages);

      setState(() {
        _messages.addAll(newMessages);
        if (newMax > _lastMessageId) _lastMessageId = newMax;
        _isLive = true;
      });

      if (hasAdminMsg) _scrollToBottom();

      // Dim the live dot after 2s — use a one-shot timer, not setState loop
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isLive) setState(() => _isLive = false);
      });
    } catch (_) {
      // silently ignore poll failures
    } finally {
      _polling = false;
    }
  }

  Future<void> _send([String? directMessage]) async {
    final text = (directMessage ?? _messageController.text).trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();

    // Add optimistic bubble with a temp marker id of -1
    // so the de-dupe filter (id > 0) ignores it during polls.
    setState(() {
      _suggestionsOpen = false;
      _sending = true;
      _messages.add(_EleVoteMessage(id: -1, role: _EleVoteRole.user, text: text));
    });
    _scrollToBottom(force: true);

    try {
      final res = await _api.sendEleVoteMessage(text);
      if (!mounted) return;

      // Replace the optimistic bubble with the real server-saved message.
      // This gives it the correct server id so future polls de-dupe correctly.
      final msgRaw = res['message'];
      int userMsgId = 0;
      String? serverText;
      if (msgRaw is Map) {
        final idVal = msgRaw['id'];
        userMsgId = idVal is int ? idVal : int.tryParse(idVal.toString()) ?? 0;
        serverText = (msgRaw['content'] ?? '').toString().trim();
      }

      // Find and replace the optimistic bubble (-1) with the real one.
      final optimisticIdx = _messages.indexWhere((m) => m.id == -1);

      final takeoverActive = res['takeover_active'] == true;

      setState(() {
        if (optimisticIdx >= 0) {
          _messages[optimisticIdx] = _EleVoteMessage(
            id: userMsgId,
            role: _EleVoteRole.user,
            text: serverText?.isNotEmpty == true ? serverText! : text,
          );
        }
        if (userMsgId > _lastMessageId) _lastMessageId = userMsgId;
        _takeover = takeoverActive;
        _sending = false;
      });

      // When admin has taken over, no AI reply — poll picks it up.
      if (takeoverActive) {
        _scrollToBottom(force: true);
        return;
      }

      // Normal AI reply path
      final assistantRaw = res['assistant_message'];
      String reply;
      int assistantId = 0;
      if (assistantRaw is Map) {
        reply = (assistantRaw['content'] ?? '').toString().trim();
        final idVal = assistantRaw['id'];
        assistantId =
            idVal is int ? idVal : int.tryParse(idVal.toString()) ?? 0;
      } else {
        reply = (res['reply'] ?? '').toString().trim();
      }

      setState(() {
        _messages.add(
          _EleVoteMessage(
            id: assistantId,
            role: _EleVoteRole.assistant,
            text: reply.isEmpty
                ? 'I could not prepare an answer right now. Please try again.'
                : reply,
          ),
        );
        if (assistantId > _lastMessageId) _lastMessageId = assistantId;
      });
      _scrollToBottom(force: true);
    } catch (e) {
      if (!mounted) return;
      // Remove the failed optimistic bubble and show error
      setState(() {
        _messages.removeWhere((m) => m.id == -1);
        _messages.add(
          const _EleVoteMessage(
            role: _EleVoteRole.assistant,
            text:
                'I cannot reach EleVote AI right now. Please check your connection or try again later.',
          ),
        );
        _sending = false;
      });
      AppToast.error(context, 'EleVote AI is unavailable.');
      _scrollToBottom(force: true);
    }
  }

  void _scrollToBottom({bool force = false, bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final nearBottom = pos.maxScrollExtent - pos.pixels < 120;
      if (!force && !nearBottom) return;
      if (jump) {
        _scrollController.jumpTo(pos.maxScrollExtent);
      } else {
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _clearChat(BuildContext sheetContext) async {
    if (_clearingChat) return;
    Navigator.of(sheetContext).pop();
    setState(() => _clearingChat = true);
    _stopPolling();
    try {
      await _api.clearEleVoteHistory();
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _suggestionsOpen = false;
        _clearingChat = false;
      });
      AppToast.success(context, 'EleVote chat cleared.');
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _clearingChat = false);
      _startPolling();
      final message = e is ElecomApiException
          ? e.message
          : 'Could not clear chat from the database.';
      AppToast.error(context, message);
    }
  }

  Future<void> _showEleVoteMenu() async {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            bottom: safeBottom + 10,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EleVoteMenuItem(
                      icon: Icons.delete_outline_rounded,
                      iconColor: Color(0xFFEF4444),
                      label: 'Clear chat',
                      onTap: () => _clearChat(ctx),
                    ),
                    _EleVoteMenuItem(
                      icon: Icons.settings_outlined,
                      iconColor: Color(0xFF64748B),
                      label: 'Settings',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const EleVoteSettingsScreen(
                                      returnToPreviousChat: true,
                                    ),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'EleVote Ai Assistant',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: _isLive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'EleVote options',
            onPressed: _showEleVoteMenu,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _loadingHistory
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF2563EB)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                        itemCount:
                            _messages.length + 1 + (_sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == 0) return const _AssistantIntro();
                          if (_sending && index == _messages.length + 1) {
                            return const _TypingBubble();
                          }
                          return _ChatBubble(
                              message: _messages[index - 1]);
                        },
                      ),
                // ── Scroll-to-bottom FAB (Messenger-style) ──────────────
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  bottom: _showScrollDown ? 12 : -56,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _scrollToBottom(force: true),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SuggestionPanel(
            open: _suggestionsOpen && !keyboardOpen,
            suggestions: _suggestions,
            onToggle: () =>
                setState(() => _suggestionsOpen = !_suggestionsOpen),
            onSelect: _send,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: FilledButton(
                    onPressed: _sending ? null : () => _send(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantIntro extends StatelessWidget {
  const _AssistantIntro();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _EleVoteAvatar(size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, right: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              "Hello! I'm EleVote Ai Assistant.\nTap a suggestion below or type your own message. Here's what I can help with:\n\n"
              '• How to vote\n'
              '• Ballot and candidate questions\n'
              '• Receipt and results guidance\n'
              '• Face verification help\n'
              '• ELECOM app support',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.open,
    required this.suggestions,
    required this.onToggle,
    required this.onSelect,
  });

  final bool open;
  final List<String> suggestions;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final maxOpenHeight = MediaQuery.sizeOf(context).height * 0.32;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    size: 17,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Suggested questions',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              heightFactor: open ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxOpenHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    children: [
                      for (final suggestion in suggestions)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ActionChip(
                              label: Text(suggestion),
                              labelStyle: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              onPressed: () => onSelect(suggestion),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _EleVoteMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _EleVoteRole.user;
    final isAdmin = message.role == _EleVoteRole.admin;

    // Admin messages look like assistant bubbles but with a teal/admin tint
    // and a small "Admin" label so the student knows it's a human reply.
    if (isAdmin) {
      final photoUrl = message.senderPhotoUrl;
      final name = message.senderName ?? 'Admin';

      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Admin avatar — real photo if available, fallback icon otherwise
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                  : const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomLeft: const Radius.circular(4),
                    ),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          const _EleVoteAvatar(size: 28),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: isUser ? null : Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _EleVoteAvatar(size: 28),
        SizedBox(width: 8),
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'EleVote is typing...',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _EleVoteMenuItem extends StatelessWidget {
  const _EleVoteMenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 28,
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }
}

class EleVoteSettingsScreen extends StatefulWidget {
  const EleVoteSettingsScreen({super.key, this.returnToPreviousChat = false});

  final bool returnToPreviousChat;

  @override
  State<EleVoteSettingsScreen> createState() => _EleVoteSettingsScreenState();
}

class _EleVoteSettingsScreenState extends State<EleVoteSettingsScreen> {
  bool _enabled = EleVotePreferences.enabledNotifier.value;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await EleVotePreferences.load();
    if (!mounted) return;
    setState(() => _enabled = EleVotePreferences.enabledNotifier.value);
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await EleVotePreferences.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'EleVote Ai Assistant',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                _EleVoteAvatar(size: 48),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'EleVote helps you ask questions about the ELECOM app, voting steps, receipts, results, face verification, and ELECOM support.',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                if (widget.returnToPreviousChat) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const EleVoteChatScreen()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text(
                'Open EleVote',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: SwitchListTile(
              value: _enabled,
              activeThumbColor: const Color(0xFF2563EB),
              contentPadding: EdgeInsets.zero,
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              title: const Text(
                'Enable EleVote',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              onChanged: _setEnabled,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'When EleVote is disabled, the floating assistant button will be hidden from the Home screen.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EleVoteAvatar extends StatelessWidget {
  const _EleVoteAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/Robot-Bot 3D.json',
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.smart_toy_outlined,
          color: const Color(0xFF2563EB),
          size: size * 0.78,
        ),
      ),
    );
  }
}

enum _EleVoteRole { user, assistant, admin }

class _EleVoteMessage {
  const _EleVoteMessage({
    required this.role,
    required this.text,
    this.id = 0,
    this.senderPhotoUrl,
    this.senderName,
  });

  final _EleVoteRole role;
  final String text;
  final int id;
  final String? senderPhotoUrl;
  final String? senderName;
}
