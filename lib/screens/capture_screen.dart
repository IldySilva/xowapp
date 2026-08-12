import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_paths.dart';
import '../services/capture_service.dart';
import '../services/video_source.dart';
import '../services/window_service.dart';
import '../src/messages.g.dart';
import '../utils/toast.dart';
import 'editor_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final CaptureService _api = CaptureService.create();

  List<CaptureSource> _sources = [];
  bool _isLoading = true;
  String? _error;
  String _debugState = 'Init';

  CaptureSource? _activeSource;
  CaptureSource? _selectedSource;

  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  int _selectedTab = 0; // 0: Screens, 1: Windows, 2: Simulators, 3: Import

  @override
  void initState() {
    super.initState();
    _loadSources();
    WindowService.setSize(width: 500, height: 450);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _debugState = 'Calling getAvailableSources...';
    });
    try {
      final sources = await _api.getAvailableSources();
      setState(() {
        _debugState =
            'Returned ${sources.length} sources (${_platformLabel()})';
        _sources = sources;
        if (_selectedSource == null && sources.isNotEmpty) {
          final recordable = sources.where((s) => s.type != 3).toList();
          _selectedSource =
              recordable.isNotEmpty ? recordable.first : sources.first;
        }
        if (!_api.supportsNativeCapture &&
            !_api.supportsBrowserCapture &&
            sources.any((s) => s.type == 3)) {
          _selectedTab = 3;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugState = 'Exception caught: $e';
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> _closeApp() async {
    if (kIsWeb) {
      // Browser tabs cannot be force-closed reliably.
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _activeSource != null;
    return Scaffold(
      backgroundColor: kIsWeb ? const Color(0xFFF3F4F6) : Colors.transparent,
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isRecording ? _buildRecordingPill() : _buildDashboard(),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final screens = _sources.where((s) => s.type == 0).toList();
    final windows = _sources.where((s) => s.type == 1).toList();
    final simulators = _sources.where((s) => s.type == 2).toList();
    final imports = _sources.where((s) => s.type == 3).toList();

    final currentList = switch (_selectedTab) {
      0 => screens,
      1 => windows,
      2 => simulators,
      3 => imports,
      _ => screens,
    };

    final canRecordSelected = _selectedSource != null &&
        _selectedSource!.type != 3 &&
        (_api.supportsNativeCapture || _api.supportsBrowserCapture);

    return GestureDetector(
      onPanStart: (_) => WindowService.startDragging(),
      child: Container(
        width: 500,
        height: 450,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', width: 24, height: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Source',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    color: Colors.black54,
                    onPressed: _loadSources,
                  ),
                  if (!kIsWeb)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.black54,
                      onPressed: _closeApp,
                    ),
                ],
              ),
            ),
            Text(
              _debugState,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTab(0, 'Screens', screens.length),
                  _buildTab(1, 'Windows', windows.length),
                  _buildTab(2, 'Simulators', simulators.length),
                  _buildTab(3, 'Import', imports.isEmpty ? 1 : imports.length),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5EA)),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            'Error: $_error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : _selectedTab == 3
                          ? _buildImportPane()
                          : currentList.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      _emptyMessage(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: currentList.length,
                                  itemBuilder: (context, index) {
                                    final s = currentList[index];
                                    final isSelected = _selectedSource == s;
                                    return Material(
                                      color: isSelected
                                          ? const Color(0xFF0A84FF)
                                              .withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      child: ListTile(
                                        leading: Icon(
                                          _selectedTab == 0
                                              ? Icons.monitor
                                              : (_selectedTab == 1
                                                  ? Icons.window
                                                  : Icons.phone_iphone),
                                          color: isSelected
                                              ? const Color(0xFF0A84FF)
                                              : Colors.black54,
                                        ),
                                        title: Text(
                                          s.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? const Color(0xFF0A84FF)
                                                : const Color(0xFF1F2937),
                                          ),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        onTap: () => setState(() {
                                          _selectedSource = s;
                                        }),
                                      ),
                                    );
                                  },
                                ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5EA)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _handleImportVideo,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Import video'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1F2937),
                          side: const BorderSide(color: Color(0xFFE5E5EA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          disabledBackgroundColor: const Color(0xFFFCA5A5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: canRecordSelected
                            ? () => _handleStartRecording(_selectedSource!)
                            : null,
                        child: Text(
                          kIsWeb ? 'Record screen' : 'Record',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
      ),
    );
  }

  String _emptyMessage() {
    if (kIsWeb) {
      return 'Use Record screen to capture a browser tab/window, or Import a video.';
    }
    if (!_api.supportsNativeCapture) {
      return 'Native capture is only on macOS. Import a video to edit on Linux.';
    }
    return 'No sources available.';
  }

  Widget _buildImportPane() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_file_outlined, size: 48, color: Colors.black38),
            const SizedBox(height: 16),
            const Text(
              'Open an existing recording to wrap it in a device frame.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _handleImportVideo,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String title, int count) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF0A84FF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? const Color(0xFF0A84FF) : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0A84FF).withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF0A84FF) : Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingPill() {
    return GestureDetector(
      onPanStart: (_) => WindowService.startDragging(),
      child: Container(
        width: 400,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFFCA5A5).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 12),
            Container(
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _activeSource?.name ?? 'Recording',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _recordingDuration.inSeconds % 2 == 0
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFFCA5A5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(_recordingDuration),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            height: 1.0,
                            color: Color(0xFFDC2626),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _handleStopRecording,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImportVideo() async {
    try {
      final picked = await _api.importVideo();
      if (picked == null) return;
      if (!mounted) return;
      _openEditorWithSource(
        VideoSource(
          pathOrUrl: picked.pathOrUrl,
          isNetworkUrl: picked.isNetworkUrl,
          bytes: picked.bytes,
        ),
        picked.asSource,
      );
    } catch (e) {
      if (mounted) {
        showToast(context, 'Import failed: $e', isError: true);
      }
    }
  }

  Future<void> _handleStartRecording(CaptureSource source) async {
    try {
      final outputPath = await AppPaths.uniqueName('xowcase_', 'mp4');

      await WindowService.setSize(width: 400, height: 80);

      await _api.startCapture(
        sourceId: source.id,
        sourceType: source.type,
        outputPath: outputPath,
      );
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
        setState(() {
          _error = e.toString();
        });
        showToast(context, 'Error: $e', isError: true);
        await WindowService.setSize(width: 500, height: 450);
      }
    }
  }

  Future<void> _handleStopRecording() async {
    try {
      _recordingTimer?.cancel();
      final source = _activeSource!;
      final videoPath = await _api.stopCapture();
      setState(() => _activeSource = null);
      if (!mounted) return;

      if (videoPath == null || videoPath.isEmpty) {
        showToast(context, 'No recording found', isError: true);
        await WindowService.setSize(width: 500, height: 450);
        return;
      }

      _openEditorWithSource(
        VideoSource(
          pathOrUrl: videoPath,
          isNetworkUrl: kIsWeb || videoPath.startsWith('blob:'),
        ),
        source,
      );
    } catch (e) {
      if (mounted) {
        showToast(context, 'Error: $e', isError: true);
      }
    }
  }

  void _openEditorWithSource(VideoSource video, CaptureSource source) {
    WindowService.setSize(width: 1200, height: 800);

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => EditorScreen(video: video, source: source),
          ),
        )
        .then((_) {
      WindowService.setSize(width: 500, height: 450);
    });
  }
}
