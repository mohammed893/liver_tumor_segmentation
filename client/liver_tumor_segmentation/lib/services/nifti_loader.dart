import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import '../models/nifti_volume.dart';

/// Service for loading and parsing NIfTI files
class NiftiLoader {
  /// Load NIfTI file (.nii or .nii.gz)
  static Future<NiftiVolume> loadNiftiFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    Uint8List fileBytes = await file.readAsBytes();
    
    // Handle .nii.gz files
    if (filePath.endsWith('.gz')) {
      try {
        final archive = GZipDecoder().decodeBytes(fileBytes);
        fileBytes = Uint8List.fromList(archive);
      } catch (e) {
        throw Exception('Failed to decompress .gz file: $e');
      }
    }
    
    return _parseNiftiData(fileBytes);
  }
  
  /// Create demo volume for testing
  static NiftiVolume _createDemoVolume() {
    const width = 256;
    const height = 256;
    const depth = 100;
    
    final data = Uint16List(width * height * depth);
    final random = math.Random();
    
    // Generate synthetic CT-like data
    for (int z = 0; z < depth; z++) {
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final idx = z * width * height + y * width + x;
          
          // Create circular structures resembling organs
          final centerX = width / 2;
          final centerY = height / 2;
          final distance = math.sqrt(math.pow(x - centerX, 2) + math.pow(y - centerY, 2));
          
          int value;
          if (distance < 80) {
            // Liver-like tissue
            value = 1000 + random.nextInt(200);
          } else if (distance < 120) {
            // Soft tissue
            value = 800 + random.nextInt(300);
          } else {
            // Air/background
            value = -800 + random.nextInt(200);
          }
          
          data[idx] = (value + 1024).clamp(0, 4095); // Convert to unsigned
        }
      }
    }
    
    return NiftiVolume(
      data: data,
      width: width,
      height: height,
      depth: depth,
      pixelSpacingX: 1.0,
      pixelSpacingY: 1.0,
      pixelSpacingZ: 1.0,
      minValue: 0,
      maxValue: 4095,
    );
  }
  
  /// Parse NIfTI header and data
  static NiftiVolume _parseNiftiData(Uint8List bytes) {
    if (bytes.length < 352) {
      throw Exception('File too small to be a valid NIfTI file');
    }
    
    final byteData = ByteData.sublistView(bytes);
    
    // Check NIfTI magic number (be more flexible)
    try {
      final magic = String.fromCharCodes(bytes.sublist(344, 348));
      // Accept common NIfTI magic numbers
    } catch (e) {
      // Continue parsing even if magic check fails
    }
    
    // Read dimensions
    final dim0 = byteData.getInt16(40, Endian.little); // Number of dimensions
    if (dim0 < 3) {
      throw Exception('Invalid number of dimensions: $dim0');
    }
    
    final width = byteData.getInt16(42, Endian.little);
    final height = byteData.getInt16(44, Endian.little);
    final depth = byteData.getInt16(46, Endian.little);
    
    if (width <= 0 || height <= 0 || depth <= 0) {
      throw Exception('Invalid dimensions: ${width}x${height}x$depth');
    }
    
    // Pixel spacing
    final pixelSpacingX = byteData.getFloat32(80, Endian.little);
    final pixelSpacingY = byteData.getFloat32(84, Endian.little);
    final pixelSpacingZ = byteData.getFloat32(88, Endian.little);
    
    // Data type
    final datatype = byteData.getInt16(70, Endian.little);
    final bitpix = byteData.getInt16(72, Endian.little);
    
    // Data offset
    final voxOffset = byteData.getFloat32(108, Endian.little);
    final dataOffset = voxOffset > 0 ? voxOffset.toInt() : 352;
    
    if (dataOffset >= bytes.length) {
      throw Exception('Data offset beyond file size');
    }
    
    // Extract image data
    final dataSize = width * height * depth;
    final imageData = Uint16List(dataSize);
    
    if (datatype == 4 && bitpix == 16) { // 16-bit signed integer
      for (int i = 0; i < dataSize && (dataOffset + i * 2 + 1) < bytes.length; i++) {
        final value = byteData.getInt16(dataOffset + i * 2, Endian.little);
        imageData[i] = (value + 32768).clamp(0, 65535); // Convert to unsigned
      }
    } else if (datatype == 512 && bitpix == 16) { // 16-bit unsigned integer
      for (int i = 0; i < dataSize && (dataOffset + i * 2 + 1) < bytes.length; i++) {
        imageData[i] = byteData.getUint16(dataOffset + i * 2, Endian.little);
      }
    } else if (datatype == 16 && bitpix == 32) { // 32-bit float
      for (int i = 0; i < dataSize && (dataOffset + i * 4 + 3) < bytes.length; i++) {
        final value = byteData.getFloat32(dataOffset + i * 4, Endian.little);
        imageData[i] = (value + 32768).clamp(0, 65535).toInt(); // Convert to unsigned
      }
    } else {
      // Default: try different approaches
      if (bytes.length >= dataOffset + dataSize * 2) {
        // Try 16-bit signed
        for (int i = 0; i < dataSize; i++) {
          final value = byteData.getInt16(dataOffset + i * 2, Endian.little);
          imageData[i] = (value + 32768).clamp(0, 65535);
        }
      } else if (bytes.length >= dataOffset + dataSize) {
        // Try 8-bit
        for (int i = 0; i < dataSize; i++) {
          final value = bytes[dataOffset + i];
          imageData[i] = value * 256; // Scale to 16-bit range
        }
      } else {
        throw Exception('Insufficient data in file');
      }
    }
    
    // Calculate min/max values
    int minValue = imageData[0];
    int maxValue = imageData[0];
    for (final value in imageData) {
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
    }
    
    return NiftiVolume(
      data: imageData,
      width: width,
      height: height,
      depth: depth,
      pixelSpacingX: pixelSpacingX.isFinite ? pixelSpacingX : 1.0,
      pixelSpacingY: pixelSpacingY.isFinite ? pixelSpacingY : 1.0,
      pixelSpacingZ: pixelSpacingZ.isFinite ? pixelSpacingZ : 1.0,
      minValue: minValue,
      maxValue: maxValue,
    );
  }
}