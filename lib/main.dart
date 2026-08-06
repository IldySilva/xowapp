import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'src/messages.g.dart';

void main() {
  runApp(const ReelBrickApp());
}

class ReelBrickApp extends StatelessWidget {
  const ReelBrickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReelBrick',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const CaptureScreen(),
    );
  }
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final CaptureApi _api = CaptureApi();
  List<CaptureSource> _sources = [];
  bool _isLoading = true;
  String? _error;
  
  CaptureSource? _activeSource;
  int? _previewTextureId;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    try {
      final sources = await _api.getAvailableSources();
      setState(() {
        _sources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReelBrick Capture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadSources();
            },
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_sources.isEmpty) {
      return const Center(child: Text('No capture sources found.'));
    }

    return ListView.builder(
      itemCount: _sources.length,
      itemBuilder: (context, index) {
        final source = _sources[index];
        IconData icon;
        switch (source.type) {
          case 0:
            icon = Icons.monitor;
            break;
          case 1:
            icon = Icons.window;
            break;
          case 2:
            icon = Icons.phone_iphone;
            break;
          default:
            icon = Icons.device_unknown;
        }

        return ListTile(
          leading: Icon(icon),
          title: Text(source.name),
          subtitle: Text('ID: ${source.id}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_previewTextureId == null)
                IconButton(
                  icon: const Icon(Icons.visibility),
                  tooltip: 'Live Preview',
                  onPressed: () async {
                    try {
                      final textureId = await _api.startPreview(source.id, source.type);
                      setState(() {
                        _previewTextureId = textureId;
                      });
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Preview: ${source.name}'),
                            content: SizedBox(
                              width: 600,
                              height: 400,
                              child: Texture(textureId: textureId),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _api.stopPreview(textureId);
                                  setState(() {
                                    _previewTextureId = null;
                                  });
                                },
                                child: const Text('Close Preview'),
                              ),
                            ],
                          ),
                        ).then((_) {
                          if (_previewTextureId != null) {
                            _api.stopPreview(_previewTextureId!);
                            setState(() {
                              _previewTextureId = null;
                            });
                          }
                        });
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preview error: $e')));
                      }
                    }
                  },
                ),
              const SizedBox(width: 8),
              _activeSource == source
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        try {
                          final sourceId = _activeSource!.id;
                          await _api.stopCapture();
                          setState(() {
                            _activeSource = null;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Recording saved!')),
                            );
                            // Transition to Editor / Epic 3
                            _openEditor(sourceId);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error stopping: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Stop'),
                    )
                  : ElevatedButton(
                      onPressed: _activeSource != null
                          ? null
                          : () async {
                              if (source.type != 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ScreenCaptureKit not fully implemented yet, use Simulator!')),
                                );
                                return;
                              }
                              try {
                                final home = Platform.environment['HOME'] ?? '';
                                final outputPath = '$home/Downloads/reelbrick_${DateTime.now().millisecondsSinceEpoch}.mp4';
                                await _api.startCapture(source.id, source.type, outputPath);
                                setState(() {
                                  _activeSource = source;
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Recording started: $outputPath')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error starting: $e')),
                                  );
                                }
                              }
                            },
                      child: const Text('Record'),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _openEditor(String sourceId) {
    // For now, we will just grab the latest file we saved
    // Ideally we would return the explicit path from the stopCapture logic
    final home = Platform.environment['HOME'] ?? '';
    // We get the most recent file in Downloads that matches reelbrick
    final dir = Directory('$home/Downloads');
    if (!dir.existsSync()) return;
    
    final files = dir.listSync()
        .whereType<File>()
        .where((f) => f.path.contains('reelbrick_'))
        .toList();
        
    if (files.isEmpty) return;
    
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final latestVideo = files.first.path;

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(videoPath: latestVideo)));
  }
}

