import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The title gets the full available width; secondary text sits underneath.
class ChatHeaderDetails extends StatelessWidget {
  const ChatHeaderDetails({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isChannel = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isChannel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                safeText(title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textHeading,
                  height: 1.3,
                ),
              ),
              if (subtitle?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        safeText(subtitle!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTokens.gray500,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (isChannel && onTap != null)
                      Icon(Icons.chevron_right,
                          size: 16, color: AppTokens.gray400),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showGroupIntroduction(
  BuildContext context, {
  required String name,
  required String description,
}) {
  final l = AppL10n.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (context) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: Text(l.channelDescriptionLabel,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: l.actionClose,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: 8),
              SelectableText(safeText(name),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(safeText(description),
                    style: const TextStyle(fontSize: 14, height: 1.6)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
