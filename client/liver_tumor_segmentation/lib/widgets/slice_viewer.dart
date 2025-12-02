import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

/// Widget for displaying CT slices with overlay support
class SliceViewer extends StatefulWidget {
  final Uint8List? imageData;
  final Uint8List? maskData;
  final int width;
  final int height;
  final double maskOpacity;
  final bool showMask;
  final VoidCallback? onTap;
  
  const SliceViewer({
    super.key,
    this.imageData,
    this.maskData,
    required this.width,
    required this.height,
    this.maskOpacity = 0.7,
    this.showMask = true,
    this.onTap,
  });
  
  @override
  State<SliceViewer> createState() => _SliceViewerState();
}

class _SliceViewerState extends State<SliceViewer> {
  ui.Image? _baseImage;
  ui.Image? _maskImage;
  
  @override
  void didUpdateWidget(SliceViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.imageData != oldWidget.imageData) {
      _createBaseImage();
    }
    
    if (widget.maskData != oldWidget.maskData) {
      _createMaskImage();
    }
  }
  
  @override
  void initState() {
    super.initState();
    _createBaseImage();
    _createMaskImage();
  }
  
  Future<void> _createBaseImage() async {
    if (widget.imageData == null) {
      _baseImage = null;
      return;
    }
    
    // Convert grayscale to RGBA
    final rgbaData = Uint8List(widget.width * widget.height * 4);
    for (int i = 0; i < widget.imageData!.length; i++) {
      final value = widget.imageData![i];
      final rgbaIndex = i * 4;
      rgbaData[rgbaIndex] = value;     // R
      rgbaData[rgbaIndex + 1] = value; // G
      rgbaData[rgbaIndex + 2] = value; // B
      rgbaData[rgbaIndex + 3] = 255;   // A
    }
    
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaData,
      widget.width,
      widget.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    
    final image = await completer.future;
    if (mounted) {
      setState(() {
        _baseImage = image;
      });
    }
  }
  
  Future<void> _createMaskImage() async {
    if (widget.maskData == null) {
      _maskImage = null;
      return;
    }
    
    // Convert mask to colored RGBA (red overlay)
    final rgbaData = Uint8List(widget.width * widget.height * 4);
    for (int i = 0; i < widget.maskData!.length; i++) {
      final value = widget.maskData![i];
      final rgbaIndex = i * 4;
      
      if (value > 128) { // Threshold for mask
        rgbaData[rgbaIndex] = 255;     // R (red)
        rgbaData[rgbaIndex + 1] = 0;   // G
        rgbaData[rgbaIndex + 2] = 0;   // B
        rgbaData[rgbaIndex + 3] = (widget.maskOpacity * 255).toInt(); // A
      } else {
        rgbaData[rgbaIndex] = 0;
        rgbaData[rgbaIndex + 1] = 0;
        rgbaData[rgbaIndex + 2] = 0;
        rgbaData[rgbaIndex + 3] = 0;
      }
    }
    
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgbaData,
      widget.width,
      widget.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    
    final image = await completer.future;
    if (mounted) {
      setState(() {
        _maskImage = image;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: _baseImage != null
            ? CustomPaint(
                painter: _SlicePainter(
                  baseImage: _baseImage!,
                  maskImage: widget.showMask ? _maskImage : null,
                ),
                size: Size.infinite,
              )
            : const Center(
                child: Text(
                  'No image loaded',
                  style: TextStyle(color: Colors.white),
                ),
              ),
      ),
    );
  }
  
  @override
  void dispose() {
    _baseImage?.dispose();
    _maskImage?.dispose();
    super.dispose();
  }
}

class _SlicePainter extends CustomPainter {
  final ui.Image baseImage;
  final ui.Image? maskImage;
  
  _SlicePainter({
    required this.baseImage,
    this.maskImage,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    
    // Calculate scaling to fit image in available space while maintaining aspect ratio
    final imageAspectRatio = baseImage.width / baseImage.height;
    final canvasAspectRatio = size.width / size.height;
    
    double scale;
    Offset offset;
    
    if (imageAspectRatio > canvasAspectRatio) {
      // Image is wider than canvas
      scale = size.width / baseImage.width;
      offset = Offset(0, (size.height - baseImage.height * scale) / 2);
    } else {
      // Image is taller than canvas
      scale = size.height / baseImage.height;
      offset = Offset((size.width - baseImage.width * scale) / 2, 0);
    }
    
    final destRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      baseImage.width * scale,
      baseImage.height * scale,
    );
    
    // Draw base image
    canvas.drawImageRect(
      baseImage,
      Rect.fromLTWH(0, 0, baseImage.width.toDouble(), baseImage.height.toDouble()),
      destRect,
      paint,
    );
    
    // Draw mask overlay if available
    if (maskImage != null) {
      canvas.drawImageRect(
        maskImage!,
        Rect.fromLTWH(0, 0, maskImage!.width.toDouble(), maskImage!.height.toDouble()),
        destRect,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant _SlicePainter oldDelegate) {
    return oldDelegate.baseImage != baseImage || oldDelegate.maskImage != maskImage;
  }
}