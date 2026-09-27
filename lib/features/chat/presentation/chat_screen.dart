import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../domain/models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).refreshChat();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await AppScope.of(context).addMessage(text);
      controller.clear();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke sende melding: $error')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _edit(ChatMessage message) async {
    final edit = TextEditingController(text: message.text);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rediger melding'),
        content: TextField(controller: edit, autofocus: true, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, edit.text.trim()), child: const Text('Lagre')),
        ],
      ),
    );
    edit.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    try {
      await AppScope.of(context).editMessage(message, value);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Redigering feilet: $error')));
    }
  }

  Future<void> _delete(ChatMessage message) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slett melding?'),
        content: const Text('Meldingen markeres som slettet for alle i chatten.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Slett')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await AppScope.of(context).deleteMessage(message);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sletting feilet: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tur-chat'),
        actions: [IconButton(onPressed: state.chatLoading ? null : state.refreshChat, icon: const Icon(Icons.refresh))],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (state.chatLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: state.messages.isEmpty && !state.chatLoading
                  ? const Center(child: Text('Ingen meldinger ennå.', style: TextStyle(color: GoViaColors.muted)))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[state.messages.length - 1 - index];
                        return _MessageBubble(
                          message: message,
                          onLike: () async {
                            try {
                              await state.toggleMessageLike(message);
                            } catch (error) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reaksjon feilet: $error')));
                            }
                          },
                          onEdit: message.mine && !message.deleted ? () => _edit(message) : null,
                          onDelete: message.mine && !message.deleted ? () => _delete(message) : null,
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: GoViaColors.panel, border: Border(top: BorderSide(color: GoViaColors.border))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !sending,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(hintText: 'Melding…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: sending ? null : _send, icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onLike, this.onEdit, this.onDelete});

  final ChatMessage message;
  final VoidCallback onLike;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Align(
        alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(13, 10, 8, 7),
          decoration: BoxDecoration(
            color: message.mine ? GoViaColors.orange.withValues(alpha: .17) : GoViaColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: message.mine ? GoViaColors.orange.withValues(alpha: .45) : GoViaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.sender,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: message.mine ? GoViaColors.orange : GoViaColors.cyan),
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 160),
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null) const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rediger'), dense: true, contentPadding: EdgeInsets.zero)),
                        if (onDelete != null) const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Slett'), dense: true, contentPadding: EdgeInsets.zero)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(message.deleted ? 'Meldingen er slettet' : message.text, style: TextStyle(fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal, color: message.deleted ? GoViaColors.muted : null)),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.editedAt != null && !message.deleted) const Text('redigert · ', style: TextStyle(fontSize: 11, color: GoViaColors.muted)),
                  Text(_time(message.sentAt), style: const TextStyle(fontSize: 11, color: GoViaColors.muted)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: message.deleted ? null : onLike,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          Icon(message.likedByMe ? Icons.favorite : Icons.favorite_border, size: 17, color: message.likedByMe ? GoViaColors.orange : GoViaColors.muted),
                          if (message.likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text('${message.likeCount}', style: const TextStyle(fontSize: 11, color: GoViaColors.muted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
