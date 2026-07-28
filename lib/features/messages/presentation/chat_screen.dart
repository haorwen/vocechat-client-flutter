import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/contacts/application/presence_provider.dart';
import '../../../features/contacts/application/user_directory_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/loading_capsule.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../../shared/widgets/voce_context_menu.dart';
import '../../../shared/widgets/voce_dialog.dart';
import '../application/chat_controller.dart';
import '../application/chat_tools_provider.dart';
import '../application/read_index_provider.dart';
import '../data/message_api.dart';
import '../domain/message_models.dart';
import '../domain/message_status.dart';
import 'archive_message_content.dart';
import 'chat_tool_panels.dart';
import 'file_display_utils.dart';
import 'file_message_content.dart';
import 'forward_sheet.dart';
import 'mention_overlay.dart';
import 'mention_text.dart';
import 'reaction_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String id;
  const ChatScreen({super.key, required this.id});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _editCtrl = TextEditingController();
  final _searchAnchorKey = GlobalKey();
  final _sendBoxKey = GlobalKey();

  /// Uids accumulated for the in-progress compose session via the "@" picker
  /// (group chats only — mentions are disabled in DMs, matching web's
  /// `enableMention: members.length > 0`). Sent as `properties.mentions` and
  /// reset after each send.
  final List<int> _pendingMentions = [];

  /// Index into `_textCtrl.text` of the "@" that triggered the currently-open
  /// mention overlay, or null when no overlay is showing.
  int? _mentionTriggerIndex;
  MentionOverlayHandle? _mentionOverlay;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _canSend = false;

  /// True while a native file-picker dialog is in flight — guards
  /// [_pickAndStageFile] against a second concurrent invocation.
  bool _pickingFile = false;

  /// Explicit markdown mode toggled via the composer's Markdown icon —
  /// forces the next send's content-type instead of relying on heuristics.
  /// Resets to off after each send (web parity: per-message, not sticky).
  bool _markdownMode = false;
  int? _highlightMid;
  Timer? _highlightTimer;

  /// Debounce for read-index reporting: scrolling fires position changes
  /// continuously, so we coalesce and only POST the newest seen mid ~500ms
  /// after the user settles (web parity).
  Timer? _readDebounce;
  int _lastReportedReadMid = 0;
  int? _editingMid;
  int? _replyToMid;
  ChatMessage? _replyTarget;

  /// Files staged for sending — shown as preview cards above the input. Pick
  /// and paste add here; the actual upload+send fires only on send (web parity
  /// with the `UploadFileList` staging area). Supports any file type.
  final List<_StagedFile> _staged = [];

  /// True while a native file drag hovers over the chat surface — drives the
  /// dashed-border drop overlay (web parity with `DnDTip`).
  bool _dragActive = false;

  /// Multi-select mode (web parity with `updateSelectMessages` + the
  /// `Operations` bar): null when inactive; a (possibly empty) set of selected
  /// mids while active. Entered via the "Select" context-menu action, exited
  /// via the bar's close button or after a bulk action completes.
  Set<int>? _selectedMids;

  late MessageTarget _target;

  /// Send is enabled when there's text OR at least one staged image.
  void _recomputeCanSend() {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    final next = hasText || _staged.isNotEmpty;
    if (next != _canSend) setState(() => _canSend = next);
  }

  @override
  void initState() {
    super.initState();
    _target = _parseTarget(widget.id);

    _textCtrl.addListener(_recomputeCanSend);

    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      setState(() {
        _target = _parseTarget(widget.id);
        _selectedMids = null;
      });
      // New conversation: reset the read-report guard so its first visible
      // message gets marked read.
      _readDebounce?.cancel();
      _lastReportedReadMid = 0;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _editCtrl.dispose();
    _highlightTimer?.cancel();
    _readDebounce?.cancel();
    _mentionOverlay?.remove();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    super.dispose();
  }

  /// Detects "@" typed in the composer (group chats only) and drives the
  /// mention-overlay lifecycle: opens it when "@" is typed at a word
  /// boundary, updates its filter as the user keeps typing, and closes it
  /// once the query is interrupted by whitespace or the "@" is deleted.
  void _onComposerChanged(String text) {
    final gid = _target.maybeMap<int?>(group: (t) => t.gid, orElse: () => null);
    if (gid == null) return;

    final caret = _textCtrl.selection.baseOffset;
    if (caret < 0) {
      _closeMentionOverlay();
      return;
    }

    final triggerIndex = _mentionTriggerIndex;
    if (triggerIndex == null) {
      // Look for a fresh "@" immediately before the caret, at a word
      // boundary (start of string or preceded by whitespace).
      if (caret == 0 || text[caret - 1] != '@') return;
      final before = caret - 1;
      if (before > 0 && text[before - 1] != ' ' && text[before - 1] != '\n') {
        return;
      }
      _mentionTriggerIndex = before;
      _mentionOverlay = showMentionOverlay(
        context,
        anchorKey: _sendBoxKey,
        gid: gid,
        onSelect: _insertMention,
      );
      return;
    }

    // Overlay already open: keep it in sync with the text typed after "@".
    if (triggerIndex >= text.length || text[triggerIndex] != '@' ||
        caret <= triggerIndex) {
      _closeMentionOverlay();
      return;
    }
    final query = text.substring(triggerIndex + 1, caret);
    if (query.contains(' ') || query.contains('\n')) {
      _closeMentionOverlay();
      return;
    }
    _mentionOverlay?.updateQuery(query);
  }

  void _closeMentionOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
    _mentionTriggerIndex = null;
  }

  /// Replaces the partial "@query" typed so far with the literal " @{uid} "
  /// token (web wire format) and records [uid] for the outgoing
  /// `properties.mentions` array.
  void _insertMention(int uid, String name) {
    final triggerIndex = _mentionTriggerIndex;
    _mentionTriggerIndex = null;
    _mentionOverlay = null;
    if (triggerIndex == null) return;

    final text = _textCtrl.text;
    final caret = _textCtrl.selection.baseOffset;
    final end = caret < 0 || caret < triggerIndex ? text.length : caret;
    final token = ' @$uid ';
    final newText = text.replaceRange(triggerIndex, end, token);
    _textCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: triggerIndex + token.length),
    );
    _pendingMentions.add(uid);
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    // List is reverse: index 0 is the newest. The "older" end of the visible
    // window is the max trailing edge — when it's within 5 items of the
    // bottom of the dataset, fetch older history.
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    if (messages.isEmpty) return;
    final maxIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);
    if (maxIndex >= messages.length - 5) {
      ref.read(chatControllerProvider(_target).notifier).loadMore();
    }

    // Mark-read: the newest visible message is at the minimum visible index
    // (reverse list, index 0 == newest). Report it up to the server, debounced.
    final minIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a < b ? a : b);
    if (minIndex >= 0 && minIndex < messages.length) {
      final newestVisibleMid = messages[minIndex].mid;
      if (newestVisibleMid > _lastReportedReadMid) {
        _scheduleReadReport(newestVisibleMid);
      }
    }
  }

  /// Debounced read-index report. Updates the local marker optimistically and
  /// POSTs to the server. Only ever advances; placeholder/negative mids are
  /// ignored.
  void _scheduleReadReport(int mid) {
    if (mid <= 0) return;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || mid <= _lastReportedReadMid) return;
      _lastReportedReadMid = mid;

      final notifier = ref.read(readIndexProvider.notifier);
      final api = ref.read(messageApiProvider);
      _target.map(
        user: (t) {
          notifier.setUser(t.uid, mid);
          // Fire-and-forget; the server only moves markers forward.
          api.readMessage(users: [(uid: t.uid, mid: mid)]).catchError((_) {});
        },
        group: (t) {
          notifier.setGroup(t.gid, mid);
          api.readMessage(groups: [(gid: t.gid, mid: mid)]).catchError((_) {});
        },
      );
    });
  }

  static MessageTarget _parseTarget(String id) {
    if (id.startsWith('u-')) {
      final uid = int.tryParse(id.substring(2)) ?? 0;
      return MessageTarget.user(uid: uid);
    } else if (id.startsWith('g-')) {
      final gid = int.tryParse(id.substring(2)) ?? 0;
      return MessageTarget.group(gid: gid);
    }
    final gid = int.tryParse(id) ?? 0;
    return MessageTarget.group(gid: gid);
  }

  Future<void> _sendMessage() async {
    if (!_canSend) return;
    final text = _textCtrl.text.trim();
    final l = AppL10n.of(context);
    final replyMid = _replyToMid;
    final markdown = _markdownMode;
    // Snapshot + clear the staging area; uploads fire below (web parity:
    // staged files only upload on send, then the stage resets).
    final staged = List<_StagedFile>.from(_staged);
    final mentions = List<int>.from(_pendingMentions);
    _textCtrl.clear();
    _closeMentionOverlay();
    setState(() {
      _canSend = false;
      _replyToMid = null;
      _replyTarget = null;
      _staged.clear();
      _pendingMentions.clear();
      _markdownMode = false;
    });
    try {
      final notifier = ref.read(chatControllerProvider(_target).notifier);
      // 1) Text first (only when non-empty — images can be sent caption-less).
      if (text.isNotEmpty) {
        if (replyMid != null) {
          await notifier.sendReply(replyMid, text,
              mentions: mentions, markdown: markdown);
        } else {
          await notifier.sendText(text, mentions: mentions, markdown: markdown);
        }
      }
      // 2) Then each staged image (each becomes its own optimistic row).
      for (final img in staged) {
        await notifier.sendImage(
          bytes: img.bytes,
          filename: img.filename,
          contentType: img.contentType,
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = replyMid != null
            ? l.chatReplyFailed(_friendlyError(e, l))
            : l.chatSendFailed(_friendlyError(e, l));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(msg))));
      }
    }
  }

  /// Add a file to the staging area (preview above input). Upload is
  /// deferred until the user taps send — matches the web `addStageFile` flow.
  void _stageFile(Uint8List bytes, String filename) {
    final contentType = MessageApi.inferContentType(filename, bytes: bytes);
    setState(() {
      _staged.add(_StagedFile(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      ));
    });
    _recomputeCanSend();
  }

  void _removeStaged(int index) {
    if (index < 0 || index >= _staged.length) return;
    setState(() => _staged.removeAt(index));
    _recomputeCanSend();
  }

  /// Rename a staged file in place (web parity with the edit-name dialog).
  void _renameStaged(int index, String newName) {
    if (index < 0 || index >= _staged.length) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    setState(() => _staged[index].filename = trimmed);
  }

  /// Show the rename dialog for a staged file (web parity with
  /// `EditFileDetailsModal`). Pre-fills the current name; on save, applies it.
  Future<void> _showRenameDialog(int index) async {
    if (index < 0 || index >= _staged.length) return;
    final l = AppL10n.of(context);
    final ctrl = TextEditingController(text: _staged[index].filename);
    ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.chatFileDetailsTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l.chatFileNameLabel),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text(l.chatEditSave),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) _renameStaged(index, result);
  }

  /// Pick one or more files (any type) via file_picker on every platform and
  /// STAGE them for preview. Reads bytes in-memory so the clipboard + picker
  /// paths share one staging entry point.
  ///
  /// Guarded by [_pickingFile]: a second tap while the native picker dialog
  /// is still open would otherwise race a concurrent `pickFiles` call, which
  /// file_picker surfaces as a `PlatformException(already_active)` on some
  /// platforms — from the user's perspective the button just "does nothing".
  Future<void> _pickAndStageFile() async {
    if (_pickingFile) return;
    setState(() => _pickingFile = true);
    final l = AppL10n.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: true,
      );
      if (result == null) return;
      for (final picked in result.files) {
        final bytes = picked.bytes ??
            (picked.path != null
                ? await File(picked.path!).readAsBytes()
                : null);
        if (bytes == null || bytes.isEmpty) continue;
        _stageFile(bytes, picked.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(safeText(l.chatSendFailed(_friendlyError(e, l))))));
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  /// Open the voice-recording sheet; on confirm, upload the recorded clip
  /// through the same `sendImage` pipeline used for staged files (reusing
  /// the existing optimistic-row + upload machinery rather than adding a
  /// parallel send path).
  Future<void> _recordVoiceMessage() async {
    final l = AppL10n.of(context);
    final bytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _VoiceRecordSheet(),
    );
    if (bytes == null || bytes.isEmpty || !mounted) return;
    try {
      final notifier = ref.read(chatControllerProvider(_target).notifier);
      await notifier.sendImage(
        bytes: bytes,
        filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        contentType: 'audio/mp4',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(safeText(l.chatSendFailed(_friendlyError(e, l))))));
      }
    }
  }

  /// Open the full-screen camera capture screen; on confirm, upload the
  /// recorded clip through the same `sendImage` pipeline as staged files.
  /// Mobile-only (gated in `_SendBox`) — the `camera` plugin's desktop
  /// support is not solid enough for this repo's Windows-first workflow.
  Future<void> _recordVideoMessage() async {
    final l = AppL10n.of(context);
    final bytes = await Navigator.of(context, rootNavigator: true).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _VideoCaptureScreen(),
      ),
    );
    if (bytes == null || bytes.isEmpty || !mounted) return;
    try {
      final notifier = ref.read(chatControllerProvider(_target).notifier);
      await notifier.sendImage(
        bytes: bytes,
        filename: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        contentType: 'video/mp4',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(safeText(l.chatSendFailed(_friendlyError(e, l))))));
      }
    }
  }

  /// Stage files dropped onto the chat surface via native drag-and-drop.
  /// Reuses the same staging entry point as the picker/clipboard paths, so
  /// dropped files flow through the existing preview + upload-on-send logic.
  Future<void> _stageDroppedFiles(List<XFile> files) async {
    final l = AppL10n.of(context);
    try {
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        final name = file.name.isNotEmpty
            ? file.name
            : (file.path.split(RegExp(r'[\\/]')).lastOrNull ?? 'file');
        _stageFile(bytes, name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(safeText(l.chatSendFailed(_friendlyError(e, l))))));
      }
    }
  }

  /// Try to read from the clipboard and STAGE whatever it holds. Handles both
  /// raw image bytes (screenshots etc.) and real files copied from the OS file
  /// manager (PDF/doc/any type). Returns true when something was staged so the
  /// caller can suppress the default text paste.
  Future<bool> _pasteFromClipboard() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return false;
      final reader = await clipboard.read();

      // Fast path: raw image bytes on the clipboard (no filename available).
      Uint8List? bytes;
      String filename = 'pasted.png';
      if (reader.canProvide(Formats.png)) {
        bytes = await _readClipboardFormat(reader, Formats.png);
        filename = 'pasted.png';
      } else if (reader.canProvide(Formats.jpeg)) {
        bytes = await _readClipboardFormat(reader, Formats.jpeg);
        filename = 'pasted.jpg';
      } else if (reader.canProvide(Formats.gif)) {
        bytes = await _readClipboardFormat(reader, Formats.gif);
        filename = 'pasted.gif';
      } else if (reader.canProvide(Formats.webp)) {
        bytes = await _readClipboardFormat(reader, Formats.webp);
        filename = 'pasted.webp';
      }
      if (bytes != null && bytes.isNotEmpty) {
        _stageFile(bytes, filename);
        return true;
      }

      // General path: a real file (any type) was copied in the OS file
      // manager. Each item is its own reader; getFile(null) synthesizes the
      // file from its URI on desktop, giving us bytes + a suggested name.
      var staged = false;
      for (final item in reader.items) {
        // getFile(null) will happily synthesize a "file" out of plain text or
        // HTML on the clipboard. Only treat the item as a file when it carries
        // a real file URI; otherwise let the default text paste handle it.
        final isTextOnly = !item.canProvide(Formats.fileUri) &&
            (item.canProvide(Formats.plainText) ||
                item.canProvide(Formats.htmlText));
        if (isTextOnly) continue;
        final result = await _readFileFromReader(item);
        if (result != null && result.$1.isNotEmpty) {
          _stageFile(result.$1, result.$2);
          staged = true;
        }
      }
      return staged;
    } catch (_) {
      return false;
    }
  }

  /// Read a single binary image format from the clipboard into bytes.
  Future<Uint8List?> _readClipboardFormat(
    ClipboardReader reader,
    SimpleFileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();
    reader.getFile(format, (file) async {
      try {
        final data = await file.readAll();
        if (!completer.isCompleted) completer.complete(data);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    }, onError: (_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    return completer.future;
  }

  void _startReply(ChatMessage msg) {
    setState(() {
      _replyToMid = msg.mid;
      _replyTarget = msg;
      _editingMid = null;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMid = null;
      _replyTarget = null;
    });
  }

  void _startEdit(ChatMessage msg) {
    final text = msg.displayContent;
    _editCtrl.text = text;
    // Place the caret at the end so editing picks up where the message left
    // off; default selection of a freshly-assigned value is offset 0.
    _editCtrl.selection =
        TextSelection.collapsed(offset: _editCtrl.text.length);
    setState(() {
      _editingMid = msg.mid;
      _replyToMid = null;
      _replyTarget = null;
    });
  }

  void _cancelEdit() {
    setState(() => _editingMid = null);
    _editCtrl.clear();
  }

  Future<void> _saveEdit() async {
    final mid = _editingMid;
    if (mid == null) return;
    final newText = _editCtrl.text.trim();
    if (newText.isEmpty) {
      _cancelEdit();
      return;
    }
    final l = AppL10n.of(context);
    // Preserve the original content-type rather than sniffing markdown from
    // the edited text (sniffing would silently upgrade "5 > 3" to markdown).
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    final original = messages.firstWhere(
      (m) => m.mid == mid,
      orElse: () => messages.first,
    );
    final isMarkdown = original.displayContentType == 'text/markdown';
    try {
      await ref
          .read(chatControllerProvider(_target).notifier)
          .editText(mid, newText, markdown: isMarkdown);
      if (mounted) setState(() => _editingMid = null);
      _editCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(safeText(l.chatEditFailed(_friendlyError(e, l))))));
      }
    }
  }

  Future<void> _confirmDelete(ChatMessage msg) async {
    final l = AppL10n.of(context);
    final ok = await showVoceConfirm(
      context: context,
      title: l.chatDeleteConfirmTitle,
      body: l.chatDeleteConfirmBody,
      confirmLabel: l.chatActionDelete,
      cancelLabel: l.actionCancel,
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(chatControllerProvider(_target).notifier)
          .deleteMessage(msg.mid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(safeText(l.chatDeleteFailed(_friendlyError(e, l))))));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Multi-select mode (web `Operations.tsx` parity): enter via the context
  // menu's "Select" action, toggle rows by tapping/checkbox, then forward /
  // save / delete the batch from the operations bar that replaces the composer.
  // -------------------------------------------------------------------------

  void _enterSelectMode(int mid) {
    setState(() => _selectedMids = {if (mid > 0) mid});
  }

  void _exitSelectMode() {
    setState(() => _selectedMids = null);
  }

  void _toggleSelected(int mid) {
    final selected = _selectedMids;
    if (selected == null || mid <= 0) return;
    setState(() {
      if (!selected.remove(mid)) selected.add(mid);
    });
  }

  /// Selected mids in chat order (oldest first) so the forwarded archive and
  /// bulk operations preserve reading order — the set itself is insertion-
  /// ordered by tap sequence, which is not what the receiver should see.
  List<int> _selectedMidsInOrder() {
    final selected = _selectedMids ?? const <int>{};
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    return [
      for (final m in messages.reversed)
        if (selected.contains(m.mid)) m.mid,
    ];
  }

  Future<void> _forwardSelected() async {
    final mids = _selectedMidsInOrder();
    if (mids.isEmpty) return;
    final sent = await showForwardSheet(context, mids: mids);
    if (sent == true && mounted) _exitSelectMode();
  }

  Future<void> _favoriteSelected() async {
    final l = AppL10n.of(context);
    final mids = _selectedMidsInOrder();
    if (mids.isEmpty) return;
    final ok = await ref.read(favoritesProvider.notifier).add(mids);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l.chatToolSavedAdded : l.chatToolSaveFail),
    ));
    if (ok) _exitSelectMode();
  }

  Future<void> _deleteSelected() async {
    final l = AppL10n.of(context);
    final mids = _selectedMidsInOrder();
    if (mids.isEmpty) return;
    final ok = await showVoceConfirm(
      context: context,
      title: l.chatDeleteConfirmTitle,
      body: l.chatDeleteConfirmBody,
      confirmLabel: l.chatActionDelete,
      cancelLabel: l.actionCancel,
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      final notifier = ref.read(chatControllerProvider(_target).notifier);
      for (final mid in mids) {
        await notifier.deleteMessage(mid);
      }
      if (!mounted) return;
      _exitSelectMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(safeText(l.chatDeleteFailed(_friendlyError(e, l))))));
      }
    }
  }

  /// Extract a short user-safe error message from a thrown error. `Dio` and
  /// the redacting interceptor scrub headers from logs, but `.toString()` on a
  /// `DioException` still contains the request URL, status line, and raw
  /// response body — too verbose for a snackbar, and a leak risk if
  /// screenshots get shared.
  static String _friendlyError(Object e, AppL10n l) {
    if (e is DioException) {
      final inner = e.error;
      if (inner is ApiException) return inner.message;
      return e.message ?? l.errorRequestFailed;
    }
    return l.errorRequestFailed;
  }

  bool _showDateSeparator(List<ChatMessage> msgs, int index) {
    if (index == msgs.length - 1) return true;
    final current = msgs[index];
    final older = msgs[index + 1];
    final currentDate =
        DateTime.fromMillisecondsSinceEpoch(current.createdAt, isUtc: true);
    final olderDate =
        DateTime.fromMillisecondsSinceEpoch(older.createdAt, isUtc: true);
    return currentDate.day != olderDate.day;
  }

  String? _avatarUrl(int uid, int? avatarUpdatedAt) {
    if ((avatarUpdatedAt ?? 0) == 0) return null;
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    final server = serverState?.servers
        .where((s) => s.id == serverState.currentServerId)
        .firstOrNull;
    final base = server?.baseUrl ?? '';
    if (base.isEmpty) return null;
    return '$base/api/resource/avatar?uid=$uid';
  }

  String? _groupAvatarUrl(int gid, int? avatarUpdatedAt) {
    if ((avatarUpdatedAt ?? 0) == 0) return null;
    final serverState = ref.read(serverStoreProvider).valueOrNull;
    final server = serverState?.servers
        .where((s) => s.id == serverState.currentServerId)
        .firstOrNull;
    final base = server?.baseUrl ?? '';
    if (base.isEmpty) return null;
    return '$base/api/resource/group_avatar?gid=$gid';
  }

  Future<void> _openSearchOverlay() async {
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    await showSearchOverlay(
      context,
      anchorKey: _searchAnchorKey,
      messages: messages,
      userDir: ref.read(userDirectoryProvider).valueOrNull ?? const {},
      avatarUrlBuilder: _avatarUrl,
      onLocate: _scrollToMid,
    );
  }

  Future<void> _scrollToMid(int mid) async {
    final messages =
        ref.read(chatControllerProvider(_target)).valueOrNull ?? const [];
    final index = messages.indexWhere((m) => m.mid == mid);
    if (index < 0) return;
    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        // 0.0 puts the item flush with the leading edge — for a reverse list
        // that's the bottom; 0.3 nudges it a third of the way up.
        alignment: 0.3,
      );
    }
    if (!mounted) return;
    setState(() => _highlightMid = mid);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _highlightMid = null);
    });
  }

  void _showToolPanel(ChatTool tool) {
    final id = _target.map<int>(
      user: (t) => t.uid,
      group: (t) => t.gid,
    );
    final isChannel = _target.map<bool>(
      user: (_) => false,
      group: (_) => true,
    );
    showChatToolOverlay(
      context,
      tool: tool,
      targetId: id,
      isChannel: isChannel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final messagesAsync = ref.watch(chatControllerProvider(_target));

    final authState = ref.watch(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : -1;

    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? {};
    final groupDir = ref.watch(groupDirectoryProvider).valueOrNull ?? {};

    final showStatus = ref.watch(showOnlineStatusProvider);
    final presence = ref.watch(presenceProvider);
    final int? dmUid = _target.maybeMap<int?>(
      user: (t) => t.uid,
      orElse: () => null,
    );
    final dmOnline = dmUid != null && (presence[dmUid] ?? false);

    final (
      String title,
      String? subtitle,
      String? avatarUrl,
      bool isChannel
    ) = _target.map(
      user: (t) {
        final u = userDir[t.uid];
        final name = u?.name ?? l.chatUserFallback(t.uid);
        return (
          name,
          showStatus ? (dmOnline ? l.chatStatusOnline : l.chatStatusOffline) : null,
          u != null ? _avatarUrl(t.uid, u.avatarUpdatedAt) : null,
          false,
        );
      },
      group: (t) {
        final g = groupDir[t.gid];
        final name = g?.name ?? l.chatGroupFallback(t.gid);
        return (
          name,
          l.chatGroupIntro,
          g != null ? _groupAvatarUrl(t.gid, g.avatarUpdatedAt) : null,
          true,
        );
      },
    );

    final statuses =
        ref.watch(chatControllerProvider(_target).notifier).statuses;

    return Container(
      color: AppTokens.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DropTarget(
                  onDragEntered: (_) => setState(() => _dragActive = true),
                  onDragExited: (_) => setState(() => _dragActive = false),
                  onDragDone: (detail) {
                    setState(() => _dragActive = false);
                    _stageDroppedFiles(detail.files);
                  },
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _ChatHeader(
                            title: title,
                            subtitle: subtitle,
                            avatarUrl: avatarUrl,
                            isChannel: isChannel,
                            canPop: Navigator.of(context).canPop(),
                            isOnline: dmOnline,
                            showStatus: showStatus,
                            showMoreMenu: !isWide,
                            searchAnchorKey: _searchAnchorKey,
                            onSearch: _openSearchOverlay,
                            onPin: isChannel
                                ? () => _showToolPanel(ChatTool.pin)
                                : null,
                            onSaved: () => _showToolPanel(ChatTool.saved),
                            onMembers: isChannel
                                ? () => _showToolPanel(ChatTool.members)
                                : null,
                            onAutoDelete: () =>
                                _showToolPanel(ChatTool.autoDelete),
                          ),
                          Expanded(
                            child: messagesAsync.when(
                              loading: () => Center(
                                child: LoadingCapsule(
                                    label: l.chatLoadingMessages),
                              ),
                              error: (e, _) => Center(
                                  child: Text(
                                      safeText(l.errorPrefix(e.toString())))),
                              data: (messages) {
                                if (messages.isEmpty) {
                                  return const _EmptyConversation();
                                }
                                return ScrollablePositionedList.builder(
                                  itemScrollController: _itemScrollController,
                                  itemPositionsListener:
                                      _itemPositionsListener,
                                  reverse: true,
                                  padding: const EdgeInsets.fromLTRB(
                                      8, 16, 8, 16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = messages[index];
                                    final showSep =
                                        _showDateSeparator(messages, index);
                                    // reverse:true → Column children render
                                    // top→bottom visually above→below the row.
                                    // Date separator belongs ABOVE the day's
                                    // first message (oldest of that day), so it
                                    // must come BEFORE the row in the Column.
                                    return Column(
                                      key: ValueKey<int>(msg.mid),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (showSep)
                                          _DateSeparator(
                                              createdAt: msg.createdAt),
                                        _MessageRow(
                                          message: msg,
                                          currentUid: currentUid,
                                          status: statuses[msg.mid],
                                          userDir: userDir,
                                          avatarUrlBuilder: _avatarUrl,
                                          target: _target,
                                          highlighted:
                                              msg.mid == _highlightMid,
                                          isEditing: _editingMid == msg.mid,
                                          editController: _editCtrl,
                                          onEditSave: _saveEdit,
                                          onEditCancel: _cancelEdit,
                                          onReply: () => _startReply(msg),
                                          onEdit: () => _startEdit(msg),
                                          onDelete: () => _confirmDelete(msg),
                                          onJumpToMid: _scrollToMid,
                                          selecting: _selectedMids != null,
                                          selected: _selectedMids
                                                  ?.contains(msg.mid) ??
                                              false,
                                          onToggleSelect: () =>
                                              _toggleSelected(msg.mid),
                                          onEnterSelect: () =>
                                              _enterSelectMode(msg.mid),
                                          onRetry: msg.mid < 0 &&
                                                  statuses[msg.mid] ==
                                                      MessageSendStatus.failed
                                              ? () => ref
                                                  .read(chatControllerProvider(
                                                          _target)
                                                      .notifier)
                                                  .retrySend(msg.mid)
                                              : null,
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          if (_selectedMids != null)
                            _SelectionBar(
                              count: _selectedMids!.length,
                              onForward: _forwardSelected,
                              onFavorite: _favoriteSelected,
                              onDelete: _deleteSelected,
                              onClose: _exitSelectMode,
                            )
                          else
                            _SendBox(
                              controller: _textCtrl,
                              canSend: _canSend,
                              onSend: _sendMessage,
                              onAttach:
                                  _pickingFile ? null : _pickAndStageFile,
                              onPasteImage: _pasteFromClipboard,
                              staged: _staged,
                              onRemoveStaged: _removeStaged,
                              onRenameStaged: _showRenameDialog,
                              placeholder: isChannel
                                  ? l.chatMessagePlaceholderChannel(title)
                                  : l.chatMessagePlaceholderUser(title),
                              replyTarget: _replyTarget,
                              replyTargetName: _replyTarget == null
                                  ? null
                                  : (userDir[_replyTarget!.fromUid]?.name ??
                                      l.chatUserFallback(
                                          _replyTarget!.fromUid)),
                              onCancelReply: _cancelReply,
                              textFieldKey: _sendBoxKey,
                              onChanged: isChannel ? _onComposerChanged : null,
                              markdownActive: _markdownMode,
                              onToggleMarkdown: () => setState(
                                  () => _markdownMode = !_markdownMode),
                              onRecordVoice: _recordVoiceMessage,
                              onRecordVideo: _recordVideoMessage,
                            ),
                        ],
                      ),
                      if (_dragActive)
                        Positioned.fill(
                          child: _DropOverlay(targetName: title),
                        ),
                    ],
                  ),
                ),
              ),
              if (isWide)
                _ChatSideRail(
                  isChannel: isChannel,
                  onPin: isChannel
                      ? () => _showToolPanel(ChatTool.pin)
                      : null,
                  onSaved: () => _showToolPanel(ChatTool.saved),
                  onMembers: isChannel
                      ? () => _showToolPanel(ChatTool.members)
                      : null,
                  onAutoDelete: () => _showToolPanel(ChatTool.autoDelete),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DropOverlay — shown over the chat surface while a native file drag hovers
// (web parity with `DnDTip`). Semi-transparent scrim + centered dashed-border
// card naming the drop target.
// ---------------------------------------------------------------------------

class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.targetName});

  final String targetName;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    // IgnorePointer: the overlay is purely visual — the underlying DropTarget
    // must keep receiving the native drag/drop events.
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: DottedBorderBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    size: 48, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  safeText(l.chatDropOverlayTitle(targetName)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.chatDropOverlayHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle drawn with a dashed white border — the dashed look the
/// web `DnDTip` uses. Implemented with a custom painter to avoid pulling in a
/// dotted-border dependency for one widget.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  static const double _radius = 16;
  static const double _dash = 8;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// _ChatHeader — channel/dm header (Figma "Main / Header"). 52px tall, white
// background, bottom border #EAECF0, Inter Bold 16 title + Inter 16 subtitle.
// ---------------------------------------------------------------------------

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.isChannel,
    required this.canPop,
    this.isOnline = false,
    this.showStatus = true,
    this.showMoreMenu = false,
    this.searchAnchorKey,
    this.onSearch,
    this.onPin,
    this.onSaved,
    this.onMembers,
    this.onAutoDelete,
  });

  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final bool isChannel;
  final bool canPop;
  final bool isOnline;
  final bool showStatus;
  final bool showMoreMenu;
  final Key? searchAnchorKey;
  final VoidCallback? onSearch;
  final VoidCallback? onPin;
  final VoidCallback? onSaved;
  final VoidCallback? onMembers;
  final VoidCallback? onAutoDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border(
          bottom: BorderSide(color: AppTokens.gray200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: AppL10n.of(context).actionBack,
              icon: Icon(Icons.arrow_back,
                  size: 20, color: AppTokens.gray700),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          if (isChannel)
            Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.tag,
                  size: 20, color: AppTokens.textHeading),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  VoceAvatar(
                      name: title, imageUrl: avatarUrl, size: 28),
                  if (showStatus)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? AppTokens.successDot
                              : AppTokens.gray400,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTokens.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    safeText(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.textHeading,
                      height: 24 / 16,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      safeText(subtitle!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTokens.gray500,
                        height: 24 / 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: searchAnchorKey,
            icon: Icon(Icons.search,
                size: 20, color: AppTokens.gray500),
            onPressed: onSearch,
            tooltip: l.actionSearch,
          ),
          if (showMoreMenu)
            PopupMenuButton<ChatTool>(
              icon: Icon(Icons.more_horiz,
                  size: 20, color: AppTokens.gray500),
              tooltip: l.actionMore,
              onSelected: (tool) {
                switch (tool) {
                  case ChatTool.pin:
                    onPin?.call();
                  case ChatTool.saved:
                    onSaved?.call();
                  case ChatTool.members:
                    onMembers?.call();
                  case ChatTool.autoDelete:
                    onAutoDelete?.call();
                }
              },
              itemBuilder: (context) => [
                if (isChannel)
                  PopupMenuItem(
                    value: ChatTool.pin,
                    child: _ChatToolMenuRow(
                      icon: Icons.push_pin_outlined,
                      label: l.chatToolPin,
                    ),
                  ),
                PopupMenuItem(
                  value: ChatTool.saved,
                  child: _ChatToolMenuRow(
                    icon: Icons.bookmark_outline,
                    label: l.chatToolSaved,
                  ),
                ),
                if (isChannel)
                  PopupMenuItem(
                    value: ChatTool.members,
                    child: _ChatToolMenuRow(
                      icon: Icons.people_outline,
                      label: l.chatToolMembers,
                    ),
                  ),
                PopupMenuItem(
                  value: ChatTool.autoDelete,
                  child: _ChatToolMenuRow(
                    icon: Icons.timer_outlined,
                    label: l.chatAutoDeleteTitle,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChatToolMenuRow extends StatelessWidget {
  const _ChatToolMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTokens.gray500),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                fontSize: 14, color: AppTokens.gray700)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ChatSideRail — Figma/Web "aside" column. A 56px-wide vertical rail to the
// right of the chat surface, surfacing Pin (channels only), Saved, and
// Members (channels only). On narrow screens these collapse into the header's
// "more" overflow menu.
// ---------------------------------------------------------------------------

class _ChatSideRail extends StatelessWidget {
  const _ChatSideRail({
    required this.isChannel,
    this.onPin,
    this.onSaved,
    this.onMembers,
    this.onAutoDelete,
  });

  final bool isChannel;
  final VoidCallback? onPin;
  final VoidCallback? onSaved;
  final VoidCallback? onMembers;
  final VoidCallback? onAutoDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border(
          left: BorderSide(color: AppTokens.gray200, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (isChannel) ...[
            _RailButton(
              icon: Icons.push_pin_outlined,
              tooltip: l.chatToolPin,
              onPressed: onPin ?? () {},
            ),
            const SizedBox(height: 12),
          ],
          _RailButton(
            icon: Icons.bookmark_outline,
            tooltip: l.chatToolSaved,
            onPressed: onSaved ?? () {},
          ),
          if (isChannel) ...[
            const SizedBox(height: 12),
            _RailButton(
              icon: Icons.people_outline,
              tooltip: l.chatToolMembers,
              onPressed: onMembers ?? () {},
            ),
          ],
          const SizedBox(height: 12),
          _RailButton(
            icon: Icons.timer_outlined,
            tooltip: l.chatAutoDeleteTitle,
            onPressed: onAutoDelete ?? () {},
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: AppTokens.gray500),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DateSeparator — Figma "Timestamp": horizontal line with centered white
// pill carrying the date.
// ---------------------------------------------------------------------------

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.createdAt});
  final int createdAt;

  String _formatDate() {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true)
        .toLocal();
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 1,
            color: AppTokens.borderSubtle,
          ),
          Container(
            color: AppTokens.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              _formatDate(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTokens.gray500,
                height: 18 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MessageRow — Figma "Main / Comment". 40px avatar, cyan name + gray time
// header, body text in #374151. Hovering reveals a reply-actions cluster on
// the right of the row (Emoji / Reply / Bookmark / More).
// ---------------------------------------------------------------------------

/// Friendly label for a burn-after-read `expiresIn` (seconds) value, for the
/// message-row timer tooltip. Covers the real option set (0/300/600/3600/
/// 86400/604800, matching web's AutoDeleteMessages.tsx) plus a generic
/// fallback in case the server ever returns an arbitrary value.
String _formatExpiresIn(int seconds) {
  if (seconds >= 604800 && seconds % 604800 == 0) {
    final weeks = seconds ~/ 604800;
    return weeks == 1 ? '1 week' : '$weeks weeks';
  }
  if (seconds >= 86400 && seconds % 86400 == 0) {
    final days = seconds ~/ 86400;
    return days == 1 ? '1 day' : '$days days';
  }
  if (seconds >= 3600 && seconds % 3600 == 0) {
    final hours = seconds ~/ 3600;
    return hours == 1 ? '1 hour' : '$hours hours';
  }
  if (seconds >= 60 && seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }
  return '$seconds seconds';
}

class _MessageRow extends ConsumerStatefulWidget {
  const _MessageRow({
    required this.message,
    required this.currentUid,
    required this.userDir,
    required this.avatarUrlBuilder,
    required this.target,
    this.status,
    this.onRetry,
    this.highlighted = false,
    this.isEditing = false,
    this.editController,
    this.onEditSave,
    this.onEditCancel,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onJumpToMid,
    this.selecting = false,
    this.selected = false,
    this.onToggleSelect,
    this.onEnterSelect,
  });

  final ChatMessage message;
  final int currentUid;
  final MessageSendStatus? status;
  final Map<int, UserSummary> userDir;
  final String? Function(int uid, int? avatarUpdatedAt) avatarUrlBuilder;
  final MessageTarget target;
  final VoidCallback? onRetry;
  final bool highlighted;
  final bool isEditing;
  final TextEditingController? editController;
  final VoidCallback? onEditSave;
  final VoidCallback? onEditCancel;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(int mid)? onJumpToMid;

  /// Multi-select mode: while [selecting], rows render a leading checkbox and
  /// any tap toggles membership instead of opening menus/pickers.
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onEnterSelect;

  @override
  ConsumerState<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends ConsumerState<_MessageRow> {
  bool _hovered = false;
  final GlobalKey _toolbarKey = GlobalKey();

  bool get _isPinned {
    final p = (widget.message.detail is NormalMessageDetail)
        ? (widget.message.detail as NormalMessageDetail).properties
        : null;
    return p != null && (p['pinned'] == true || p['is_pinned'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final msg = widget.message;
    final sender = widget.userDir[msg.fromUid];
    final senderName = sender?.name ?? l.chatUserFallback(msg.fromUid);
    final senderAvatarUrl = sender != null
        ? widget.avatarUrlBuilder(msg.fromUid, sender.avatarUpdatedAt)
        : null;

    final date =
        DateTime.fromMillisecondsSinceEpoch(msg.createdAt, isUtc: true)
            .toLocal();
    final dateLabel =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    final detail = msg.detail;
    final displayContent = msg.displayContent;
    final displayContentType = msg.displayContentType;
    // Burn-after-read: server stamps `expires_in` (seconds) onto normal/reply
    // messages based on the sender's own auto-delete setting for this
    // target. Static icon + tooltip only — no countdown/auto-delete-on-expiry
    // (that's out of scope; see web's ExpireTimer.tsx for the fuller
    // behaviour this intentionally does not replicate).
    final expiresIn = switch (detail) {
      NormalMessageDetail() => detail.expiresIn,
      ReplyMessageDetail() => detail.expiresIn,
      _ => null,
    };
    Widget content;
    if (widget.isEditing && widget.editController != null) {
      content = _EditForm(
        controller: widget.editController!,
        onSave: widget.onEditSave ?? () {},
        onCancel: widget.onEditCancel ?? () {},
      );
    } else if (detail is NormalMessageDetail || msg.isEdited) {
      if (displayContentType == 'vocechat/file') {
        final props = detail is NormalMessageDetail ? detail.properties : null;
        final notifier =
            ref.read(chatControllerProvider(widget.target).notifier);
        final isSending = widget.status == MessageSendStatus.sending;
        // Only preview from local memory while the upload is in flight. Once
        // confirmed/failed the row falls back to the network-backed bubble so
        // a sent image looks and behaves exactly like a received one.
        final localBytes = isSending ? notifier.localBytesFor(msg.mid) : null;
        content = FileMessageContent(
          content: displayContent,
          properties: props,
          localBytes: localBytes,
          sending: isSending,
          progress: isSending ? notifier.progressFor(msg.mid) : null,
        );
      } else if (displayContentType == 'vocechat/archive') {
        content = ArchiveMessageContent(filePath: displayContent);
      } else if (displayContentType == 'text/markdown') {
        content = MarkdownBody(
          data: safeText(displayContent),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: 14,
              color: AppTokens.gray700,
              height: 20 / 14,
            ),
          ),
        );
      } else {
        content = MentionText(
          text: displayContent,
          userDir: widget.userDir,
          style: TextStyle(
            fontSize: 14,
            color: AppTokens.gray700,
            height: 20 / 14,
          ),
        );
      }
    } else if (detail is ReplyMessageDetail) {
      // Try to resolve the original message from the current chat list so we
      // can render a real preview ("↩ replying to <name>: <snippet>") instead
      // of a bare mid. Falls back to the mid alone if we don't have history.
      final chatMessages =
          ref.watch(chatControllerProvider(widget.target)).valueOrNull ??
              const <ChatMessage>[];
      final original = chatMessages
          .where((m) => m.mid == detail.mid)
          .firstOrNull;
      final originalAuthor = original != null
          ? widget.userDir[original.fromUid]
          : null;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quoted original — mirrors the web client's <Reply>: a w-fit
          // gray-100 rounded box with the original author's avatar, name in
          // the primary color, and the original content rendered by its real
          // content type (image thumbnail, [Voice Message], file, or text).
          // No left-accent border and no reply icon (web has neither).
          original == null || originalAuthor == null
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTokens.gray100,
                    borderRadius: BorderRadius.circular(8),
                    border: AppTokens.brightness == Brightness.dark
                        ? Border.all(color: AppTokens.borderSubtle, width: 1)
                        : null,
                  ),
                  child: Text(
                    l.chatReplyDeleted,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppTokens.gray500,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => widget.onJumpToMid?.call(detail.mid),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTokens.gray100,
                        borderRadius: BorderRadius.circular(8),
                        border: AppTokens.brightness == Brightness.dark
                            ? Border.all(
                                color: AppTokens.borderSubtle, width: 1)
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VoceAvatar(
                            name: originalAuthor.name,
                            imageUrl: widget.avatarUrlBuilder(
                              original.fromUid,
                              originalAuthor.avatarUpdatedAt,
                            ),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  safeText(originalAuthor.name),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTokens.primary500,
                                    height: 18 / 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                _ReplyQuotePreview(original: original),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 4),
          if (displayContentType == 'vocechat/file')
            FileMessageContent(
              content: displayContent,
              properties: detail.properties,
            )
          else if (displayContentType == 'vocechat/archive')
            ArchiveMessageContent(filePath: displayContent)
          else
            MentionText(
              text: displayContent,
              userDir: widget.userDir,
              style: TextStyle(
                fontSize: 14,
                color: AppTokens.gray700,
                height: 20 / 14,
              ),
            ),
        ],
      );
    } else {
      content = Text(
        l.chatUnsupported,
        style: TextStyle(fontSize: 13, color: AppTokens.gray500),
      );
    }

    final pinned = _isPinned;
    final highlighted = widget.highlighted;
    final selecting = widget.selecting;
    final selectable = selecting && msg.mid > 0;
    final rowBg = highlighted
        ? AppTokens.gray200
        : (widget.selected
            ? AppTokens.primary50
            : (pinned ? AppTokens.primary50 : Colors.transparent));

    final mainRow = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: pinned
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pinned)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.push_pin,
                      size: 12, color: AppTokens.gray400),
                  const SizedBox(width: 4),
                  Text(
                    l.chatPinned,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTokens.gray400,
                      height: 18 / 12,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting) ...[
                // AbsorbPointer: the whole row is the toggle target in select
                // mode; the checkbox is display-only so taps don't race.
                AbsorbPointer(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 4),
                    child: Checkbox(
                      value: widget.selected,
                      onChanged: selectable ? (_) {} : null,
                      activeColor: AppTokens.primary400,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
              VoceAvatar(
                  name: senderName,
                  imageUrl: senderAvatarUrl,
                  size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            safeText(senderName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTokens.primary600,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTokens.gray400,
                            height: 18 / 12,
                          ),
                        ),
                        if (msg.isEdited) ...[
                          const SizedBox(width: 6),
                          Text(
                            l.chatEditMarker,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppTokens.gray400,
                              height: 18 / 12,
                            ),
                          ),
                        ],
                        if (expiresIn != null && expiresIn > 0) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: l.chatExpiresTooltip(
                                _formatExpiresIn(expiresIn)),
                            child: Icon(Icons.timer_outlined,
                                size: 12, color: AppTokens.gray400),
                          ),
                        ],
                        if (widget.status ==
                            MessageSendStatus.sending) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.access_time,
                              size: 12, color: AppTokens.gray400),
                        ] else if (widget.status ==
                            MessageSendStatus.failed) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.error_outline,
                              size: 12, color: AppTokens.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    content,
                    if (msg.mid > 0) ReactionBar(mid: msg.mid),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Select mode: the entire row becomes a toggle target — inner interactive
    // content (image viewers, markdown links, reaction chips) is absorbed so
    // it can't swallow the tap, and the hover toolbar/context menu stay off.
    if (selecting) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selectable ? widget.onToggleSelect : null,
        child: AbsorbPointer(
          child: Opacity(opacity: selectable ? 1 : 0.55, child: mainRow),
        ),
      );
    }

    Widget row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          mainRow,
          if (_hovered)
            Positioned(
              // Anchor toolbar to the top-right of the message row so it
              // stays inside the MouseRegion's hit-test bounds. Floating
              // it above the row (negative top) makes the cursor exit
              // the MouseRegion when it moves up, which causes the
              // toolbar to jump to the previous message.
              top: 0,
              right: 10,
              child: _ReplyActionsBar(
                key: _toolbarKey,
                onEmojiTap: widget.message.mid > 0
                    ? () => _openReactionPicker()
                    : null,
                onReplyTap: widget.message.mid > 0
                    ? () => widget.onReply?.call()
                    : null,
                onFavoriteTap:
                    widget.message.mid > 0 ? () => _favorite() : null,
                onMoreTap: widget.message.mid > 0
                    ? () => _openContextMenuAtToolbar()
                    : null,
              ),
            ),
        ],
      ),
    );

    // Optimistic / failed rows can't be acted on yet.
    if (widget.message.mid > 0) {
      row = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (details) => _openContextMenu(details.globalPosition),
        onSecondaryTapDown: (details) =>
            _openContextMenu(details.globalPosition),
        child: row,
      );
    }

    if (widget.onRetry != null) {
      row = GestureDetector(onTap: widget.onRetry, child: row);
    }
    return row;
  }

  Future<void> _openReactionPicker() async {
    final mid = widget.message.mid;
    if (mid <= 0) return;
    // Anchor the picker to the floating toolbar so it appears flush
    // beneath it (matches the web reference's Tippy popover that hugs
    // its trigger). Falling back to the row bounds would place it
    // far below the message — visually disconnected from the toolbar.
    final anchorContext =
        _toolbarKey.currentContext ?? context;
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    const pickerWidth = 220.0;
    const pickerHeight = 220.0;
    const gap = 4.0;
    final rightEdge = offset.dx + box.size.width;
    await showDialog<void>(
      context: anchorContext,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            // Transparent overlay that dismisses the picker on outside tap.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              // Right-align with the toolbar's right edge.
              left: (rightEdge - pickerWidth)
                  .clamp(8.0, overlay.size.width - pickerWidth - 8)
                  .toDouble(),
              // Place flush beneath the toolbar with a small gap.
              top: (offset.dy + box.size.height + gap)
                  .clamp(8.0, overlay.size.height - pickerHeight - 8)
                  .toDouble(),
              width: pickerWidth,
              child: Material(
                color: Colors.transparent,
                child: ReactionPicker(
                  mid: mid,
                  onPicked: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Opens the context menu anchored to the floating toolbar (the "more"
  /// button), mirroring the web reference where the More dropdown hangs off
  /// the toolbar rather than at the cursor.
  Future<void> _openContextMenuAtToolbar() async {
    final box = _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final topRight = box.localToGlobal(Offset(box.size.width, box.size.height));
    await _openContextMenu(topRight);
  }

  Future<void> _favorite() async {
    final l = AppL10n.of(context);
    final ok =
        await ref.read(favoritesProvider.notifier).add([widget.message.mid]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l.chatToolSavedAdded : l.chatToolSaveFail),
    ));
  }

  Future<void> _openContextMenu(Offset globalPos) async {
    final l = AppL10n.of(context);
    final isChannel = widget.target.map<bool>(
      user: (_) => false,
      group: (_) => true,
    );
    final msg = widget.message;
    final isMine = msg.fromUid == widget.currentUid && widget.currentUid > 0;
    final detail = msg.detail;
    final canEdit = isMine &&
        (detail is NormalMessageDetail || detail is ReplyMessageDetail) &&
        (msg.displayContentType == 'text/plain' ||
            msg.displayContentType == 'text/markdown');

    // Copy is only meaningful for text-ish content (plain/markdown). Files,
    // images, reactions, and archive (forwarded) messages have no clipboard
    // text to copy — mirrors the web reference which hides the copy action
    // for non-text message types.
    final canCopy = msg.displayContentType == 'text/plain' ||
        msg.displayContentType == 'text/markdown';

    final items = <VoceContextMenuItem>[
      VoceContextMenuItem('react', l.chatActionReact,
          icon: Icons.emoji_emotions_outlined),
      VoceContextMenuItem('reply', l.chatActionReply,
          icon: Icons.reply_outlined),
      if (canCopy)
        VoceContextMenuItem('copy', l.chatActionCopy, icon: Icons.copy_outlined),
      VoceContextMenuItem('forward', l.chatActionForward,
          icon: Icons.forward_outlined),
      VoceContextMenuItem('select', l.chatActionSelect,
          icon: Icons.check_circle_outline),
      if (canEdit)
        VoceContextMenuItem('edit', l.chatActionEdit, icon: Icons.edit_outlined),
      if (isChannel)
        VoceContextMenuItem('pin', l.chatToolPin,
            icon: Icons.push_pin_outlined),
      VoceContextMenuItem('fav', l.chatToolSaved, icon: Icons.bookmark_outline),
      if (isMine)
        VoceContextMenuItem('delete', l.chatActionDelete,
            icon: Icons.delete_outline, danger: true),
    ];

    final selection = await showVoceContextMenu(
      context: context,
      globalPos: globalPos,
      items: items,
    );
    if (!mounted || selection == null) return;
    if (selection == 'react') {
      _openReactionPicker();
    } else if (selection == 'reply') {
      widget.onReply?.call();
    } else if (selection == 'copy') {
      await _copyToClipboard();
    } else if (selection == 'forward') {
      await _forward();
    } else if (selection == 'select') {
      widget.onEnterSelect?.call();
    } else if (selection == 'edit') {
      widget.onEdit?.call();
    } else if (selection == 'delete') {
      widget.onDelete?.call();
    } else if (selection == 'pin') {
      final gid = widget.target.map<int>(
        user: (_) => 0,
        group: (t) => t.gid,
      );
      final ok = await ref
          .read(chatToolsProvider)
          .pin(gid: gid, mid: widget.message.mid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? l.chatToolPinAdded : l.chatToolPinFail),
      ));
    } else if (selection == 'fav') {
      await _favorite();
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.message.displayContent));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppL10n.of(context).chatCopiedToClipboard),
    ));
  }

  Future<void> _forward() async {
    await showForwardSheet(context, mids: [widget.message.mid]);
  }
}

