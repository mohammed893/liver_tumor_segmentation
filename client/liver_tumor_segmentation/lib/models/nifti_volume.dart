import 'dart:typed_data';

/// Represents a 3D NIfTI volume with metadata
class NiftiVolume {
  final Uint16List data;
  final int width;
  final int height;
  final int depth;
  final double pixelSpacingX;
  final double pixelSpacingY;
  final double pixelSpacingZ;
  final int minValue;
  final int maxValue;
  
  NiftiVolume({
    required this.data,
    required this.width,
    required this.height,
    required this.depth,
    this.pixelSpacingX = 1.0,
    this.pixelSpacingY = 1.0,
    this.pixelSpacingZ = 1.0,
    required this.minValue,
    required this.maxValue,
  });
  
  /// Get a specific slice from the volume
  Uint16List getSlice(int sliceIndex) {
    if (sliceIndex < 0 || sliceIndex >= depth) {
      throw ArgumentError('Slice index out of bounds');
    }
    
    final sliceSize = width * height;
    final startIndex = sliceIndex * sliceSize;
    return Uint16List.sublistView(data, startIndex, startIndex + sliceSize);
  }
  
  /// Get pixel value at specific coordinates
  int getPixelValue(int x, int y, int z) {
    if (x < 0 || x >= width || y < 0 || y >= height || z < 0 || z >= depth) {
      return 0;
    }
    return data[z * width * height + y * width + x];
  }
}

/// Window/Level preset configurations
class WindowLevelPreset {
  final String name;
  final double windowMin;
  final double windowMax;
  
  const WindowLevelPreset({
    required this.name,
    required this.windowMin,
    required this.windowMax,
  });
  
  static const List<WindowLevelPreset> presets = [
    WindowLevelPreset(name: 'Liver', windowMin: 40, windowMax: 80),
    WindowLevelPreset(name: 'Bone', windowMin: -250, windowMax: 1250),
    WindowLevelPreset(name: 'Lung', windowMin: -1000, windowMax: -300),
    WindowLevelPreset(name: 'Soft Tissue', windowMin: 50, windowMax: 350),
  ];
}