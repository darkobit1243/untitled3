import 'package:flutter/material.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.content,
    required this.isMe,
    required this.createdAt,
  });

  final String content;
  final bool isMe;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMe ? theme.colorScheme.primary : theme.colorScheme.surface;
    final textColor = isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final borderColor = isMe ? Colors.transparent : theme.dividerColor.withValues(alpha: 0.35);
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    return Column(
      crossAxisAlignment: align,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isMe ? 0.08 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatTime(createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isMe
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.75)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