// ---------------------------------------------------------------------------
// _ReplyQuotePreview — renders the quoted original inside a reply bubble,
// mirroring the web client's <Reply> renderContent: image originals show a
// thumbnail, audio shows a voice-message label, files show an icon + name,
// and text/markdown show a single clipped line.
// ---------------------------------------------------------------------------

class _ReplyQuotePreview extends StatelessWidget {
  const _ReplyQuotePreview({required this.original});

  final ChatMessage original;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final type = original.displayContentType;
    final content = original.displayContent;

    if (type == 'vocechat/file') {
      final detail = original.detail;
      final props =
          detail is NormalMessageDetail ? detail.properties : null;
      // Reuse the shared file/image renderer so image originals show a real
      // thumbnail and other files show the icon + filename row, identical to
      // a normal file message. Constrain it so a quoted image stays compact.
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 160),
        child: FileMessageContent(content: content, properties: props),
      );
    }

    if (type == 'vocechat/archive') {
      return Text(
        l.chatForwardedMessagePreview,
        style: TextStyle(
          fontSize: 13,
          color: AppTokens.gray500,
          fontStyle: FontStyle.italic,
          height: 18 / 13,
        ),
      );
    }

    if (type == 'text/audio' || type.startsWith('audio')) {
      return Text(
        l.chatReplyVoiceMessage,
        style: TextStyle(
          fontSize: 13,
          color: AppTokens.primary500,
          height: 18 / 13,
        ),
      );
    }

    final snippet = content.replaceAll('\n', ' ').trim();
    return Text(
      safeText(snippet),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        color: AppTokens.gray700,
        height: 18 / 13,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ReplyActionsBar — Figma "Replies / Icons" cluster.
// ---------------------------------------------------------------------------

class _ReplyActionsBar extends StatelessWidget {
  const _ReplyActionsBar({
    super.key,
    this.onEmojiTap,
    this.onReplyTap,
    this.onFavoriteTap,
    this.onMoreTap,
  });

  final VoidCallback? onEmojiTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    // Mirrors the web reference Commands toolbar:
    //   bg-white dark:bg-gray-900, border border-black/10, rounded-md (6px),
    //   flat icon buttons with a gray-100/gray-800 hover.
    final l = AppL10n.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.borderSubtle),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppTokens.brightness == Brightness.dark
                ? const Color(0x66000000)
                : const Color(0x14000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReplyIcon(
              icon: Icons.emoji_emotions_outlined,
              tooltip: l.chatActionReact,
              onTap: onEmojiTap),
          _ReplyIcon(
              icon: Icons.reply_outlined,
              tooltip: l.chatActionReply,
              onTap: onReplyTap),
          _ReplyIcon(
              icon: Icons.bookmark_add_outlined,
              tooltip: l.chatToolSaved,
              onTap: onFavoriteTap),
          _ReplyIcon(
              icon: Icons.more_horiz,
              tooltip: l.actionMore,
              onTap: onMoreTap),
        ],
      ),
    );
  }
}

