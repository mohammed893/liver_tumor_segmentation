import 'dart:typed_data';
import 'dart:ui' as ui;
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
    final windowRange = windowMax - windowMin;
    
    for (int i = 0; i < sliceData.length; i++) {
      final value = sliceData[i].toDouble();
      double normalized;
      
      if (value <= windowMin) {
        normalized = 0.0;
      } else if (value >= windowMax) {
        normalized = 1.0;
      } else {
        normalized = (value - windowMin) / windowRange;
      }
      
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
    return Uint8List.fromList(blurred.getBytes());
  }
  
  /// Apply sharpen filter
  static Uint8List applySharpen(
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
    
    // Simple sharpen kernel
    final kernel = [
      [0, -1, 0],
      [-1, 5, -1],
      [0, -1, 0],
    ];
    
    final sharpened = img.convolution(image, kernel);
    return Uint8List.fromList(sharpened.getBytes());
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
    return Uint8List.fromList(edges.getBytes());
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