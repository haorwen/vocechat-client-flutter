import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/storage/secure_token_store.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import 'file_display_utils.dart';

/// Renders a `vocechat/file` message — image, video, audio, or generic file.
///
/// Mirrors the web reference's FileMessage dispatch:
///   - image content_type (excl. raw camera, size ≤ 10MB) → inline thumbnail,
///     tap opens a full-screen viewer with download / zoom-in / zoom-out /
///     fullscreen / close (web lightbox parity).
///   - video → thumb with play overlay, tap opens chewie full-screen player.
///   - audio → inline just_audio player.
///   - other → file card with a download button.
///
/// vocechat/file body is JSON `{"path": "<server path>"}`. Width/height/name/
/// content_type/size come from the message's `properties` map.
class FileMessageContent extends ConsumerWidget {
  const FileMessageContent({
    super.key,
    required this.content,
    required this.properties,
    this.localBytes,
    this.sending = false,
    this.progress,
  });

  final String content;
  final Map<String, dynamic>? properties;

  /// Local image bytes for an optimistic (not-yet-uploaded) row. When set and
  /// the message is an image, the bubble previews from memory instead of the
  /// server URL.
  final Uint8List? localBytes;

  /// Whether this row is still uploading (shows a sending overlay on the
  /// local preview).
  final bool sending;

  /// Upload progress in [0, 1] for an in-flight row. Null when unknown — the
  /// overlay then shows an indeterminate spinner.
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = _parseFileMessage(content, properties);
    if (parsed == null) {
      return Text(
        safeText(content),
        style: TextStyle(
          fontSize: 14,
          color: AppTokens.gray700,
          height: 20 / 14,
        ),
      );
    }

    // Optimistic local image: render directly from memory (no server URL yet).
    if (localBytes != null && _isImage(parsed.contentType, parsed.size)) {
      return _LocalImageBubble(
        bytes: localBytes!,
        meta: parsed,
        sending: sending,
        progress: progress,
      );
    }

    final urls = _buildResourceUrls(ref, parsed.path);
    if (urls == null) {
      return _FileCard(meta: parsed, urls: null);
    }

    if (_isImage(parsed.contentType, parsed.size)) {
      return _ImageBubble(meta: parsed, urls: urls);
    }
    if (parsed.contentType.startsWith('video')) {
      return _VideoBubble(meta: parsed, urls: urls);
    }
    if (parsed.contentType.startsWith('audio')) {
      return _AudioBubble(meta: parsed, urls: urls);
    }
    return _FileCard(meta: parsed, urls: urls);
  }
}

// ---------------------------------------------------------------------------
// Parsing + URL helpers
// ---------------------------------------------------------------------------

class _FileMeta {
  const _FileMeta({
    required this.path,
    required this.contentType,
    required this.name,
    required this.size,
    required this.width,
    required this.height,
  });

  final String path;
  final String contentType;
  final String name;
  final int size;
  final double? width;
  final double? height;
}

_FileMeta? _parseFileMessage(String content, Map<String, dynamic>? props) {
  String? path;
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      path = decoded['path'] as String?;
    } else if (decoded is String) {
      path = decoded;
    }
  } catch (_) {
    if (content.isNotEmpty && !content.trim().startsWith('{')) {
      path = content;
    }
  }
  if (path == null || path.isEmpty) return null;

  final p = props ?? const <String, dynamic>{};
  return _FileMeta(
    path: path,
    contentType: (p['content_type'] as String?) ?? '',
    name: (p['name'] as String?) ?? '',
    size: (p['size'] as num?)?.toInt() ?? 0,
    width: (p['width'] as num?)?.toDouble(),
    height: (p['height'] as num?)?.toDouble(),
  );
}

class _ResourceUrls {
  const _ResourceUrls({
    required this.thumbnail,
    required this.origin,
    required this.download,
    required this.baseUrl,
  });

  final String thumbnail;
  final String origin;
  final String download;
  final String baseUrl;
}

_ResourceUrls? _buildResourceUrls(WidgetRef ref, String path) {
  final serverState = ref.read(serverStoreProvider).valueOrNull;
  final server = serverState?.servers
      .where((s) => s.id == serverState.currentServerId)
      .firstOrNull;
  final base = server?.baseUrl ?? '';
  if (base.isEmpty) return null;
  final encoded = Uri.encodeQueryComponent(path);
  final root = '$base/api/resource/file?file_path=$encoded';
  return _ResourceUrls(
    thumbnail: '$root&thumbnail=true',
    origin: root,
    download: '$root&download=true',
    baseUrl: base,
  );
}

