import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../src/messages.g.dart';
import '../utils/toast.dart';
import 'editor_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final CaptureApi _api = CaptureApi();
  static const MethodChannel _windowChannel = MethodChannel(
    'app.xowcase/window',
  );

  List<CaptureSource> _sources = [];
  bool _isLoading = true;
  String? _error;

  CaptureSource? _activeSource;
  CaptureSource? _selectedSource;

  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadSources();
    _windowChannel.invokeMethod('setSize', {'width': 400.0, 'height': 80.0});
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSources() async {
    try {
      final sources = await _api.getAvailableSources();
      setState(() {
        _sources = sources;
        if (_selectedSource == null && sources.isNotEmpty) {
          _selectedSource = sources.firstWhere(
            (s) => s.type == 2,
            orElse: () => sources.first,
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showDeviceSelector(BuildContext context, TapDownDetails details) async {
    if (_sources.isEmpty) {
      await _loadSources();
    }

    final simulators = _sources.where((s) => s.type == 2).toList();
    if (simulators.isEmpty && mounted) {
      showToast(context, 'No booted simulators found. Please launch one.', isError: true);
      return;
    }

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final CaptureSource? selected = await showMenu<CaptureSource>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,

      items: simulators.map((CaptureSource source) {
        return PopupMenuItem<CaptureSource>(
          value: source,
          child: Text(
            source.name,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedSource = selected;
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _activeSource != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: GestureDetector(
          onPanStart: (details) {
            _windowChannel.invokeMethod('startDragging');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 600,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isRecording
                      ? const Color(0xFFDC2626).withOpacity(0.15)
                      : Colors.black.withOpacity(0.12),
                  blurRadius: isRecording ? 20 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isRecording
                    ? const Color(0xFFFCA5A5).withOpacity(0.5)
                    : Colors.black.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: isRecording
                      ? const SizedBox.shrink()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 8),

                            GestureDetector(
                              onTap: () => exit(0),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                ),

                // Logo / Indicator
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isRecording
                      ? Container(
                          key: const ValueKey('rec_indicator'),
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fiber_manual_record,
                            color: Colors.white,
                            size: 12,
                          ),
                        )
                      : Image.asset(
                          'assets/logo.png',
                          key: const ValueKey('logo'),
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                ),
                const SizedBox(width: 12),

                // Source Name and Timestamp (Horizontal)
                Expanded(
                  child: _isLoading
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            return GestureDetector(
                              onTapDown: isRecording
                                  ? null
                                  : (details) =>
                                        _showDeviceSelector(context, details),
                              child: Container(
                                color: Colors
                                    .transparent, // Ensures the gesture detector covers the whole expanded area
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedSource?.name ?? 'No Simulator',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Color(0xFF1F2937),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                      child: !isRecording
                                          ? const Icon(
                                              Icons.unfold_more,
                                              size: 16,
                                              color: Colors.black38,
                                              key: ValueKey('unfold'),
                                            )
                                          : Row(
                                              key: const ValueKey('timer'),
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFEF2F2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 500,
                                                            ),
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              _recordingDuration
                                                                          .inSeconds %
                                                                      2 ==
                                                                  0
                                                              ? const Color(
                                                                  0xFFDC2626,
                                                                )
                                                              : const Color(
                                                                  0xFFFCA5A5,
                                                                ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        _formatDuration(
                                                          _recordingDuration,
                                                        ),
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 12,
                                                          height:
                                                              1.0, // Removes text leading for perfect vertical alignment
                                                          color: Color(
                                                            0xFFDC2626,
                                                          ),
                                                          letterSpacing: 1,
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
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(width: 8),

                // Record / Stop Button
                GestureDetector(
                  onTap: () {
                    if (isRecording) {
                      _handleStopRecording();
                    } else if (_selectedSource != null) {
                      _handleStartRecording(_selectedSource!);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutBack,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isRecording
                          ? const Color(0xFFF3F4F6)
                          : const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: isRecording
                          ? Border.all(color: Colors.black12)
                          : Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: isRecording ? 12 : 14,
                        height: isRecording ? 12 : 14,
                        decoration: BoxDecoration(
                          color: isRecording
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(
                            isRecording ? 3 : 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleStartRecording(CaptureSource source) async {
    if (source.type != 2) {
      showToast(context, 'Use a Simulator!', isError: true);
      return;
    }
    try {
      final home = Platform.environment['HOME'] ?? '';
      final outputPath =
          '$home/Downloads/xowcase_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await _api.startCapture(source.id, source.type, outputPath);
      setState(() {
        _activeSource = source;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      });
    } catch (e) {
      if (mounted) {
        showToast(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _handleStopRecording() async {
    try {
      _recordingTimer?.cancel();
      final sourceId = _activeSource!.id;
      await _api.stopCapture();
      setState(() => _activeSource = null);
      if (mounted) {
        _openEditor(sourceId);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Error: $e', isError: true);
      }
    }
  }

  void _openEditor(String sourceId) {
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory('$home/Downloads');
    if (!dir.existsSync()) return;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('xowcase_'))
        .toList();
    if (files.isEmpty) return;

    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    final latestVideo = files.first.path;

    // Resize back to Editor size (it will re-add traffic lights!)
    _windowChannel.invokeMethod('setSize', {'width': 1200.0, 'height': 800.0});

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => EditorScreen(videoPath: latestVideo),
          ),
        )
        .then((_) {
          // Resize back to Tiny Pill when editor closes
          _windowChannel.invokeMethod('setSize', {
            'width': 400.0,
            'height': 80.0,
          });
        });
  }
}