class _ReplyIcon extends StatelessWidget {
  const _ReplyIcon({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Flat with a hover fill matching the web's md:hover:bg-gray-100. The
    // 32px box keeps the toolbar compact while staying tappable on touch.
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        hoverColor: AppTokens.gray100,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 20, color: AppTokens.gray500),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message context menu styling lives in shared/widgets/voce_context_menu.dart
// (showVoceContextMenu / VoceContextMenuItem), shared with the chat list.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// _SendBox — matches the web client `Send` component:
//   • outer `bg-gray-200` rounded pill, 8px radius
//   • emoji picker pinned bottom-left (absolute), input padded behind it
//   • right-side toolbar: markdown, attach (+), send (zoom-in when text)
//   • icons are flat gray — no IconButton ripple boxes, no primary fill
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// _SelectionBar — replaces the composer while multi-select mode is active
// (web parity with chat Layout's `Operations`): forward / save / delete the
// selected batch, plus a close button that exits the mode.
// ---------------------------------------------------------------------------

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onForward,
    required this.onFavorite,
    required this.onDelete,
    required this.onClose,
  });

  final int count;
  final VoidCallback onForward;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final enabled = count > 0;

    Widget action({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      Color? color,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: AppTokens.gray100,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                size: 20,
                color: enabled
                    ? (color ?? AppTokens.gray700)
                    : AppTokens.gray400,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border(top: BorderSide(color: AppTokens.gray200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.forwardSelectedCount(count),
                style: TextStyle(fontSize: 13, color: AppTokens.gray500),
              ),
            ),
            action(
              icon: Icons.forward_outlined,
              tooltip: l.chatActionForward,
              onTap: onForward,
            ),
            const SizedBox(width: 12),
            action(
              icon: Icons.bookmark_outline,
              tooltip: l.chatToolSaved,
              onTap: onFavorite,
            ),
            const SizedBox(width: 12),
            action(
              icon: Icons.delete_outline,
              tooltip: l.chatActionDelete,
              onTap: onDelete,
              color: AppTokens.error,
            ),
            const SizedBox(width: 16),
            IconButton(
              tooltip: l.actionClose,
              icon: Icon(Icons.close, size: 20, color: AppTokens.gray500),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _SendBox extends StatelessWidget {
  const _SendBox({
    required this.controller,
    required this.canSend,
    required this.onSend,
    required this.placeholder,
    this.onAttach,
    this.onPasteImage,
    this.staged = const [],
    this.onRemoveStaged,
    this.onRenameStaged,
    this.replyTarget,
    this.replyTargetName,
    this.onCancelReply,
    this.textFieldKey,
    this.onChanged,
    this.markdownActive = false,
    this.onToggleMarkdown,
    this.onRecordVoice,
    this.onRecordVideo,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;
  final String placeholder;

  /// Anchor key for the mention overlay — lets [_ChatScreenState] locate the
  /// composer's on-screen position without this widget knowing about
  /// mentions itself.
  final GlobalKey? textFieldKey;

  /// Open the image/file picker.
  final VoidCallback? onAttach;

  /// Attempt to paste an image from the clipboard. Returns true if an image
  /// was found and staged (so the default text paste should be suppressed).
  final Future<bool> Function()? onPasteImage;

  /// Images staged for sending, previewed above the input.
  final List<_StagedFile> staged;

  /// Remove a staged file by index.
  final void Function(int index)? onRemoveStaged;

  /// Open the rename dialog for a staged file by index.
  final void Function(int index)? onRenameStaged;

  final ChatMessage? replyTarget;
  final String? replyTargetName;
  final VoidCallback? onCancelReply;

  /// Fires on every text change — used by [_ChatScreenState] to drive the
  /// mention-overlay trigger. Optional so callers that don't support
  /// mentions (none currently) needn't wire it.
  final void Function(String text)? onChanged;

  /// Whether the next send will use `text/markdown` instead of `text/plain`.
  final bool markdownActive;
  final VoidCallback? onToggleMarkdown;

  /// Open the voice-recording sheet / video-capture screen. Both are only
  /// shown when the composer has no text/staged files (mirrors web's
  /// mic/send mutual-exclusion pattern).
  final VoidCallback? onRecordVoice;
  final VoidCallback? onRecordVideo;

  /// Ctrl/Cmd+V handler: send a clipboard image if present, otherwise fall
  /// back to inserting clipboard text at the caret (the default paste, which
  /// CallbackShortcuts would otherwise swallow).
  void _handlePaste() {
    final paste = onPasteImage;
    if (paste == null) {
      _fallbackTextPaste();
      return;
    }
    paste().then((handled) {
      if (!handled) _fallbackTextPaste();
    });
  }

  Future<void> _fallbackTextPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final value = controller.value;
    final sel = value.selection;
    if (!sel.isValid) {
      controller.text = value.text + text;
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);
      return;
    }
    final newText = value.text.replaceRange(sel.start, sel.end, text);
    controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    // Lift the composer above the system navigation bar (gesture/3-button nav)
    // so the input isn't obscured at the bottom of the screen on phones.
    final navInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      color: AppTokens.surface,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + navInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTarget != null)
            _ReplyChip(
              target: replyTarget!,
              targetName: replyTargetName ?? '',
              onCancel: onCancelReply ?? () {},
            ),
          if (staged.isNotEmpty)
            _StagedPreviewRow(
              staged: staged,
              onRemove: onRemoveStaged ?? (_) {},
              onRename: onRenameStaged ?? (_) {},
            ),
          Container(
            decoration: BoxDecoration(
              color: AppTokens.borderSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SendIcon(
                  icon: Icons.emoji_emotions_outlined,
                  tooltip: l.chatEmoji,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: CallbackShortcuts(
                      bindings: <ShortcutActivator, VoidCallback>{
                        const SingleActivator(LogicalKeyboardKey.enter): () {
                          if (canSend) onSend();
                        },
                        const SingleActivator(LogicalKeyboardKey.numpadEnter):
                            () {
                          if (canSend) onSend();
                        },
                        // Ctrl/Cmd+V: intercept to check for a clipboard image.
                        // If none, fall back to the default text paste so plain
                        // text still pastes normally.
                        const SingleActivator(LogicalKeyboardKey.keyV,
                            control: true): _handlePaste,
                        const SingleActivator(LogicalKeyboardKey.keyV,
                            meta: true): _handlePaste,
                      },
                      child: KeyedSubtree(
                        key: textFieldKey,
                        child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorColor: AppTokens.primary500,
                        onChanged: onChanged,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTokens.gray700,
                          height: 20 / 14,
                        ),
                        decoration: InputDecoration(
                          hintText: placeholder,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppTokens.gray400,
                            height: 20 / 14,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                _SendIcon(
                  icon: Icons.code,
                  tooltip: l.chatMarkdown,
                  onTap: onToggleMarkdown,
                  color: markdownActive ? AppTokens.primary400 : null,
                ),
                const SizedBox(width: 10),
                _SendIcon(
                  icon: Icons.add_circle,
                  tooltip: l.chatAttach,
                  onTap: onAttach,
                ),
                if (!canSend && onRecordVoice != null) ...[
                  const SizedBox(width: 10),
                  _SendIcon(
                    icon: Icons.mic_none,
                    tooltip: l.chatVoiceMessage,
                    onTap: onRecordVoice,
                  ),
                ],
                if (!canSend &&
                    onRecordVideo != null &&
                    (Platform.isAndroid || Platform.isIOS)) ...[
                  const SizedBox(width: 10),
                  _SendIcon(
                    icon: Icons.videocam_outlined,
                    tooltip: l.chatVideoMessage,
                    onTap: onRecordVideo,
                  ),
                ],
                ClipRect(
                  child: AnimatedAlign(
                    alignment: Alignment.centerRight,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    widthFactor: canSend ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: AnimatedScale(
                        scale: canSend ? 1 : 0.6,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: canSend ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: _SendIcon(
                            icon: Icons.send_rounded,
                            tooltip: l.actionSend,
                            onTap: canSend ? onSend : null,
                          ),
                        ),
                      ),
                    ),
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

// ---------------------------------------------------------------------------
// _VoiceRecordSheet — bottom sheet with record/stop, elapsed timer, and
// cancel/send actions. Pops with the recorded bytes on send, or null on
// cancel/dismiss. Uses the `record` package (cross-platform, incl. desktop).
// ---------------------------------------------------------------------------

class _VoiceRecordSheet extends StatefulWidget {
  const _VoiceRecordSheet();

  @override
  State<_VoiceRecordSheet> createState() => _VoiceRecordSheetState();
}

class _VoiceRecordSheetState extends State<_VoiceRecordSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _finishing = false;
  String? _path;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() {
      _recording = true;
      _path = path;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    await _recorder.stop();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    if (_recording) await _recorder.stop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirm() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    _ticker?.cancel();
    if (_recording) await _recorder.stop();
    final path = _path;
    if (path == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final bytes = await File(path).readAsBytes();
    if (mounted) Navigator.of(context).pop(bytes);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.chatVoiceRecording,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTokens.textHeading,
              ),
            ),
            const SizedBox(height: 16),
            if (_permissionDenied)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l.chatRecordingPermissionDenied,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTokens.error),
                ),
              )
            else ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _recording
                      ? AppTokens.error.withValues(alpha: 0.12)
                      : AppTokens.gray100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _recording ? Icons.mic : Icons.mic_none,
                  size: 32,
                  color: _recording ? AppTokens.error : AppTokens.gray500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _formatElapsed(_elapsed),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: AppTokens.textHeading,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _finishing ? null : _cancel,
                    child: Text(l.chatVoiceRecordingCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _permissionDenied || _finishing
                        ? null
                        : (_recording ? _stop : _confirm),
                    child: Text(_recording
                        ? l.actionSend
                        : (_finishing
                            ? l.actionSend
                            : l.chatVoiceRecordingSend)),
                  ),
                ),
              ],
            ),
            if (_recording)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: _finishing
                      ? null
                      : () async {
                          await _stop();
                          if (mounted) await _confirm();
                        },
                  child: Text(l.chatVoiceRecordingSend),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _VideoCaptureScreen — full-screen camera preview with record/stop and a
// confirm/discard step. Pops with the recorded bytes on confirm, or null on
// discard/back. Mobile-only (gated at the call site in `_SendBox`).
// ---------------------------------------------------------------------------

class _VideoCaptureScreen extends StatefulWidget {
  const _VideoCaptureScreen();

  @override
  State<_VideoCaptureScreen> createState() => _VideoCaptureScreenState();
}

class _VideoCaptureScreenState extends State<_VideoCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _recording = false;
  bool _initFailed = false;
  bool _permissionDenied = false;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _initFailed = true);
        return;
      }
      await _openCamera(_cameraIndex);
    } catch (_) {
      if (mounted) setState(() => _initFailed = true);
    }
  }

  Future<void> _openCamera(int index) async {
    final previous = _controller;
    _controller = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: true,
    );
    try {
      await _controller!.initialize();
      await previous?.dispose();
      if (!mounted) return;
      setState(() => _cameraIndex = index);
    } on CameraException catch (e) {
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt') {
        if (mounted) setState(() => _permissionDenied = true);
      } else if (mounted) {
        setState(() => _initFailed = true);
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(next);
  }

  Future<void> _toggleRecord() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (_recording) {
      final file = await ctrl.stopVideoRecording();
      if (mounted) {
        setState(() {
          _recording = false;
          _recordedPath = file.path;
        });
      }
    } else {
      await ctrl.startVideoRecording();
      if (mounted) setState(() => _recording = true);
    }
  }

  Future<void> _confirm() async {
    final path = _recordedPath;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    if (mounted) Navigator.of(context).pop(bytes);
  }

  void _discard() {
    setState(() => _recordedPath = null);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final recordedPath = _recordedPath;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: recordedPath != null
            ? _RecordedVideoPreview(
                path: recordedPath,
                onDiscard: _discard,
                onConfirm: _confirm,
              )
            : _permissionDenied
                ? Center(
                    child: Text(
                      l.chatRecordingPermissionDenied,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : _initFailed || _controller?.value.isInitialized != true
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_controller!),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          if (_cameras.length > 1)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(
                                    Icons.cameraswitch_outlined,
                                    color: Colors.white),
                                onPressed: _recording ? null : _switchCamera,
                              ),
                            ),
                          Positioned(
                            bottom: 32,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _toggleRecord,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: _recording
                                          ? BoxShape.rectangle
                                          : BoxShape.circle,
                                      borderRadius: _recording
                                          ? BorderRadius.circular(6)
                                          : null,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _RecordedVideoPreview extends StatefulWidget {
  const _RecordedVideoPreview({
    required this.path,
    required this.onDiscard,
    required this.onConfirm,
  });

  final String path;
  final VoidCallback onDiscard;
  final VoidCallback onConfirm;

  @override
  State<_RecordedVideoPreview> createState() => _RecordedVideoPreviewState();
}

class _RecordedVideoPreviewState extends State<_RecordedVideoPreview> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _ctrl?.play();
        _ctrl?.setLooping(true);
      });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ctrl = _ctrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: ctrl != null && ctrl.value.isInitialized
              ? AspectRatio(
                  aspectRatio: ctrl.value.aspectRatio,
                  child: VideoPlayer(ctrl),
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
        Positioned(
          bottom: 32,
          left: 24,
          right: 24,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: widget.onDiscard,
                  child: Text(l.chatVoiceRecordingCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: widget.onConfirm,
                  child: Text(l.actionSend),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One staged-but-not-yet-sent image awaiting send.
class _StagedFile {
  _StagedFile({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;

  /// Mutable so the rename dialog can update it in place.
  String filename;
  final String contentType;

  int get size => bytes.length;
  bool get isImage => contentType.startsWith('image/');
}

/// Horizontal row of staged image thumbnails shown above the input — mirrors
/// the web `UploadFileList`. Each chip shows the image with an ✕ remove button.
class _StagedPreviewRow extends StatelessWidget {
  const _StagedPreviewRow({
    required this.staged,
    required this.onRemove,
    required this.onRename,
  });

  final List<_StagedFile> staged;
  final void Function(int index) onRemove;
  final void Function(int index) onRename;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.borderSubtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        height: 138,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: staged.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _StagedFileCard(
            file: staged[i],
            onRemove: () => onRemove(i),
            onRename: () => onRename(i),
          ),
        ),
      ),
    );
  }
}

/// A single staged-file card — thumbnail (or type icon), name, size, plus
/// edit (rename) and remove controls. Mirrors the web `UploadFileList` item.
class _StagedFileCard extends StatelessWidget {
  const _StagedFileCard({
    required this.file,
    required this.onRemove,
    required this.onRename,
  });

  final _StagedFile file;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    const thumbSize = 80.0;
    return SizedBox(
      width: thumbSize + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTokens.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: file.isImage
                      ? Image.memory(
                          file.bytes,
                          width: thumbSize,
                          height: thumbSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: thumbSize,
                            height: thumbSize,
                            color: AppTokens.borderSubtle,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 34,
                              color: AppTokens.textMuted,
                            ),
                          ),
                        )
                      : Container(
                          width: thumbSize,
                          height: thumbSize,
                          color: AppTokens.borderSubtle,
                          alignment: Alignment.center,
                          child: Icon(
                            iconForContentType(file.contentType),
                            size: 34,
                            color: AppTokens.textMuted,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: thumbSize,
                  child: Text(
                    safeText(file.filename),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  formatBytes(file.size),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -10,
            right: -10,
            child: Row(
              children: [
                _CardActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: AppL10n.of(context).actionEdit,
                    onTap: onRename),
                const SizedBox(width: 4),
                _CardActionButton(
                    icon: Icons.close,
                    tooltip: AppL10n.of(context).actionCancel,
                    onTap: onRemove),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The visual disc stays 20px (web parity) but the tappable area is
    // widened to 28px for touch.
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Icon(icon, size: 12, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyChip extends StatelessWidget {
  const _ReplyChip({
    required this.target,
    required this.targetName,
    required this.onCancel,
  });

  final ChatMessage target;
  final String targetName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final preview = target.displayContent.replaceAll('\n', ' ').trim();
    final clipped = preview.length > 80 ? '${preview.substring(0, 80)}…' : preview;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.gray100,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: AppTokens.primary500, width: 3),
            top: AppTokens.brightness == Brightness.dark
                ? BorderSide(color: AppTokens.borderSubtle, width: 1)
                : BorderSide.none,
            right: AppTokens.brightness == Brightness.dark
                ? BorderSide(color: AppTokens.borderSubtle, width: 1)
                : BorderSide.none,
            bottom: AppTokens.brightness == Brightness.dark
                ? BorderSide(color: AppTokens.borderSubtle, width: 1)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.reply, size: 14, color: AppTokens.gray500),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    safeText(l.chatReplyingTo(targetName)),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.primary600,
                      height: 18 / 12,
                    ),
                  ),
                  if (clipped.isNotEmpty)
                    Text(
                      safeText(clipped),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTokens.gray500,
                        height: 18 / 12,
                      ),
                    ),
                ],
              ),
            ),
            InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: AppTokens.gray500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTokens.gray200, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.enter): onSave,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): onSave,
              const SingleActivator(LogicalKeyboardKey.escape): onCancel,
            },
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontSize: 14,
                color: AppTokens.gray700,
                height: 20 / 14,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onCancel,
              child: Text(l.chatEditCancel),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: onSave,
              child: Text(l.chatEditSave),
            ),
          ],
        ),
      ],
    );
  }
}

