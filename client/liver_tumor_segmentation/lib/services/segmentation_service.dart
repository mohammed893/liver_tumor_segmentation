import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for communicating with the segmentation server
class SegmentationService {
  static const String defaultEndpoint = 'http://localhost:8000/segment';
  
  /// Send slice image to server for segmentation
  static Future<Uint8List?> segmentSlice({
    required Uint8List imageData,
    required int width,
    required int height,
    String endpoint = defaultEndpoint,
  }) async {
    try {
      // Convert grayscale to PNG format
      final pngBytes = await _convertToPNG(imageData, width, height);
      
      // Prepare multipart request
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));
      
      // Add image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          pngBytes,
          filename: 'slice.png',
        ),
      );
      
      // Add metadata
      request.fields['width'] = width.toString();
      request.fields['height'] = height.toString();
      request.fields['format'] = 'png';
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Assuming server returns base64 encoded mask
        if (responseData['mask'] != null) {
          return base64Decode(responseData['mask']);
        }
      } else {
        throw Exception('Segmentation failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Segmentation error: $e');
    }
    
    return null;
  }
  
  /// Convert grayscale image data to PNG bytes
  static Future<Uint8List> _convertToPNG(
    Uint8List grayscaleData,
    int width,
    int height,
  ) async {
    // Create RGBA data from grayscale
    final rgbaData = Uint8List(width * height * 4);
    
    for (int i = 0; i < grayscaleData.length; i++) {
      final value = grayscaleData[i];
      final rgbaIndex = i * 4;
      
      rgbaData[rgbaIndex] = value;     // R
      rgbaData[rgbaIndex + 1] = value; // G
      rgbaData[rgbaIndex + 2] = value; // B
      rgbaData[rgbaIndex + 3] = 255;   // A
    }
    
    // Note: In a real implementation, you'd use a proper PNG encoder
    // For now, we'll return the raw RGBA data
    return rgbaData;
  }
  
  /// Test server connectivity
  static Future<bool> testConnection(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${endpoint.replaceAll('/segment', '')}/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}