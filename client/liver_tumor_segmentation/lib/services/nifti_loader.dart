import 'dart:io';
import 'dart:typed_data';
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
      final archive = GZipDecoder().decodeBytes(fileBytes);
      fileBytes = Uint8List.fromList(archive);
    }
    
    return _parseNiftiData(fileBytes);
  }
  
  /// Parse NIfTI header and data
  static NiftiVolume _parseNiftiData(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    
    // Read NIfTI header (simplified - real implementation would be more comprehensive)
    final headerSize = byteData.getInt32(0, Endian.little);
    
    // Basic dimensions (assuming standard NIfTI structure)
    final width = byteData.getInt16(42, Endian.little);
    final height = byteData.getInt16(44, Endian.little);
    final depth = byteData.getInt16(46, Endian.little);
    
    // Pixel spacing
    final pixelSpacingX = byteData.getFloat32(80, Endian.little);
    final pixelSpacingY = byteData.getFloat32(84, Endian.little);
    final pixelSpacingZ = byteData.getFloat32(88, Endian.little);
    
    // Data offset (usually 352 for NIfTI-1)
    final dataOffset = headerSize > 0 ? headerSize : 352;
    
    // Extract image data (assuming 16-bit integers)
    final dataSize = width * height * depth;
    final imageData = Uint16List(dataSize);
    
    for (int i = 0; i < dataSize; i++) {
      imageData[i] = byteData.getUint16(dataOffset + i * 2, Endian.little);
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
      pixelSpacingX: pixelSpacingX,
      pixelSpacingY: pixelSpacingY,
      pixelSpacingZ: pixelSpacingZ,
      minValue: minValue,
      maxValue: maxValue,
    );
  }
}