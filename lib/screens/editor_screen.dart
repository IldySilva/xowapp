import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import '../clipper.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/toast.dart';
class EditorScreen extends StatefulWidget {
  final String videoPath;
  const EditorScreen({super.key, required this.videoPath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  Color _backgroundColor = Colors.white;
  String _resolution = '9:16 (Story/Reels)';
  bool _isExporting = false;

  Map<String, dynamic> _framesData = {};
  String? _selectedFramePath;
  String? _videoError;

  double _cropTop = 0.0;
  double _cropBottom = 0.0;
  double _cropLeft = 0.0;
  double _cropRight = 0.0;

  @override
  void initState() {
    super.initState();
    _loadFrames();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      }).catchError((e) {
        setState(() {
          _videoError = e.toString();
        });
      });
  }

  Future<void> _loadFrames() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/frames.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _framesData = data;
        if (data.isNotEmpty) {
          // Find a default portrait frame if possible
          _selectedFramePath = data.keys.firstWhere(
            (k) => k.contains('Portrait'),
            orElse: () => data.keys.first,
          );
        }
      });
    } catch (e) {
      print("Error loading frames.json: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 500 || constraints.maxWidth < 800) {
            return const Center(
              child: Text(
                'Please enlarge window to use XowCase',
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }
          return Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildTopToolbar(),
                    Expanded(
                      child: Row(
                        children: [
                          _buildAssetsPanel(),
                          _buildCanvas(),
                          _buildInspector(),
                        ],
                      ),
                    ),
                    _buildTimeline(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
      ),
      padding: const EdgeInsets.only(left: 80, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  size: 16,
                  color: Colors.black87,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'Project: Xowcase',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.near_me_outlined,
                      size: 20,
                      color: Colors.black87,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.text_fields,
                      size: 20,
                      color: Colors.black54,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.devices,
                      size: 20,
                      color: Colors.black54,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.bookmark_border,
                      size: 20,
                      color: Colors.black54,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.ios_share,
                  size: 20,
                  color: Colors.black54,
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportVideo,
                icon: _isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download, size: 16, color: Colors.white),
                label: Text(
                  _isExporting ? 'Exporting...' : 'Export',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    double ratio = 9 / 16;
    if (_resolution == '16:9 (YouTube)') ratio = 16 / 9;
    else if (_resolution == '1:1 (Square)') ratio = 1.0;
    else if (_resolution == '3:4') ratio = 3 / 4;

    return Expanded(
      child: Container(
        color: const Color(0xFFE5E5EA),
        child: Center(
          child: AspectRatio(
            aspectRatio: ratio,
            child: Container(
              margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 40,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Center(
                child: _controller.value.isInitialized
                    ? _selectedFramePath != null &&
                              _framesData.containsKey(_selectedFramePath)
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final bounds = _framesData[_selectedFramePath!];
                                double canvasW = constraints.maxWidth;
                                double canvasH = constraints.maxHeight;

                                double frameScale = 1.0;
                                if (bounds['frame_w'] > canvasW * 0.85 ||
                                    bounds['frame_h'] > canvasH * 0.85) {
                                  final scaleW =
                                      (canvasW * 0.85) / bounds['frame_w'];
                                  final scaleH =
                                      (canvasH * 0.85) / bounds['frame_h'];
                                  frameScale = scaleW < scaleH
                                      ? scaleW
                                      : scaleH;
                                }

                                final scaledFrameW =
                                    bounds['frame_w'] * frameScale;
                                final scaledFrameH =
                                    bounds['frame_h'] * frameScale;

                                // Add a small inset to hide the video deeply behind the bezel
                                final inset = 0.0;
                                final scaledHoleX =
                                    (bounds['x'] * frameScale) + inset;
                                final scaledHoleY =
                                    (bounds['y'] * frameScale) + inset;
                                final scaledHoleW =
                                    (bounds['w'] * frameScale) - (inset * 2);
                                final scaledHoleH =
                                    (bounds['h'] * frameScale) - (inset * 2);

                                final visibleW = scaledFrameW * (1 - _cropLeft - _cropRight);
                                final visibleH = scaledFrameH * (1 - _cropTop - _cropBottom);

                                final visibleStartX = (canvasW - visibleW) / 2;
                                final visibleStartY = (canvasH - visibleH) / 2;

                                final globalFrameX = visibleStartX - (scaledFrameW * _cropLeft);
                                final globalFrameY = visibleStartY - (scaledFrameH * _cropTop);

                                return Stack(
                                  children: [
                                    Positioned(
                                      left: globalFrameX,
                                      top: globalFrameY,
                                      width: scaledFrameW,
                                      height: scaledFrameH,
                                      child: ClipRect(
                                        clipper: DeviceClipper(
                                          top: _cropTop,
                                          bottom: _cropBottom,
                                          left: _cropLeft,
                                          right: _cropRight,
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              left: scaledHoleX,
                                              top: scaledHoleY,
                                              width: scaledHoleW,
                                              height: scaledHoleH,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(
                                                  120 * frameScale,
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.cover,
                                                  child: SizedBox(
                                                    width:
                                                        _controller.value.size.width ==
                                                            0
                                                        ? 100
                                                        : _controller.value.size.width,
                                                    height:
                                                        _controller.value.size.height ==
                                                            0
                                                        ? 100
                                                        : _controller.value.size.height,
                                                    child: VideoPlayer(_controller),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              width: scaledFrameW,
                                              height: scaledFrameH,
                                              child: IgnorePointer(
                                                child: Image.asset(
                                                  _selectedFramePath!,
                                                  fit: BoxFit.fill,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          : const CircularProgressIndicator(color: Colors.black)
                    : _videoError != null
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Video Error: $_videoError',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const CircularProgressIndicator(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetsPanel() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Device Frames',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search frames...',
                hintStyle: const TextStyle(color: Colors.black38),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.black38,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                isDense: true,
                contentPadding: const EdgeInsets.all(8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _framesData.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _framesData.keys.length,
                    itemBuilder: (context, index) {
                      final path = _framesData.keys.elementAt(index);
                      final name = path.split('/').last.replaceAll('.png', '');
                      final isSelected = _selectedFramePath == path;
                      return InkWell(
                        onTap: () => setState(() => _selectedFramePath = path),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: isSelected
                              ? const Color(0xFF0A84FF).withOpacity(0.1)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? const Color(0xFF0A84FF)
                                    : Colors.black26,
                                size: 16,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.black87
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspector() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Export Settings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          _buildSidebarSection('Resolution', _buildResolutionGrid()),
          const SizedBox(height: 24),
          _buildSidebarSection('Device Crop', _buildCropGrid()),
          const SizedBox(height: 12),
          _buildSidebarSection('Custom Crop', _buildCropSliders()),
          const SizedBox(height: 24),
          _buildSidebarSection('Quality', _buildQualityPills()),
          const SizedBox(height: 24),
          _buildSidebarSection(
            'Background Color',
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _colorButton(Colors.white),
                _colorButton(const Color(0xFFF5F5F7)),
                _colorButton(const Color(0xFF5E5CE6)),
                _colorButton(const Color(0xFFFF9F0A)),
                _colorButton(const Color(0xFFFF375F)),
                _colorButton(const Color(0xFF32ADE6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionGrid() {
    final opts = [
      '9:16 (Story/Reels)',
      '3:4',
      '1:1 (Square)',
      '16:9 (YouTube)',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opts.map((opt) {
        final isActive = _resolution == opt;
        return InkWell(
          onTap: () => setState(() => _resolution = opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF0A84FF).withOpacity(0.1)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? const Color(0xFF0A84FF) : Colors.transparent,
              ),
            ),
            child: Text(
              opt.split(' ').first,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF0A84FF) : Colors.black87,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCropGrid() {
    final opts = [
      'Full Device',
      'Top Half',
      'Bottom Half',
      'Middle',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opts.map((opt) {
        bool isActive = false;
        if (opt == 'Full Device') isActive = _cropTop == 0 && _cropBottom == 0 && _cropLeft == 0 && _cropRight == 0;
        else if (opt == 'Top Half') isActive = _cropTop == 0 && _cropBottom == 0.5 && _cropLeft == 0 && _cropRight == 0;
        else if (opt == 'Bottom Half') isActive = _cropTop == 0.5 && _cropBottom == 0 && _cropLeft == 0 && _cropRight == 0;
        else if (opt == 'Middle') isActive = _cropTop == 0.25 && _cropBottom == 0.25 && _cropLeft == 0 && _cropRight == 0;

        return InkWell(
          onTap: () {
            setState(() {
              if (opt == 'Full Device') { _cropTop = 0; _cropBottom = 0; _cropLeft = 0; _cropRight = 0; }
              else if (opt == 'Top Half') { _cropTop = 0; _cropBottom = 0.5; _cropLeft = 0; _cropRight = 0; }
              else if (opt == 'Bottom Half') { _cropTop = 0.5; _cropBottom = 0; _cropLeft = 0; _cropRight = 0; }
              else if (opt == 'Middle') { _cropTop = 0.25; _cropBottom = 0.25; _cropLeft = 0; _cropRight = 0; }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF0A84FF).withOpacity(0.1)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? const Color(0xFF0A84FF) : Colors.transparent,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF0A84FF) : Colors.black87,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCropSliders() {
    return Column(
      children: [
        _buildCropSlider('Top', _cropTop, (v) => setState(() => _cropTop = v), 1.0 - _cropBottom - 0.05),
        _buildCropSlider('Bottom', _cropBottom, (v) => setState(() => _cropBottom = v), 1.0 - _cropTop - 0.05),
        _buildCropSlider('Left', _cropLeft, (v) => setState(() => _cropLeft = v), 1.0 - _cropRight - 0.05),
        _buildCropSlider('Right', _cropRight, (v) => setState(() => _cropRight = v), 1.0 - _cropLeft - 0.05),
      ],
    );
  }

  Widget _buildCropSlider(String label, double val, Function(double) onChanged, double maxVal) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))),
        Expanded(
          child: Slider(
            value: val > maxVal ? maxVal : val,
            min: 0.0,
            max: maxVal < 0.1 ? 0.1 : maxVal,
            onChanged: onChanged,
            activeColor: const Color(0xFF0A84FF),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityPills() {
    return Row(
      children: ['720p', '1080p', '4K'].map((q) {
        final isActive = q == '1080p';
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0A84FF) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            q,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.white : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSidebarSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _colorButton(Color c) {
    return InkWell(
      onTap: () => setState(() => _backgroundColor = c),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black26,
            width: _backgroundColor == c ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.undo,
                        size: 18,
                        color: Colors.black54,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.redo,
                        size: 18,
                        color: Colors.black54,
                      ),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.cut,
                        size: 18,
                        color: Colors.black54,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous,
                        size: 20,
                        color: Colors.black87,
                      ),
                      onPressed: () {},
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A84FF),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next,
                        size: 20,
                        color: Colors.black87,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.loop,
                        size: 18,
                        color: Colors.black54,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.zoom_out_map,
                        size: 18,
                        color: Colors.black54,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.black54,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tracks Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Main Video Track
                  Positioned(
                    top: 16,
                    left: 100,
                    right: 40,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0A84FF),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Screen Capture.mp4',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Device Frame Modifier Track
                  Positioned(
                    top: 60,
                    left: 100,
                    right: 120,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: const Center(
                        child: Text(
                          'Device Frame: Active',
                          style: TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ),
                    ),
                  ),
                  // Playhead
                  Positioned(
                    left: 140,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: const Color(0xFF0A84FF)),
                  ),
                  Positioned(
                    left: 136,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A84FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportVideo() async {
    if (_selectedFramePath == null) return;

    setState(() => _isExporting = true);
    try {
      final home = Platform.environment['HOME'] ?? '';
      final outputPath =
          '$home/Downloads/Xowcase_Export_${DateTime.now().millisecondsSinceEpoch}.mp4';
          
      // Copy asset frame to an absolute temporary path so ffmpeg can read it in Release mode
      final frameAssetPath = _selectedFramePath!;
      final frameAssetData = await rootBundle.load(frameAssetPath);
      final tempFramePath = '$home/Downloads/xowcase_temp_frame.png';
      await File(tempFramePath).writeAsBytes(frameAssetData.buffer.asUint8List());
      
      final bounds = _framesData[frameAssetPath];

      int canvasW = 1080;
      int canvasH = 1920;
      if (_resolution == '16:9 (YouTube)') {
        canvasW = 1920;
        canvasH = 1080;
      } else if (_resolution == '1:1 (Square)') {
        canvasW = 1080;
        canvasH = 1080;
      } else if (_resolution == '3:4') {
        canvasW = 1080;
        canvasH = 1440;
      }

      final colorHex = _backgroundColor.value
          .toRadixString(16)
          .substring(2)
          .toUpperCase();

      // Calculate video scale and position based on the frame's transparent bounds
      // We want the frame to fit inside the canvas (e.g. 85% of canvas size)
      // So first we find the scale factor for the frame itself
      double frameScale = 1.0;
      if (bounds['frame_w'] > canvasW * 0.85 ||
          bounds['frame_h'] > canvasH * 0.85) {
        final scaleW = (canvasW * 0.85) / bounds['frame_w'];
        final scaleH = (canvasH * 0.85) / bounds['frame_h'];
        frameScale = scaleW < scaleH ? scaleW : scaleH;
      }

      final scaledFrameW = (bounds['frame_w'] * frameScale).toInt();
      final scaledFrameH = (bounds['frame_h'] * frameScale).toInt();

      // Add a small inset to perfectly hide the video edges behind the device bezel
      final inset = 0;
      final scaledHoleX = (bounds['x'] * frameScale).toInt() + inset;
      final scaledHoleY = (bounds['y'] * frameScale).toInt() + inset;
      final scaledHoleW = (bounds['w'] * frameScale).toInt() - (inset * 2);
      final scaledHoleH = (bounds['h'] * frameScale).toInt() - (inset * 2);

      // The crop values
      final visibleW = (scaledFrameW * (1 - _cropLeft - _cropRight)).toInt();
      final visibleH = (scaledFrameH * (1 - _cropTop - _cropBottom)).toInt();
      final cropOffsetX = (scaledFrameW * _cropLeft).toInt();
      final cropOffsetY = (scaledFrameH * _cropTop).toInt();

      // Generate a mask for the video to give it perfectly rounded corners in FFmpeg
      final maskPath = '$home/Downloads/xowcase_temp_mask.png';
      final maskRecorder = ui.PictureRecorder();
      final maskCanvas = Canvas(
        maskRecorder,
        Rect.fromLTWH(0, 0, scaledHoleW.toDouble(), scaledHoleH.toDouble()),
      );
      maskCanvas.drawColor(Colors.transparent, BlendMode.clear);
      final maskPaint = Paint()..color = Colors.white;
      maskCanvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, scaledHoleW.toDouble(), scaledHoleH.toDouble()),
          Radius.circular(120 * frameScale),
        ),
        maskPaint,
      );
      final maskPic = maskRecorder.endRecording();
      final maskImg = await maskPic.toImage(scaledHoleW, scaledHoleH);
      final maskByteData = await maskImg.toByteData(
        format: ui.ImageByteFormat.png,
      );
      await File(maskPath).writeAsBytes(maskByteData!.buffer.asUint8List());

      final args = [
        '-i',
        widget.videoPath,
        '-i',
        tempFramePath,
        '-i',
        maskPath,
        '-f',
        'lavfi',
        '-i',
        'color=c=#$colorHex:s=${canvasW}x${canvasH}:r=60',
        '-filter_complex',
        '[0:v]scale=$scaledHoleW:$scaledHoleH:force_original_aspect_ratio=increase,crop=$scaledHoleW:$scaledHoleH,format=rgba[vid_scaled];'
            '[2:v]format=rgba[mask];'
            '[vid_scaled][mask]alphamerge[vid_rounded];'
            '[1:v]scale=$scaledFrameW:$scaledFrameH[frame];'
            'color=c=black@0:s=${scaledFrameW}x${scaledFrameH}:r=60,format=rgba[transparent_bg];'
            '[transparent_bg][vid_rounded]overlay=$scaledHoleX:$scaledHoleY:shortest=1[device_with_vid];'
            '[device_with_vid][frame]overlay=0:0[full_device];'
            '[full_device]crop=$visibleW:$visibleH:$cropOffsetX:$cropOffsetY[cropped_device];'
            '[3:v][cropped_device]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2:shortest=1[out]',
        '-map',
        '[out]',
        '-map',
        '0:a?',
        '-c:v',
        'h264_videotoolbox',
        '-c:a',
        'aac',
        '-allow_sw',
        '1',
        '-b:v',
        '8M',
        '-y',
        outputPath,
      ];

      ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text(
            "Exporting Video",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (context, val, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: val > 0 ? val : null,
                    backgroundColor: const Color(0xFFE5E5EA),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    val > 0 ? "${(val * 100).toStringAsFixed(1)}%" : "Starting...",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
        ),
      );

      final process = await Process.start('/opt/homebrew/bin/ffmpeg', args);
      final durationMicros = _controller.value.duration.inMicroseconds.toDouble();
      final timeRegex = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)');

      process.stderr.transform(utf8.decoder).listen((line) {
        final match = timeRegex.firstMatch(line);
        if (match != null) {
          final hours = int.parse(match.group(1)!);
          final minutes = int.parse(match.group(2)!);
          final seconds = double.parse(match.group(3)!);
          final currentMicros = (hours * 3600 + minutes * 60 + seconds) * 1000000;
          
          if (durationMicros > 0) {
            double p = currentMicros / durationMicros;
            if (p > 1.0) p = 1.0;
            progressNotifier.value = p;
          }
        }
      });

      final exitCode = await process.exitCode;
      
      // Close the dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (exitCode == 0) {
        if (mounted) {
          showToast(context, 'Exportado com sucesso para: $outputPath');
        }
      } else {
        if (mounted) {
          showToast(context, 'Erro ao exportar! Veja os logs do terminal.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Erro: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
