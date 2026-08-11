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
  String _debugState = "Init";

  CaptureSource? _activeSource;
  CaptureSource? _selectedSource;

  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  int _selectedTab = 0; // 0: Screens, 1: Windows, 2: Simulators

  @override
  void initState() {
    super.initState();
    _loadSources();
    _windowChannel.invokeMethod('setSize', {'width': 500.0, 'height': 450.0});
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
      _debugState = "Calling getAvailableSources...";
    });
    try {
      final sources = await _api.getAvailableSources();
      setState(() {
        _debugState = "Returned ${sources.length} sources";
        _sources = sources;
        if (_selectedSource == null && sources.isNotEmpty) {
          _selectedSource = sources.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugState = "Exception caught: $e";
        _error = e.toString();
        _isLoading = false;
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

    final currentList = _selectedTab == 0
        ? screens
        : (_selectedTab == 1 ? windows : simulators);

    return GestureDetector(
      onPanStart: (details) => _windowChannel.invokeMethod('startDragging'),
      child: Container(
        width: 500,
        height: 450,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
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
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.black54,
                    onPressed: () => exit(0),
                  ),
                ],
              ),
            ),
            // Debug text
            Text(
              _debugState,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            // Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab(0, 'Screens', screens.length),
                _buildTab(1, 'Windows', windows.length),
                _buildTab(2, 'Simulators', simulators.length),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFE5E5EA)),
            // List
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
                  : currentList.isEmpty
                  ? const Center(
                      child: Text(
                        'No sources available.',
                        style: TextStyle(color: Colors.black38),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: currentList.length,
                      itemBuilder: (context, index) {
                        final s = currentList[index];
                        final isSelected = _selectedSource == s;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0A84FF).withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                              borderRadius: BorderRadius.circular(8),
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
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _selectedSource == null
                      ? null
                      : () => _handleStartRecording(_selectedSource!),
                  child: const Text(
                    'Record',
                    style: TextStyle(
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
    );
  }

  Widget _buildTab(int index, String title, int count) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    ? const Color(0xFF0A84FF).withOpacity(0.1)
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
      onPanStart: (details) => _windowChannel.invokeMethod('startDragging'),
      child: Container(
        width: 400,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFFCA5A5).withOpacity(0.5),
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

  Future<void> _handleStartRecording(CaptureSource source) async {
    try {
      final home = Platform.environment['HOME'] ?? '';
      final outputPath =
          '$home/Downloads/xowcase_${DateTime.now().millisecondsSinceEpoch}.mp4';

      _windowChannel.invokeMethod('setSize', {'width': 400.0, 'height': 80.0});

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
        setState(() {
            _error = e.toString();
        });
        showToast(context, 'Error: $e', isError: true);
        _windowChannel.invokeMethod('setSize', {
          'width': 500.0,
          'height': 450.0,
        });
      }
    }
  }

  Future<void> _handleStopRecording() async {
    try {
      _recordingTimer?.cancel();
      final source = _activeSource!;
      final sourceId = source.id;
      await _api.stopCapture();
      setState(() => _activeSource = null);
      if (mounted) {
        _openEditor(sourceId, source);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Error: $e', isError: true);
      }
    }
  }

  void _openEditor(String sourceId, CaptureSource source) {
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory('$home/Downloads');
    if (!dir.existsSync()) return;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('xowcase_'))
        .toList();
    if (files.isEmpty) {
      _windowChannel.invokeMethod('setSize', {'width': 500.0, 'height': 450.0});
      return;
    }

    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    final latestVideo = files.first.path;

    // Resize back to Editor size (it will re-add traffic lights!)
    _windowChannel.invokeMethod('setSize', {'width': 1200.0, 'height': 800.0});

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => EditorScreen(videoPath: latestVideo, source: source),
          ),
        )
        .then((_) {
          // Resize back to Dashboard when editor closes
          _windowChannel.invokeMethod('setSize', {
            'width': 500.0,
            'height': 450.0,
          });
        });
  }
}
