import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({required this.state, super.key, this.fullPage = false});

  final AppState state;
  final bool fullPage;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _ChatHeader(state: state),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.chatMessages.length + (state.isProcessing ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.chatMessages.length) {
                return const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Align(alignment: Alignment.centerLeft, child: _TypingIndicator()),
                );
              }
              final message = state.chatMessages[index];
              return _Message(message: message);
            },
          ),
        ),
        _ChatComposer(state: state),
      ],
    );
    if (fullPage) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: SurfaceCard(child: content),
      );
    }
    return Container(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Theme.of(context).dividerColor))),
      child: content,
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 18, 12, 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.14), borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.auto_awesome, size: 17, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 9),
          const Expanded(child: Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.w700))),
          AppIconButton(icon: Icons.tune_rounded, tooltip: 'AI settings', onPressed: () {}),
          AppIconButton(icon: Icons.close, tooltip: 'Close assistant', onPressed: state.toggleChat),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 275),
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12).copyWith(bottomRight: isUser ? Radius.zero : null, bottomLeft: isUser ? null : Radius.zero),
          border: isUser ? null : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(fontSize: 13, height: 1.45, color: isUser ? Colors.white : null)),
            if (message.citation != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.link, size: 13, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(message.citation!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
      child: const Text('Thinking…', style: TextStyle(fontSize: 12)),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: state.chatController,
            minLines: 1,
            maxLines: 4,
            onSubmitted: (_) => state.sendMessage(),
            decoration: InputDecoration(
              hintText: 'Ask about this document…',
              suffixIcon: IconButton(onPressed: state.sendMessage, icon: const Icon(Icons.arrow_upward_rounded)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lock_outline, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text('Only this document · OpenAI', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ],
      ),
    );
  }
}
