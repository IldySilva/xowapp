import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import '../clipper.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/toast.dart';
import '../src/messages.g.dart';

class EditorScreen extends StatefulWidget {
  final String videoPath;
  final CaptureSource source;
  const EditorScreen({super.key, required this.videoPath, required this.source});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  Color _backgroundColor = Colors.white;
  List<Color>? _backgroundGradient;
  String _resolution = 'Auto (Original)';
  String _quality = '1080p';
  bool _isExporting = false;

  Map<String, dynamic> _framesData = {};
  String? _selectedFramePath;
  String? _videoError;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  double _cropTop = 0.0;
  double _cropBottom = 0.0;
  double _cropLeft = 0.0;
  double _cropRight = 0.0;
  double _padding = 0.15;
  bool _isCustomCrop = false;
  double _borderRadius = 16.0;
  double _shadowOpacity = 0.4;
  double _shadowBlur = 30.0;

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
          if (widget.source.type == 0 || widget.source.type == 1) {
            _selectedFramePath = 'frameless';
            _padding = widget.source.type == 0 ? 0.05 : 0.15;
            _resolution = 'Auto (Original)';
          } else {
            _padding = 0.15;
            _resolution = '9:16 (Story/Reels)';
            final sName = widget.source.name.toLowerCase();
            final matches = data.keys.where((k) {
               final fname = k.split('/').last.split(' - ').first.toLowerCase();
               return sName.contains(fname);
            });
            if (matches.isNotEmpty) {
                _selectedFramePath = matches.firstWhere((k) => k.contains('Portrait'), orElse: () => matches.first);
            } else {
                _selectedFramePath = data.keys.firstWhere(
                  (k) => k.contains('Portrait'),
                  orElse: () => data.keys.first,
                );
            }
          }
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
          Row(
            children: [
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
    else if (_resolution == 'Auto (Original)') {
       if (_selectedFramePath == 'frameless') {
          double videoW = _controller.value.isInitialized ? _controller.value.size.width : 1920;
          double videoH = _controller.value.isInitialized ? _controller.value.size.height : 1080;
          if (videoW == 0) videoW = 1920;
          if (videoH == 0) videoH = 1080;
          ratio = videoW / videoH;
       } else {
          if (_framesData.containsKey(_selectedFramePath)) {
              final bounds = _framesData[_selectedFramePath!];
              double frameW = bounds['frame_w'].toDouble();
              double frameH = bounds['frame_h'].toDouble();
              ratio = frameW / frameH;
          }
       }
    }

    return Expanded(
      child: Container(
        color: const Color(0xFFE5E5EA),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: AspectRatio(
              aspectRatio: ratio,
              child: Container(
                decoration: BoxDecoration(
                color: _backgroundGradient == null ? _backgroundColor : null,
                gradient: _backgroundGradient != null ? LinearGradient(colors: _backgroundGradient!, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 40,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Center(
                    child: _controller.value.isInitialized
                        ? _selectedFramePath == 'frameless'
                            ? _buildFramelessVideo()
                            : _selectedFramePath != null &&
                                      _framesData.containsKey(_selectedFramePath)
                                  ? LayoutBuilder(
                              builder: (context, constraints) {
                                final bounds = _framesData[_selectedFramePath!];
                                double canvasW = constraints.maxWidth;
                                double canvasH = constraints.maxHeight;

                                  double frameScale = 1.0;
                                  if (bounds['frame_w'] > canvasW * (1.0 - _padding) ||
                                      bounds['frame_h'] > canvasH * (1.0 - _padding)) {
                                    final scaleW =
                                        (canvasW * (1.0 - _padding)) / bounds['frame_w'];
                                    final scaleH =
                                        (canvasH * (1.0 - _padding)) / bounds['frame_h'];
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
      ),
    );
  }

  Widget _buildFramelessVideo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double videoW = _controller.value.size.width;
        double videoH = _controller.value.size.height;
        if (videoW == 0) videoW = 1920;
        if (videoH == 0) videoH = 1080;

        double canvasW = constraints.maxWidth;
        double canvasH = constraints.maxHeight;

        double scale = 1.0;
        if (videoW > canvasW * (1.0 - _padding) || videoH > canvasH * (1.0 - _padding)) {
          final scaleW = (canvasW * (1.0 - _padding)) / videoW;
          final scaleH = (canvasH * (1.0 - _padding)) / videoH;
          scale = scaleW < scaleH ? scaleW : scaleH;
        }

        final scaledW = videoW * scale;
        final scaledH = videoH * scale;

        final visibleW = scaledW * (1 - _cropLeft - _cropRight);
        final visibleH = scaledH * (1 - _cropTop - _cropBottom);

        final visibleStartX = (canvasW - visibleW) / 2;
        final visibleStartY = (canvasH - visibleH) / 2;

        return Stack(
          children: [
            Positioned(
              left: visibleStartX,
              top: visibleStartY,
              width: visibleW,
              height: visibleH,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_borderRadius * scale),
                  boxShadow: [
                    if (_shadowOpacity > 0)
                      BoxShadow(
                        color: Colors.black.withOpacity(_shadowOpacity),
                        blurRadius: _shadowBlur * scale,
                        offset: Offset(0, 15 * scale),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_borderRadius * scale),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -scaledW * _cropLeft,
                        top: -scaledH * _cropTop,
                        width: scaledW,
                        height: scaledH,
                        child: VideoPlayer(_controller),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
              onChanged: (val) => setState(() => _searchQuery = val),
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
          if (_framesData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    dropdownColor: Colors.white,
                    items: () {
                      final categories = {'All', 'Frameless'};
                      for (final path in _framesData.keys) {
                        final parts = path.split('/');
                        if (parts.length > 1) {
                          categories.add(parts[1]);
                        }
                      }
                      return categories.toList()..sort();
                    }().map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _framesData.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Builder(builder: (context) {
                    final filteredFrames = _framesData.keys.where((path) {
                      final name = path.split('/').last.replaceAll('.png', '').toLowerCase();
                      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
                      
                      final parts = path.split('/');
                      final category = parts.length > 1 ? parts[1] : '';
                      final matchesCat = _selectedCategory == 'All' || category == _selectedCategory;
                      
                      return matchesSearch && matchesCat;
                    }).toList();
                    
                    if ((_selectedCategory == 'All' || _selectedCategory == 'Frameless') && 
                        (_searchQuery.isEmpty || 'frameless'.contains(_searchQuery.toLowerCase()))) {
                      filteredFrames.insert(0, 'frameless');
                    }
                    
                    if (filteredFrames.isEmpty) {
                      return const Center(
                        child: Text('No frames found', style: TextStyle(color: Colors.black38, fontSize: 13)),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: filteredFrames.length,
                      itemBuilder: (context, index) {
                        final path = filteredFrames[index];
                        final name = path == 'frameless' 
                            ? 'Frameless (Shadow & Radius)' 
                            : path.split('/').last.replaceAll('.png', '');
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
                    );
                  }),
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
          
          _buildSidebarSection(
            'Background',
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _colorButton(const Color(0xFFF5F5F7)), // Light Gray
                _gradientButton([const Color(0xFF8A2387), const Color(0xFFE94057), const Color(0xFFF27121)]), // Sunset
                _gradientButton([const Color(0xFF00C9FF), const Color(0xFF92FE9D)]), // Mint Green
                _gradientButton([const Color(0xFF1CB5E0), const Color(0xFF000046)]), // Deep Sea
                _gradientButton([const Color(0xFFf12711), const Color(0xFFf5af19)]), // Fire
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSidebarSection('Padding', _buildCropSlider('Padding', _padding, (v) => setState(() => _padding = v), 0.5)),
          const SizedBox(height: 24),
          _buildSidebarSection('Resolution', _buildResolutionGrid()),
          const SizedBox(height: 24),
          _buildSidebarSection('Quality', _buildQualityPills()),
          const SizedBox(height: 24),
          _buildSidebarSection('Device Crop', _buildCropGrid()),
          if (_isCustomCrop) ...[
            const SizedBox(height: 12),
            _buildSidebarSection('Custom Crop', _buildCropSliders()),
          ],
          if (_selectedFramePath == 'frameless') ...[
            const SizedBox(height: 24),
            _buildSidebarSection('Border Radius', _buildCropSlider('Radius', _borderRadius, (v) => setState(() => _borderRadius = v), 100.0)),
            const SizedBox(height: 12),
            _buildSidebarSection('Shadow Opacity', _buildCropSlider('Opacity', _shadowOpacity, (v) => setState(() => _shadowOpacity = v), 1.0)),
            const SizedBox(height: 12),
            _buildSidebarSection('Shadow Blur', _buildCropSlider('Blur', _shadowBlur, (v) => setState(() => _shadowBlur = v), 100.0)),
          ],
        ],
      ),
    );
  }

  Widget _buildResolutionGrid() {
    final opts = [
      'Auto (Original)',
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
      'Custom',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opts.map((opt) {
        bool isActive = false;
        if (opt == 'Full Device') isActive = !_isCustomCrop && _cropTop == 0 && _cropBottom == 0 && _cropLeft == 0 && _cropRight == 0;
        else if (opt == 'Top Half') isActive = !_isCustomCrop && _cropTop == 0 && _cropBottom == 0.5 && _cropLeft == 0 && _cropRight == 0;
        else if (opt == 'Bottom Half') isActive = !_isCustomCrop && _cropTop == 0.5 && _cropBottom == 0 && _cropLeft == 0 && _cropRight == 0;
        else if (opt == 'Middle') isActive = !_isCustomCrop && _cropTop == 0.25 && _cropBottom == 0.25 && _cropLeft == 0 && _cropRight == 0;
        else if (opt == 'Custom') isActive = _isCustomCrop;

        return InkWell(
          onTap: () {
            setState(() {
              if (opt == 'Full Device') { _isCustomCrop = false; _cropTop = 0; _cropBottom = 0; _cropLeft = 0; _cropRight = 0; }
              else if (opt == 'Top Half') { _isCustomCrop = false; _cropTop = 0; _cropBottom = 0.5; _cropLeft = 0; _cropRight = 0; }
              else if (opt == 'Bottom Half') { _isCustomCrop = false; _cropTop = 0.5; _cropBottom = 0; _cropLeft = 0; _cropRight = 0; }
              else if (opt == 'Middle') { _isCustomCrop = false; _cropTop = 0.25; _cropBottom = 0.25; _cropLeft = 0; _cropRight = 0; }
              else if (opt == 'Custom') { _isCustomCrop = true; }
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
        final isActive = q == _quality;
        return InkWell(
          onTap: () => setState(() => _quality = q),
          child: Container(
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
    final isActive = _backgroundGradient == null && _backgroundColor == c;
    return InkWell(
      onTap: () => setState(() { _backgroundGradient = null; _backgroundColor = c; }),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black26,
            width: isActive ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _gradientButton(List<Color> colors) {
    final isActive = _backgroundGradient != null && _backgroundGradient![0] == colors[0];
    return InkWell(
      onTap: () => setState(() { _backgroundGradient = colors; }),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.black26,
            width: isActive ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF0A84FF),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 24,
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
          
      final durationSecs = (_controller.value.duration.inMicroseconds / 1000000.0).toStringAsFixed(3);
          
      int canvasW = 1080;
      int canvasH = 1920;

      String bitrate = '8M';
      if (_quality == '720p') bitrate = '5M';
      else if (_quality == '1080p') bitrate = '10M';
      else if (_quality == '4K') bitrate = '25M';

      if (_resolution == '16:9 (YouTube)') {
        canvasW = 1920;
        canvasH = 1080;
      } else if (_resolution == '1:1 (Square)') {
        canvasW = 1080;
        canvasH = 1080;
      } else if (_resolution == '3:4') {
        canvasW = 1080;
        canvasH = 1440;
      } else if (_resolution == 'Auto (Original)') {
          if (_selectedFramePath == 'frameless') {
              double videoW = _controller.value.size.width == 0 ? 1920 : _controller.value.size.width.toDouble();
              double videoH = _controller.value.size.height == 0 ? 1080 : _controller.value.size.height.toDouble();
              double padSafe = _padding > 0.9 ? 0.9 : _padding;
              canvasW = (videoW / (1.0 - padSafe)).toInt();
              canvasH = (videoH / (1.0 - padSafe)).toInt();
          } else {
              final bounds = _framesData[_selectedFramePath!];
              double frameW = bounds['frame_w'].toDouble();
              double frameH = bounds['frame_h'].toDouble();
              double padSafe = _padding > 0.9 ? 0.9 : _padding;
              canvasW = (frameW / (1.0 - padSafe)).toInt();
              canvasH = (frameH / (1.0 - padSafe)).toInt();
          }
          if (canvasW > 3840) {
              double capScale = 3840 / canvasW;
              canvasW = 3840;
              canvasH = (canvasH * capScale).toInt();
          }
          if (canvasW % 2 != 0) canvasW -= 1;
          if (canvasH % 2 != 0) canvasH -= 1;
      }

      final bgPath = '$home/Downloads/xowcase_temp_bg.png';
      final bgRecorder = ui.PictureRecorder();
      final bgCanvas = Canvas(bgRecorder, Rect.fromLTWH(0, 0, canvasW.toDouble(), canvasH.toDouble()));
      if (_backgroundGradient != null) {
         final rect = Rect.fromLTWH(0, 0, canvasW.toDouble(), canvasH.toDouble());
         final stops = [for (int i = 0; i < _backgroundGradient!.length; i++) i / (_backgroundGradient!.length - 1)];
         final paint = Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, _backgroundGradient!, stops);
         bgCanvas.drawRect(rect, paint);
      } else {
         bgCanvas.drawColor(_backgroundColor, BlendMode.srcOver);
      }

      List<String> args;

      if (_selectedFramePath == 'frameless') {
          final videoW = _controller.value.size.width == 0 ? 1920 : _controller.value.size.width.toDouble();
          final videoH = _controller.value.size.height == 0 ? 1080 : _controller.value.size.height.toDouble();
          
          double scale = 1.0;
          if (videoW > canvasW * (1.0 - _padding) || videoH > canvasH * (1.0 - _padding)) {
              final scaleW = (canvasW * (1.0 - _padding)) / videoW;
              final scaleH = (canvasH * (1.0 - _padding)) / videoH;
              scale = scaleW < scaleH ? scaleW : scaleH;
          }
          
          final scaledW = (videoW * scale).toInt();
          final scaledH = (videoH * scale).toInt();
          
          final visibleW = (scaledW * (1 - _cropLeft - _cropRight)).toInt();
          final visibleH = (scaledH * (1 - _cropTop - _cropBottom)).toInt();
          final cropOffsetX = (scaledW * _cropLeft).toInt();
          final cropOffsetY = (scaledH * _cropTop).toInt();
          
          final visibleStartX = (canvasW - visibleW) / 2;
          final visibleStartY = (canvasH - visibleH) / 2;
          
          if (_shadowOpacity > 0) {
              final shadowRect = Rect.fromLTWH(visibleStartX.toDouble(), visibleStartY.toDouble(), visibleW.toDouble(), visibleH.toDouble());
              final shadowPaint = Paint()
                 ..color = Colors.black.withOpacity(_shadowOpacity)
                 ..maskFilter = MaskFilter.blur(BlurStyle.normal, (_shadowBlur * scale) * 0.5);
              bgCanvas.drawRRect(
                 RRect.fromRectAndRadius(
                    shadowRect.translate(0, 15 * scale), 
                    Radius.circular(_borderRadius * scale)
                 ),
                 shadowPaint
              );
          }
          
          final bgImg = await bgRecorder.endRecording().toImage(canvasW, canvasH);
          final bgByteData = await bgImg.toByteData(format: ui.ImageByteFormat.png);
          await File(bgPath).writeAsBytes(bgByteData!.buffer.asUint8List());
          
          final maskPath = '$home/Downloads/xowcase_temp_mask.png';
          final maskRecorder = ui.PictureRecorder();
          final maskCanvas = Canvas(maskRecorder, Rect.fromLTWH(0, 0, scaledW.toDouble(), scaledH.toDouble()));
          maskCanvas.drawColor(Colors.transparent, BlendMode.clear);
          maskCanvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, scaledW.toDouble(), scaledH.toDouble()), Radius.circular(_borderRadius * scale)),
            Paint()..color = Colors.white,
          );
          final maskImg = await maskRecorder.endRecording().toImage(scaledW, scaledH);
          final maskByteData = await maskImg.toByteData(format: ui.ImageByteFormat.png);
          await File(maskPath).writeAsBytes(maskByteData!.buffer.asUint8List());

          args = [
            '-i', widget.videoPath,
            '-framerate', '60', '-loop', '1', '-t', durationSecs, '-i', maskPath,
            '-framerate', '60', '-loop', '1', '-t', durationSecs, '-i', bgPath,
            '-filter_complex',
            '[0:v]scale=$scaledW:$scaledH:force_original_aspect_ratio=increase,crop=$scaledW:$scaledH,format=rgba[vid_scaled];'
            '[1:v]format=rgba[mask];'
            '[vid_scaled][mask]alphamerge[vid_rounded];'
            '[vid_rounded]crop=$visibleW:$visibleH:$cropOffsetX:$cropOffsetY[cropped];'
            '[2:v][cropped]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2:shortest=1[out]',
            '-map', '[out]',
            '-map', '0:a?',
            '-c:v', 'h264_videotoolbox',
            '-c:a', 'aac',
            '-allow_sw', '1',
            '-b:v', bitrate,
            '-y',
            outputPath
          ];
      } else {
          final bgImg = await bgRecorder.endRecording().toImage(canvasW, canvasH);
          final bgByteData = await bgImg.toByteData(format: ui.ImageByteFormat.png);
          await File(bgPath).writeAsBytes(bgByteData!.buffer.asUint8List());

          final frameAssetPath = _selectedFramePath!;
          final frameAssetData = await rootBundle.load(frameAssetPath);
          final tempFramePath = '$home/Downloads/xowcase_temp_frame.png';
          await File(tempFramePath).writeAsBytes(frameAssetData.buffer.asUint8List());
          
          final bounds = _framesData[frameAssetPath];
          
          double frameScale = 1.0;
          if (bounds['frame_w'] > canvasW * (1.0 - _padding) ||
              bounds['frame_h'] > canvasH * (1.0 - _padding)) {
            final scaleW = (canvasW * (1.0 - _padding)) / bounds['frame_w'];
            final scaleH = (canvasH * (1.0 - _padding)) / bounds['frame_h'];
            frameScale = scaleW < scaleH ? scaleW : scaleH;
          }

          final scaledFrameW = (bounds['frame_w'] * frameScale).toInt();
          final scaledFrameH = (bounds['frame_h'] * frameScale).toInt();

          final inset = 0;
          final scaledHoleX = (bounds['x'] * frameScale).toInt() + inset;
          final scaledHoleY = (bounds['y'] * frameScale).toInt() + inset;
          final scaledHoleW = (bounds['w'] * frameScale).toInt() - (inset * 2);
          final scaledHoleH = (bounds['h'] * frameScale).toInt() - (inset * 2);

          final visibleW = (scaledFrameW * (1 - _cropLeft - _cropRight)).toInt();
          final visibleH = (scaledFrameH * (1 - _cropTop - _cropBottom)).toInt();
          final cropOffsetX = (scaledFrameW * _cropLeft).toInt();
          final cropOffsetY = (scaledFrameH * _cropTop).toInt();

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

          args = [
            '-i', widget.videoPath,
            '-framerate', '60', '-loop', '1', '-t', durationSecs, '-i', tempFramePath,
            '-framerate', '60', '-loop', '1', '-t', durationSecs, '-i', maskPath,
            '-framerate', '60', '-loop', '1', '-t', durationSecs, '-i', bgPath,
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
            '-map', '[out]',
            '-map', '0:a?',
            '-c:v', 'h264_videotoolbox',
            '-c:a', 'aac',
            '-allow_sw', '1',
            '-b:v', bitrate,
            '-y',
            outputPath,
          ];
      }

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
