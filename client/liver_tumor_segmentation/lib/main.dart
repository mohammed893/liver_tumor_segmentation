import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'models/nifti_volume.dart';
import 'services/nifti_loader.dart';
import 'services/segmentation_service.dart';
import 'utils/image_processor.dart';
import 'widgets/slice_viewer.dart';

void main() {
  runApp(const LiverSegmentationApp());
}

class LiverSegmentationApp extends StatelessWidget {
  const LiverSegmentationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CT Liver Tumor Segmentation',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const CTViewerPage(),
    );
  }
}

class CTViewerPage extends StatefulWidget {
  const CTViewerPage({super.key});

  @override
  State<CTViewerPage> createState() => _CTViewerPageState();
}

class _CTViewerPageState extends State<CTViewerPage> {
  // Core data
  NiftiVolume? _volume;
  int _currentSlice = 0;
  Uint8List? _currentSliceData;
  Uint8List? _maskData;
  bool _isLoading = false;
  String _statusMessage = '';
  
  // Window/Level settings
  double _windowMin = -1000;
  double _windowMax = 1000;
  WindowLevelPreset? _selectedPreset;
  
  // Image processing settings
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _maskOpacity = 0.7;
  bool _showMask = true;
  
  // Filter settings
  bool _applyGaussianBlur = false;
  bool _applySharpen = false;
  bool _applyEdgeDetection = false;
  bool _applyCLAHE = false;
  double _blurRadius = 1.0;
  
  // API settings
  String _apiEndpoint = 'http://localhost:8000/segment';
  
  @override
  void initState() {
    super.initState();
    _updateSliceDisplay();
  }
  
