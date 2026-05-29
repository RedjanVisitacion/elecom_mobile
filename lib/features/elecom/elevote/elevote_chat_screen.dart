import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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
  final List<_EleVoteMessage> _messages = <_EleVoteMessage>[];
  bool _loadingHistory = true;
  bool _sending = false;
  bool _suggestionsOpen = false;

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
    _loadHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await _api.getEleVoteHistory();
      final raw = res['messages'];
      final loaded = raw is List
          ? raw
                .whereType<Map>()
                .map((item) {
                  return _EleVoteMessage(
                    role: (item['role'] ?? '').toString() == 'assistant'
                        ? _EleVoteRole.assistant
                        : _EleVoteRole.user,
                    text: (item['content'] ?? '').toString(),
                  );
                })
                .where((item) => item.text.trim().isNotEmpty)
                .toList()
          : <_EleVoteMessage>[];
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
        _loadingHistory = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _send([String? directMessage]) async {
    final text = (directMessage ?? _messageController.text).trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();
    setState(() {
      _suggestionsOpen = false;
      _sending = true;
      _messages.add(_EleVoteMessage(role: _EleVoteRole.user, text: text));
    });
    _scrollToBottom();

    try {
      final res = await _api.sendEleVoteMessage(text);
      final reply = (res['reply'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _messages.add(
          _EleVoteMessage(
            role: _EleVoteRole.assistant,
            text: reply.isEmpty
                ? 'I could not prepare an answer right now. Please try again.'
                : reply,
          ),
        );
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
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
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'EleVote Ai Assistant',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Suggestions',
            onPressed: () =>
                setState(() => _suggestionsOpen = !_suggestionsOpen),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  )
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                    children: [
                      const _AssistantIntro(),
                      for (final message in _messages)
                        _ChatBubble(message: message),
                      if (_sending) const _TypingBubble(),
                    ],
                  ),
          ),
          _SuggestionPanel(
            open: _suggestionsOpen,
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
              child: Padding(
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

enum _EleVoteRole { user, assistant }

class _EleVoteMessage {
  const _EleVoteMessage({required this.role, required this.text});

  final _EleVoteRole role;
  final String text;
}