class EditorScreen extends StatefulWidget {
  final String videoPath;
  const EditorScreen({super.key, required this.videoPath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  Color _backgroundColor = const Color(0xFF1C1C1E);
  String _resolution = '9:16 (Story/Reels)';
  bool _isExporting = false;
  
  Map<String, dynamic> _framesData = {};
  String? _selectedFramePath;
  
  @override
  void initState() {
    super.initState();
    _loadFrames();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
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
            orElse: () => data.keys.first
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
      backgroundColor: const Color(0xFF0D0D0D), // Ultra dark background for pro feel
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              children: [
                _buildCanvas(),
                _buildPropertySidebar(),
              ],
            ),
          ),
          _buildTimeline(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text('Project: Untitled Demo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportVideo,
            icon: _isExporting 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.ios_share, size: 16, color: Colors.white),
            label: Text(_isExporting ? 'Exporting...' : 'Export', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Expanded(
      child: Container(
        color: const Color(0xFF121212),
        child: Center(
          child: AspectRatio(
            aspectRatio: _resolution == '9:16 (Story/Reels)' ? 9 / 16 : 16 / 9,
            child: Container(
              margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 40, offset: Offset(0, 20)),
                ],
              ),
              child: Center(
                child: _controller.value.isInitialized
                    ? _selectedFramePath != null && _framesData.containsKey(_selectedFramePath)
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final bounds = _framesData[_selectedFramePath!];
                              double canvasW = constraints.maxWidth;
                              double canvasH = constraints.maxHeight;
                              
                              double frameScale = 1.0;
                              if (bounds['frame_w'] > canvasW * 0.85 || bounds['frame_h'] > canvasH * 0.85) {
                                final scaleW = (canvasW * 0.85) / bounds['frame_w'];
                                final scaleH = (canvasH * 0.85) / bounds['frame_h'];
                                frameScale = scaleW < scaleH ? scaleW : scaleH;
                              }
                              
                              final scaledFrameW = bounds['frame_w'] * frameScale;
                              final scaledFrameH = bounds['frame_h'] * frameScale;
                              final scaledHoleX = bounds['x'] * frameScale;
                              final scaledHoleY = bounds['y'] * frameScale;
                              final scaledHoleW = bounds['w'] * frameScale;
                              final scaledHoleH = bounds['h'] * frameScale;
                              
                              final globalFrameX = (canvasW - scaledFrameW) / 2;
                              final globalFrameY = (canvasH - scaledFrameH) / 2;
                              
                              final absVidX = globalFrameX + scaledHoleX;
                              final absVidY = globalFrameY + scaledHoleY;

                              return Stack(
                                children: [
                                  Positioned(
                                    left: absVidX,
                                    top: absVidY,
                                    width: scaledHoleW,
                                    height: scaledHoleH,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(44 * frameScale),
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _controller.value.size.width == 0 ? 100 : _controller.value.size.width,
                                          height: _controller.value.size.height == 0 ? 100 : _controller.value.size.height,
                                          child: VideoPlayer(_controller),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: globalFrameX,
                                    top: globalFrameY,
                                    width: scaledFrameW,
                                    height: scaledFrameH,
                                    child: IgnorePointer(
                                      child: Image.asset(_selectedFramePath!, fit: BoxFit.fill),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        : const CircularProgressIndicator(color: Colors.white)
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertySidebar() {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(left: BorderSide(color: Color(0xFF2C2C2E), width: 1)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Canvas Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          
          _buildSidebarSection(
            'Resolution',
            DropdownButtonFormField<String>(
              value: _resolution,
              dropdownColor: const Color(0xFF2C2C2E),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              items: ['9:16 (Story/Reels)', '16:9 (YouTube)', '1:1 (Square)'].map((String val) {
                return DropdownMenuItem(value: val, child: Text(val));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _resolution = val);
              },
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSidebarSection(
            'Background',
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _colorButton(const Color(0xFF1C1C1E)),
                _colorButton(const Color(0xFF5E5CE6)),
                _colorButton(const Color(0xFFFF9F0A)),
                _colorButton(const Color(0xFFFF375F)),
                _colorButton(const Color(0xFF32ADE6)),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSidebarSection(
            'Device Mockup',
            _framesData.isEmpty 
              ? const CircularProgressIndicator()
              : DropdownButtonFormField<String>(
                  value: _selectedFramePath,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2C2C2E),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: _framesData.keys.map((String path) {
                    final name = path.split('/').last.replaceAll('.png', '');
                    return DropdownMenuItem(value: path, child: Text(name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFramePath = val);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _colorButton(Color c) {
    return InkWell(
      onTap: () => setState(() => _backgroundColor = c),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: _backgroundColor == c ? 2 : 0),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      height: 140,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2E), width: 1)),
      ),
      child: Column(
        children: [
          // Playback controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                ),
                const SizedBox(width: 16),
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, VideoPlayerValue value, child) {
                    final position = value.position.toString().split('.').first;
                    final duration = value.duration.toString().split('.').first;
                    return Text('$position / $duration', style: const TextStyle(color: Colors.white70, fontFamily: 'Monospace', fontSize: 12));
                  },
                ),
                const Spacer(),
                const Text('Trim/Cut (Em Breve)', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          
          // Timeline tracks
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Fake video track waveform
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E5CE6).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF5E5CE6), width: 1),
                        ),
                      ),
                    ),
                  ),
                  // Fake playhead
                  Positioned(
                    left: 100,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white),
                  ),
                  Positioned(
                    left: 92,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
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
      final outputPath = '$home/Downloads/ReelBrick_Export_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final framePath = _selectedFramePath!;
      final bounds = _framesData[framePath];
      
      int canvasW = 1080;
      int canvasH = 1920;
      if (_resolution == '16:9 (YouTube)') {
        canvasW = 1920; canvasH = 1080;
      } else if (_resolution == '1:1 (Square)') {
        canvasW = 1080; canvasH = 1080;
      }
      
      final colorHex = _backgroundColor.value.toRadixString(16).substring(2).toUpperCase();
      
      // Calculate video scale and position based on the frame's transparent bounds
      // We want the frame to fit inside the canvas (e.g. 85% of canvas size)
      // So first we find the scale factor for the frame itself
      double frameScale = 1.0;
      if (bounds['frame_w'] > canvasW * 0.85 || bounds['frame_h'] > canvasH * 0.85) {
        final scaleW = (canvasW * 0.85) / bounds['frame_w'];
        final scaleH = (canvasH * 0.85) / bounds['frame_h'];
        frameScale = scaleW < scaleH ? scaleW : scaleH;
      }
      
      final scaledFrameW = (bounds['frame_w'] * frameScale).toInt();
      final scaledFrameH = (bounds['frame_h'] * frameScale).toInt();
      
      final scaledHoleX = (bounds['x'] * frameScale).toInt();
      final scaledHoleY = (bounds['y'] * frameScale).toInt();
      final scaledHoleW = (bounds['w'] * frameScale).toInt();
      final scaledHoleH = (bounds['h'] * frameScale).toInt();
      
      // Calculate the global offsets on the canvas for the frame
      final globalFrameX = (canvasW - scaledFrameW) / 2;
      final globalFrameY = (canvasH - scaledFrameH) / 2;
      
      // The absolute position of the video on the canvas is the frame's global position + hole offset
      final absVidX = (globalFrameX + scaledHoleX).toInt();
      final absVidY = (globalFrameY + scaledHoleY).toInt();

      // Generate a mask for the video to give it perfectly rounded corners in FFmpeg
      final maskPath = '$home/Downloads/reelbrick_temp_mask.png';
      final maskRecorder = ui.PictureRecorder();
      final maskCanvas = Canvas(maskRecorder, Rect.fromLTWH(0, 0, scaledHoleW.toDouble(), scaledHoleH.toDouble()));
      maskCanvas.drawColor(Colors.transparent, BlendMode.clear);
      final maskPaint = Paint()..color = Colors.white;
      maskCanvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, scaledHoleW.toDouble(), scaledHoleH.toDouble()),
          Radius.circular(44 * frameScale),
        ),
        maskPaint,
      );
      final maskPic = maskRecorder.endRecording();
      final maskImg = await maskPic.toImage(scaledHoleW, scaledHoleH);
      final maskByteData = await maskImg.toByteData(format: ui.ImageByteFormat.png);
      await File(maskPath).writeAsBytes(maskByteData!.buffer.asUint8List());

      final args = [
        '-i', widget.videoPath,
        '-i', framePath,
        '-i', maskPath,
        '-f', 'lavfi',
        '-i', 'color=c=#$colorHex:s=${canvasW}x${canvasH}',
        '-filter_complex', 
        '[0:v]scale=$scaledHoleW:$scaledHoleH:force_original_aspect_ratio=increase,crop=$scaledHoleW:$scaledHoleH,format=rgba[vid_scaled];'
        '[2:v]format=rgba[mask];'
        '[vid_scaled][mask]alphamerge[vid_rounded];'
        '[1:v]scale=$scaledFrameW:$scaledFrameH[frame];'
        '[3:v][vid_rounded]overlay=$absVidX:$absVidY:shortest=1[bgAndVid];'
        '[bgAndVid][frame]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2',
        '-map', '0:a?',
        '-c:v', 'h264_videotoolbox',
        '-c:a', 'aac',
        '-allow_sw', '1',
        '-b:v', '8M',
        '-y',
        outputPath
      ];
      
      final result = await Process.run('/opt/homebrew/bin/ffmpeg', args);
      
      if (result.exitCode == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exportado com sucesso para: $outputPath'), duration: const Duration(seconds: 5)),
          );
        }
      } else {
        print("FFMPEG ERROR: ${result.stderr}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao exportar! Veja os logs do terminal.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
