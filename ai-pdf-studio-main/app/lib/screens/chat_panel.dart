import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({required this.state, super.key, this.fullPage = false, this.onCitationPage});

  final AppState state;
  final bool fullPage;
  final ValueChanged<int>? onCitationPage;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _ChatHeader(state: state),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.chatMessages.length + (state.streamingResponse.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.chatMessages.length) {
                return _Message(
                  message: ChatMessage(text: state.streamingResponse, isUser: false),
                  onCitationPage: onCitationPage,
                );
              }
              final message = state.chatMessages[index];
              return _Message(message: message, onCitationPage: onCitationPage);
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
          AppIconButton(icon: Icons.history, tooltip: 'Conversation history', onPressed: () => _history(context)),
          AppIconButton(icon: Icons.add, tooltip: 'New conversation', onPressed: state.newConversation),
          AppIconButton(icon: Icons.delete_sweep_outlined, tooltip: 'Clear conversation', onPressed: state.clearChat),
          AppIconButton(icon: Icons.tune_rounded, tooltip: 'AI settings', onPressed: () {}),
          AppIconButton(icon: Icons.close, tooltip: 'Close assistant', onPressed: state.toggleChat),
        ],
      ),
    );
  }

  void _history(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Conversation history')),
            ...state.conversations.map(
              (conversation) => ListTile(
                title: Text(conversation.title),
                subtitle: Text(conversation.documentPath.split(RegExp(r'[/\\]')).last),
                onTap: () {
                  state.openConversation(conversation);
                  Navigator.pop(context);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    state.deleteConversation(conversation.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.onCitationPage});

  final ChatMessage message;
  final ValueChanged<int>? onCitationPage;

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
            if (!isUser && message.text.contains(r'$$'))
              Math.tex(message.text.replaceAll(r'$$', ''), textStyle: const TextStyle(fontSize: 14))
            else if (!isUser)
              MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(p: const TextStyle(fontSize: 13, height: 1.45)),
                onTapLink: (_, __, ___) {},
              )
            else
              Text(message.text, style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white)),
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.citations.map((citation) => ActionChip(
                  avatar: const Icon(Icons.link, size: 13),
                  label: Text('Page ${citation.pageNumber}'),
                  onPressed: () => onCitationPage?.call(citation.pageNumber),
                )).toList(),
              ),
            ],
            if (!isUser) Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: const Icon(Icons.copy, size: 15), tooltip: 'Copy', onPressed: () => Clipboard.setData(ClipboardData(text: message.text))),
              ],
            ),
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
    Future<void> send() async {
      if (!state.hasConsentForSelectedDocument()) {
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Allow document sharing?'),
            content: Text('Your selected document will be sent to ${state.provider} to answer this question.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Allow')),
            ],
          ),
        );
        if (approved != true) return;
        state.grantConsentForSelectedDocument();
      }
      await state.sendMessage();
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          if (state.indexingJobId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(value: state.indexingProgress),
            ),
          TextField(
            controller: state.chatController,
            minLines: 1,
            maxLines: 4,
            onSubmitted: (_) => send(),
            decoration: InputDecoration(
              hintText: 'Ask about this document…',
              suffixIcon: state.isProcessing
                  ? IconButton(onPressed: state.stopChat, icon: const Icon(Icons.stop_circle_outlined))
                  : IconButton(onPressed: send, icon: const Icon(Icons.arrow_upward_rounded)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lock_outline, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              state.apiKey.isEmpty ? 'Add a provider key in Settings' : 'Only this document · ${state.provider}',
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ]),
        ],
      ),
    );
  }
}