// Flat gray icon used inside the send pill. No ripple box, tight hit area
// (28px) so the icons sit close together like the web toolbar.
class _SendIcon extends StatelessWidget {
  const _SendIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22, color: color ?? AppTokens.gray500);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        containedInkWell: false,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(child: iconWidget),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyConversation — placeholder when there are no messages yet.
// ---------------------------------------------------------------------------

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTokens.primary50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline,
                size: 24, color: AppTokens.primary500),
          ),
          const SizedBox(height: 12),
          Text(
            l.chatEmpty,
            style: TextStyle(
              fontSize: 14,
              color: AppTokens.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// File reading shared by clipboard-paste and drag-drop. Both surfaces reduce
// to: given a single-item DataReader, read its file bytes + a filename.
// ---------------------------------------------------------------------------

/// Read an arbitrary file (any type) from a single-item [DataReader] into
/// `(bytes, filename)`. Passing `null` to `getFile` makes super_native
/// synthesize the file from its URI on desktop, so this works for images,
/// PDFs, docs — anything copied or dropped. Returns null when the item holds
/// no readable file.
Future<(Uint8List, String)?> _readFileFromReader(DataReader item) async {
  final suggested = await item.getSuggestedName();
  final completer = Completer<(Uint8List, String)?>();
  final progress = item.getFile(null, (file) async {
    try {
      final bytes = await file.readAll();
      final name = file.fileName ?? suggested ?? 'file';
      if (!completer.isCompleted) completer.complete((bytes, name));
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
  }, onError: (_) {
    if (!completer.isCompleted) completer.complete(null);
  });
  // getFile returns null synchronously when the item has no file to provide.
  if (progress == null && !completer.isCompleted) completer.complete(null);
  return completer.future;
}