  /// Load NIfTI file
  Future<void> _loadNiftiFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['nii', 'gz'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'Loading NIfTI file...';
        });
        
        final volume = await NiftiLoader.loadNiftiFile(result.files.single.path!);
        
        setState(() {
          _volume = volume;
          _currentSlice = volume.depth ~/ 2; // Start at middle slice
          _windowMin = volume.minValue.toDouble();
          _windowMax = volume.maxValue.toDouble();
          _isLoading = false;
          _statusMessage = 'Loaded ${volume.width}x${volume.height}x${volume.depth} volume';
          _maskData = null;
        });
        
        _updateSliceDisplay();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading file: $e';
      });
    }
  }
  
  /// Update current slice display with all processing
  void _updateSliceDisplay() {
    if (_volume == null) {
      _currentSliceData = null;
      return;
    }
    
    // Get raw slice data
    final rawSlice = _volume!.getSlice(_currentSlice);
    
    // Apply window/level
    var processedData = ImageProcessor.applyWindowLevel(
      rawSlice,
      _volume!.width,
      _volume!.height,
      _windowMin,
      _windowMax,
    );
    
    // Apply brightness/contrast
    processedData = ImageProcessor.applyBrightnessContrast(
      processedData,
      _brightness,
      _contrast,
    );
    
    // Apply filters
    if (_applyGaussianBlur) {
      processedData = ImageProcessor.applyGaussianBlur(
        processedData,
        _volume!.width,
        _volume!.height,
        _blurRadius,
      );
    }
    
    if (_applySharpen) {
      processedData = ImageProcessor.applySharpen(
        processedData,
        _volume!.width,
        _volume!.height,
      );
    }
    
    if (_applyEdgeDetection) {
      processedData = ImageProcessor.applyEdgeDetection(
        processedData,
        _volume!.width,
        _volume!.height,
      );
    }
    
    if (_applyCLAHE) {
      processedData = ImageProcessor.applyCLAHE(
        processedData,
        _volume!.width,
        _volume!.height,
      );
    }
    
    setState(() {
      _currentSliceData = processedData;
    });
  }
  
  /// Apply window/level preset
  void _applyPreset(WindowLevelPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _windowMin = preset.windowMin;
      _windowMax = preset.windowMax;
    });
    _updateSliceDisplay();
  }
  
  /// Segment current slice
  Future<void> _segmentCurrentSlice() async {
    if (_volume == null || _currentSliceData == null) {
      setState(() {
        _statusMessage = 'No slice to segment';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Segmenting slice ${_currentSlice + 1}...';
    });
    
    try {
      final maskData = await SegmentationService.segmentSlice(
        imageData: _currentSliceData!,
        width: _volume!.width,
        height: _volume!.height,
        endpoint: _apiEndpoint,
      );
      
      setState(() {
        _maskData = maskData;
        _isLoading = false;
        _statusMessage = maskData != null 
            ? 'Segmentation complete!' 
            : 'Segmentation failed';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Segmentation error: $e';
      });
    }
  }
  
  /// Reset all settings
  void _resetAll() {
    setState(() {
      _volume = null;
      _currentSlice = 0;
      _currentSliceData = null;
      _maskData = null;
      _brightness = 0.0;
      _contrast = 1.0;
      _maskOpacity = 0.7;
      _applyGaussianBlur = false;
      _applySharpen = false;
      _applyEdgeDetection = false;
      _applyCLAHE = false;
      _blurRadius = 1.0;
      _selectedPreset = null;
      _statusMessage = '';
    });
  }
  
  /// Show settings dialog
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'API Endpoint',
                  hintText: 'http://localhost:8000/segment',
                ),
                controller: TextEditingController(text: _apiEndpoint),
                onChanged: (value) => _apiEndpoint = value,
              ),
              const SizedBox(height: 16),
              Text('Mask Opacity: ${_maskOpacity.toStringAsFixed(2)}'),
              Slider(
                value: _maskOpacity,
                min: 0.0,
                max: 1.0,
                onChanged: (value) => setState(() => _maskOpacity = value),
              ),
              SwitchListTile(
                title: const Text('Show Mask'),
                value: _showMask,
                onChanged: (value) => setState(() => _showMask = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CT Liver Tumor Segmentation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Display Area
          Expanded(
            flex: 3,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: _volume != null
                  ? SliceViewer(
                      imageData: _currentSliceData,
                      maskData: _maskData,
                      width: _volume!.width,
                      height: _volume!.height,
                      maskOpacity: _maskOpacity,
                      showMask: _showMask,
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medical_services, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Load a NIfTI file to begin'),
                        ],
                      ),
                    ),
            ),
          ),
          
          // Controls Area
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Message
                  if (_statusMessage.isNotEmpty)
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(color: Colors.blue[900]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Load File Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadNiftiFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Load NIfTI File'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  
                  if (_volume != null) ...[
                    const SizedBox(height: 16),
                    
                    // Slice Navigation
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Slice: ${_currentSlice + 1} / ${_volume!.depth}'),
                            Slider(
                              value: _currentSlice.toDouble(),
                              min: 0,
                              max: (_volume!.depth - 1).toDouble(),
                              divisions: _volume!.depth - 1,
                              onChanged: (value) {
                                setState(() {
                                  _currentSlice = value.toInt();
                                  _maskData = null; // Clear mask when changing slices
                                });
                                _updateSliceDisplay();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Window/Level Controls
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Window/Level', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            
                            // Presets
                            Wrap(
                              spacing: 8,
                              children: WindowLevelPreset.presets.map((preset) {
                                return FilterChip(
                                  label: Text(preset.name),
                                  selected: _selectedPreset == preset,
                                  onSelected: (_) => _applyPreset(preset),
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Text('Min: ${_windowMin.toInt()}'),
                            Slider(
                              value: _windowMin,
                              min: _volume!.minValue.toDouble(),
                              max: _volume!.maxValue.toDouble(),
                              onChanged: (value) {
                                setState(() => _windowMin = value);
                                _updateSliceDisplay();
                              },
                            ),
                            
                            Text('Max: ${_windowMax.toInt()}'),
                            Slider(
                              value: _windowMax,
                              min: _volume!.minValue.toDouble(),
                              max: _volume!.maxValue.toDouble(),
                              onChanged: (value) {
                                setState(() => _windowMax = value);
                                _updateSliceDisplay();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Image Processing Controls
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Image Processing', style: TextStyle(fontWeight: FontWeight.bold)),
                            
                            Text('Brightness: ${_brightness.toStringAsFixed(2)}'),
                            Slider(
                              value: _brightness,
                              min: -1.0,
                              max: 1.0,
                              onChanged: (value) {
                                setState(() => _brightness = value);
                                _updateSliceDisplay();
                              },
                            ),
                            
                            Text('Contrast: ${_contrast.toStringAsFixed(2)}'),
                            Slider(
                              value: _contrast,
                              min: 0.1,
                              max: 3.0,
                              onChanged: (value) {
                                setState(() => _contrast = value);
                                _updateSliceDisplay();
                              },
                            ),
                            
                            // Filters
                            const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
                            
                            SwitchListTile(
                              title: const Text('Gaussian Blur'),
                              value: _applyGaussianBlur,
                              onChanged: (value) {
                                setState(() => _applyGaussianBlur = value);
                                _updateSliceDisplay();
                              },
                            ),
                            
                            if (_applyGaussianBlur)
                              Column(
                                children: [
                                  Text('Blur Radius: ${_blurRadius.toStringAsFixed(1)}'),
                                  Slider(
                                    value: _blurRadius,
                                    min: 0.5,
                                    max: 5.0,
                                    onChanged: (value) {
                                      setState(() => _blurRadius = value);
                                      _updateSliceDisplay();
                                    },
                                  ),
                                ],
                              ),
                            
                            SwitchListTile(
                              title: const Text('Sharpen'),
                              value: _applySharpen,
                              onChanged: (value) {
                                setState(() => _applySharpen = value);
                                _updateSliceDisplay();
                              },
                            ),
                            
                            SwitchListTile(
                              title: const Text('Edge Detection'),
                              value: _applyEdgeDetection,
                              onChanged: (value) {
                                setState(() => _applyEdgeDetection = value);
                                _updateSliceDisplay();
                              },
                            ),
                            
                            SwitchListTile(
                              title: const Text('CLAHE'),
                              value: _applyCLAHE,
                              onChanged: (value) {
                                setState(() => _applyCLAHE = value);
                                _updateSliceDisplay();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Segment Button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _segmentCurrentSlice,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      label: const Text('Segment Slice'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}