Map<String, String> _refererOnlyHeaders(String baseUrl) {
  final headers = <String, String>{};
  if (baseUrl.isNotEmpty) {
    final uri = Uri.tryParse(baseUrl);
    if (uri != null && uri.host.isNotEmpty) {
      headers['Referer'] = '${uri.scheme}://${uri.authority}/';
    }
  }
  return headers;
}

Future<Map<String, String>> _buildAuthHeaders(
  WidgetRef ref,
  String baseUrl,
) async {
  final headers = _refererOnlyHeaders(baseUrl);
  final serverId = ref.read(serverStoreProvider).valueOrNull?.currentServerId;
  if (serverId != null) {
    final store = ref.read(secureTokenStoreProvider(serverId));
    final tokens = await store.readTokens();
    if (tokens != null) headers['X-API-Key'] = tokens.accessToken;
  }
  return headers;
}

bool _isImage(String contentType, int size) {
  if (contentType.isEmpty) return false;
  if (contentType == 'image/x-sony-arw') return false;
  if (!contentType.startsWith('image')) return false;
  const fileImageSize = 10 * 1024 * 1024;
  if (size > fileImageSize) return false;
  return true;
}

String _formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:$m:$s';
  return '$m:$s';
}

Future<void> _launchExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ---------------------------------------------------------------------------
// Image bubble + preview
// ---------------------------------------------------------------------------

/// Computes a clamped bubble size from natural image dimensions.
/// Matches _ImageBubble's sizing so optimistic → confirmed has no layout jump.
(double, double) _imageBubbleSize(double? natW, double? natH) {
  const minSize = 80.0;
  const maxSize = 240.0;
  double bubbleW = maxSize;
  double bubbleH = maxSize;
  if (natW != null && natH != null && natW > 0 && natH > 0) {
    final ratio = natW / natH;
    if (ratio >= 1) {
      bubbleH = (maxSize / ratio).clamp(minSize, maxSize);
    } else {
      bubbleW = (maxSize * ratio).clamp(minSize, maxSize);
    }
  }
  return (bubbleW, bubbleH);
}

/// Optimistic image preview rendered from in-memory bytes while the upload is
/// in flight. Shows a translucent overlay + spinner when [sending].
class _LocalImageBubble extends StatelessWidget {
  const _LocalImageBubble({
    required this.bytes,
    required this.meta,
    required this.sending,
    this.progress,
  });

