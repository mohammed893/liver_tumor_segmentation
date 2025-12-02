import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Image processing utilities for CT slices
class ImageProcessor {
  /// Apply window/level adjustment to slice data
  static Uint8List applyWindowLevel(
    Uint16List sliceData,
    int width,
    int height,
    double windowMin,
    double windowMax,
  ) {
    final result = Uint8List(width * height);
    
    // Find min/max in raw data
    int minRaw = sliceData[0];
    int maxRaw = sliceData[0];
    for (final value in sliceData) {
      if (value < minRaw) minRaw = value;
      if (value > maxRaw) maxRaw = value;
    }
    
    // Simple linear scaling from raw data range to 0-255
    final rawRange = maxRaw - minRaw;
    if (rawRange == 0) {
      result.fillRange(0, result.length, 128);
      return result;
    }
    
    for (int i = 0; i < sliceData.length; i++) {
      final normalized = (sliceData[i] - minRaw) / rawRange;
      result[i] = (normalized * 255).round().clamp(0, 255);
    }
    
    return result;
  }
  
  /// Apply brightness and contrast adjustments
  static Uint8List applyBrightnessContrast(
    Uint8List imageData,
    double brightness,
    double contrast,
  ) {
    final result = Uint8List(imageData.length);
    
    for (int i = 0; i < imageData.length; i++) {
      double value = imageData[i].toDouble();
      
      // Apply contrast (multiply)
      value *= contrast;
      
      // Apply brightness (add)
      value += brightness * 255;
      
      result[i] = value.round().clamp(0, 255);
    }
    
    return result;
  }
  
  /// Apply Gaussian blur filter
  static Uint8List applyGaussianBlur(
    Uint8List imageData,
    int width,
    int height,
    double radius,
  ) {
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: imageData.buffer,
      format: img.Format.uint8,
      numChannels: 1,
    );
    
    final blurred = img.gaussianBlur(image, radius: radius.toInt());
    return Uint8List.fromList(blurred.toUint8List());
  }
  
  /// Apply sharpen filter
  static Uint8List applySharpen(
    Uint8List imageData,
    int width,
    int height,
  ) {
    // Simple CPU-based sharpening using convolution
    final result = Uint8List.fromList(imageData);
    
    // Apply simple sharpening kernel manually
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final idx = y * width + x;
        final center = imageData[idx].toDouble();
        final top = imageData[(y - 1) * width + x].toDouble();
        final bottom = imageData[(y + 1) * width + x].toDouble();
        final left = imageData[y * width + (x - 1)].toDouble();
        final right = imageData[y * width + (x + 1)].toDouble();
        
        // Sharpen kernel: center * 5 - neighbors
        final sharpened = (center * 5 - top - bottom - left - right);
        result[idx] = sharpened.clamp(0, 255).toInt();
      }
    }
    
    return result;
  }
  
  /// Apply edge detection (Sobel)
  static Uint8List applyEdgeDetection(
    Uint8List imageData,
    int width,
    int height,
  ) {
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: imageData.buffer,
      format: img.Format.uint8,
      numChannels: 1,
    );
    
    final edges = img.sobel(image);
    return Uint8List.fromList(edges.toUint8List());
  }
  
  /// Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
  static Uint8List applyCLAHE(
    Uint8List imageData,
    int width,
    int height,
  ) {
    // Simplified histogram equalization
    final histogram = List<int>.filled(256, 0);
    
    // Build histogram
    for (final pixel in imageData) {
      histogram[pixel]++;
    }
    
    // Calculate cumulative distribution
    final cdf = List<double>.filled(256, 0);
    cdf[0] = histogram[0].toDouble();
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }
    
    // Normalize CDF
    final totalPixels = imageData.length.toDouble();
    for (int i = 0; i < 256; i++) {
      cdf[i] = (cdf[i] / totalPixels * 255).round().toDouble();
    }
    
    // Apply equalization
    final result = Uint8List(imageData.length);
    for (int i = 0; i < imageData.length; i++) {
      result[i] = cdf[imageData[i]].toInt();
    }
    
    return result;
  }
  
  /// Convert grayscale data to RGBA for display
  static Uint8List grayscaleToRGBA(Uint8List grayscaleData) {
    final rgba = Uint8List(grayscaleData.length * 4);
    
    for (int i = 0; i < grayscaleData.length; i++) {
      final value = grayscaleData[i];
      final rgbaIndex = i * 4;
      
      rgba[rgbaIndex] = value;     // R
      rgba[rgbaIndex + 1] = value; // G
      rgba[rgbaIndex + 2] = value; // B
      rgba[rgbaIndex + 3] = 255;   // A
    }
    
    return rgba;
  }
}