  final Uint8List bytes;
  final _FileMeta meta;
  final bool sending;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final (bubbleW, bubbleH) = _imageBubbleSize(meta.width, meta.height);
    final pct = progress == null ? null : (progress!.clamp(0.0, 1.0) * 100).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: bubbleW,
        height: bubbleH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            if (sending)
              Container(
                color: Colors.white.withValues(alpha: 0.5),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        // Indeterminate until the first byte-progress callback.
                        value: progress?.clamp(0.0, 1.0),
                        backgroundColor: Colors.black.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTokens.primary500,
                        ),
                      ),
                    ),
                    if (pct != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTokens.gray700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageBubble extends ConsumerStatefulWidget {
  const _ImageBubble({required this.meta, required this.urls});

  final _FileMeta meta;
  final _ResourceUrls urls;

  @override
  ConsumerState<_ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends ConsumerState<_ImageBubble> {
  Map<String, String>? _resolvedHeaders;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _buildAuthHeaders(ref, widget.urls.baseUrl).then((h) {
      if (mounted) setState(() => _resolvedHeaders = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _ExpiredCard(kind: _ExpiredKind.image, name: widget.meta.name);
    }

    final natW = widget.meta.width;
    final natH = widget.meta.height;
    final (bubbleW, bubbleH) = _imageBubbleSize(natW, natH);

    final headers = _resolvedHeaders ?? _refererOnlyHeaders(widget.urls.baseUrl);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _resolvedHeaders == null
          ? null
          : () => _openPreview(context, _resolvedHeaders!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: bubbleW,
          height: bubbleH,
          child: CachedNetworkImage(
            imageUrl: widget.urls.thumbnail,
            httpHeaders: headers,
            fit: BoxFit.cover,
            placeholder: (context, _) => Container(
              color: AppTokens.gray100,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_failed) setState(() => _failed = true);
              });
              return Container(
                color: AppTokens.gray100,
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppTokens.gray400,
                  size: 32,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openPreview(BuildContext context, Map<String, String> headers) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImagePreviewScreen(
          originUrl: widget.urls.origin,
          downloadUrl: widget.urls.download,
          headers: headers,
          title: widget.meta.name,
        ),
      ),
    );
  }
}

class _ImagePreviewScreen extends StatefulWidget {
  const _ImagePreviewScreen({
    required this.originUrl,
    required this.downloadUrl,
    required this.headers,
    required this.title,
  });

  final String originUrl;
  final String downloadUrl;
  final Map<String, String> headers;
  final String title;

  @override
  State<_ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<_ImagePreviewScreen> {
  final PhotoViewController _photoCtrl = PhotoViewController();
  bool _isFullscreen = false;

  @override
  void dispose() {
    _photoCtrl.dispose();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    super.dispose();
  }

  void _zoom(double factor) {
    final current = _photoCtrl.scale ?? 1.0;
    final next = (current * factor).clamp(0.25, 16.0);
    _photoCtrl.scale = next;
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Photo
          Positioned.fill(
            child: PhotoView(
              controller: _photoCtrl,
              imageProvider: CachedNetworkImageProvider(
                widget.originUrl,
                headers: widget.headers,
              ),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              loadingBuilder: (context, event) => const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              errorBuilder: (context, error, stack) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),
          // Top toolbar (web lightbox parity: download / zoom-in / zoom-out /
          // fullscreen / close, right-aligned)
          if (!_isFullscreen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            safeText(widget.title),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      _ToolbarBtn(
                        icon: Icons.download_outlined,
                        tooltip: 'Download',
                        onTap: () => _launchExternal(widget.downloadUrl),
                      ),
                      _ToolbarBtn(
                        icon: Icons.zoom_in_outlined,
                        tooltip: 'Zoom in',
                        onTap: () => _zoom(1.25),
                      ),
                      _ToolbarBtn(
                        icon: Icons.zoom_out_outlined,
                        tooltip: 'Zoom out',
                        onTap: () => _zoom(0.8),
                      ),
                      _ToolbarBtn(
                        icon: Icons.fullscreen_outlined,
                        tooltip: 'Fullscreen',
                        onTap: _toggleFullscreen,
                      ),
                      _ToolbarBtn(
                        icon: Icons.close,
                        tooltip: 'Close',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: _ToolbarBtn(
                  icon: Icons.fullscreen_exit_outlined,
                  tooltip: 'Exit fullscreen',
                  onTap: _toggleFullscreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        splashRadius: 22,
        onPressed: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video bubble + full-screen chewie player
// ---------------------------------------------------------------------------

class _VideoBubble extends ConsumerStatefulWidget {
  const _VideoBubble({required this.meta, required this.urls});

  final _FileMeta meta;
  final _ResourceUrls urls;

  @override
  ConsumerState<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends ConsumerState<_VideoBubble> {
  Map<String, String>? _headers;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _buildAuthHeaders(ref, widget.urls.baseUrl).then((h) {
      if (mounted) setState(() => _headers = h);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _ExpiredCard(kind: _ExpiredKind.video, name: widget.meta.name);
    }
    final label = widget.meta.name.isEmpty
        ? widget.meta.path.split('/').last
        : widget.meta.name;
    final sizeLabel = formatBytes(widget.meta.size);
    return GestureDetector(
      onTap: _headers == null ? null : () => _openPlayer(context, _headers!),
      child: Container(
        width: 280,
        height: 158,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTokens.gray300),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Icon(
                    Icons.movie_outlined,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      safeText(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (sizeLabel.isNotEmpty)
                    Text(
                      sizeLabel,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context, Map<String, String> headers) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _VideoPlayerScreen(
          url: widget.urls.origin,
          headers: headers,
          title: widget.meta.name,
          downloadUrl: widget.urls.download,
          onFail: () {
            if (mounted) setState(() => _failed = true);
          },
        ),
      ),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  const _VideoPlayerScreen({
    required this.url,
    required this.headers,
    required this.title,
    required this.downloadUrl,
    required this.onFail,
  });

  final String url;
  final Map<String, String> headers;
  final String title;
  final String downloadUrl;
  final VoidCallback onFail;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: widget.headers,
      );
      await ctrl.initialize();
      if (!mounted) return;
      _chewieCtrl = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: true,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTokens.primary500,
          handleColor: AppTokens.primary500,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );
      setState(() => _videoCtrl = ctrl);
    } catch (_) {
      if (mounted) {
        setState(() => _initFailed = true);
        widget.onFail();
      }
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          safeText(widget.title),
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _launchExternal(widget.downloadUrl),
          ),
        ],
      ),
      body: Center(
        child: _initFailed
            ? const Icon(
                Icons.error_outline,
                color: Colors.white54,
                size: 48,
              )
            : _chewieCtrl == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Chewie(controller: _chewieCtrl!),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audio bubble (inline just_audio player)
// ---------------------------------------------------------------------------

class _AudioBubble extends ConsumerStatefulWidget {
  const _AudioBubble({required this.meta, required this.urls});

  final _FileMeta meta;
  final _ResourceUrls urls;

  @override
  ConsumerState<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends ConsumerState<_AudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  Duration? _duration;
  Duration _position = Duration.zero;
  bool _failed = false;
  bool _ready = false;

  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final headers = await _buildAuthHeaders(ref, widget.urls.baseUrl);
      final dur = await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(widget.urls.origin),
          headers: headers,
        ),
      );
      if (!mounted) return;
      setState(() {
        _duration = dur;
        _ready = true;
      });
      _durSub = _player.durationStream.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _posSub = _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _stateSub = _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _durSub?.cancel();
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _ExpiredCard(kind: _ExpiredKind.audio, name: widget.meta.name);
    }
    final playing = _player.playing;
    final label = widget.meta.name.isEmpty
        ? widget.meta.path.split('/').last
        : widget.meta.name;
    final total = _duration ?? Duration.zero;
    final pos = _position > total ? total : _position;
    final sizeLabel = formatBytes(widget.meta.size);

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTokens.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.audiotrack_outlined,
                  color: AppTokens.primary500, size: 22),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  safeText(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray700,
                  ),
                ),
              ),
              if (sizeLabel.isNotEmpty)
                Text(
                  sizeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTokens.gray500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: !_ready
                    ? null
                    : () => playing ? _player.pause() : _player.play(),
                icon: Icon(
                  playing ? Icons.pause_circle : Icons.play_circle,
                  color: AppTokens.primary500,
                  size: 32,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: AppTokens.primary500,
                    inactiveTrackColor: AppTokens.gray200,
                    thumbColor: AppTokens.primary500,
                  ),
                  child: Slider(
                    value: total.inMilliseconds == 0
                        ? 0
                        : pos.inMilliseconds
                            .toDouble()
                            .clamp(0, total.inMilliseconds.toDouble()),
                    max: total.inMilliseconds == 0
                        ? 1
                        : total.inMilliseconds.toDouble(),
                    onChanged: !_ready || total.inMilliseconds == 0
                        ? null
                        : (v) {
                            _player.seek(Duration(milliseconds: v.toInt()));
                          },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${_formatDuration(pos)} / ${_formatDuration(total)}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTokens.gray500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// File card (non-media) with download button
// ---------------------------------------------------------------------------

class _FileCard extends StatelessWidget {
  const _FileCard({required this.meta, required this.urls});

  final _FileMeta meta;
  final _ResourceUrls? urls;

  @override
  Widget build(BuildContext context) {
    final icon = iconForContentType(meta.contentType);
    final label = meta.name.isEmpty ? meta.path.split('/').last : meta.name;
    final sizeLabel = formatBytes(meta.size);
    final canDownload = urls != null;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTokens.gray200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTokens.primary500, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  safeText(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray700,
                  ),
                ),
                if (sizeLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sizeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTokens.gray500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canDownload)
            IconButton(
              tooltip: 'Download',
              icon: Icon(
                Icons.download_outlined,
                color: AppTokens.gray500,
                size: 22,
              ),
              onPressed: () => _launchExternal(urls!.download),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expired card
// ---------------------------------------------------------------------------

enum _ExpiredKind { image, video, audio, file }

class _ExpiredCard extends StatelessWidget {
  const _ExpiredCard({required this.kind, required this.name});

  final _ExpiredKind kind;
  final String name;

  @override
  Widget build(BuildContext context) {
    final spec = switch (kind) {
      _ExpiredKind.image => (
          Icons.image_outlined,
          'Image not Found',
          'Image expired or deleted',
        ),
      _ExpiredKind.video => (
          Icons.movie_outlined,
          'Video not Found',
          'Video expired or deleted',
        ),
      _ExpiredKind.audio => (
          Icons.audiotrack_outlined,
          'Audio not Found',
          'Audio expired or deleted',
        ),
      _ExpiredKind.file => (
          Icons.insert_drive_file_outlined,
          'File not Found',
          'File expired or deleted',
        ),
    };
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTokens.gray300),
      ),
      child: Row(
        children: [
          Icon(spec.$1, color: AppTokens.gray400, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec.$3,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTokens.gray500,
                  ),
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    safeText(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTokens.gray400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.info_outline, color: AppTokens.error, size: 18),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reply snippet helper
// ---------------------------------------------------------------------------

String? fileMessageReplySnippet(
  String content,
  Map<String, dynamic>? properties,
) {
  final parsed = _parseFileMessage(content, properties);
  if (parsed == null) return null;
  if (parsed.contentType.startsWith('image')) return '[Image]';
  if (parsed.contentType.startsWith('video')) return '[Video]';
  if (parsed.contentType.startsWith('audio')) return '[Audio]';
  final name = parsed.name.isEmpty
      ? parsed.path.split('/').last
      : parsed.name;
  return '[File: $name]';
}
