# CT Liver Tumor Segmentation App

A Flutter mobile application for visualizing CT scans from NIfTI files and performing AI-based liver tumor segmentation.

## Features

### Core Functionality
- **NIfTI File Support**: Load .nii and .nii.gz files
- **3D Volume Navigation**: Navigate through CT slices with smooth scrolling
- **Window/Level Adjustment**: Adjust HU values with presets for different tissue types
- **Image Processing**: Real-time brightness, contrast, and filter adjustments
- **AI Segmentation**: Send slices to server for tumor detection
- **Mask Overlay**: Visualize segmentation results with adjustable opacity

### Image Processing Filters
- Gaussian Blur
- Sharpen
- Edge Detection (Sobel)
- CLAHE (Contrast Limited Adaptive Histogram Equalization)

### Window/Level Presets
- **Liver**: 40–80 HU
- **Bone**: -250–1250 HU  
- **Lung**: -1000–-300 HU
- **Soft Tissue**: 50–350 HU

## Project Structure

```
liver_tumor_segmentation/
├── client/liver_tumor_segmentation/    # Flutter app
│   ├── lib/
│   │   ├── models/                     # Data models
│   │   │   └── nifti_volume.dart      # NIfTI volume representation
│   │   ├── services/                   # Business logic
│   │   │   ├── nifti_loader.dart      # NIfTI file loading
│   │   │   └── segmentation_service.dart # API communication
│   │   ├── utils/                      # Utilities
│   │   │   └── image_processor.dart    # Image processing functions
│   │   ├── widgets/                    # UI components
│   │   │   └── slice_viewer.dart      # CT slice display widget
│   │   └── main.dart                   # Main application
│   └── pubspec.yaml                    # Dependencies
└── server/                             # Python API server
    ├── api/
    │   └── main.py                     # Flask server
    └── requirements.txt                # Python dependencies
```

## Setup Instructions

### Flutter App Setup

1. **Install Flutter**: Follow [Flutter installation guide](https://flutter.dev/docs/get-started/install)

2. **Navigate to client directory**:
   ```bash
   cd client/liver_tumor_segmentation
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the app**:
   ```bash
   flutter run
   ```

### Server Setup (Optional)

The app includes a demo Python server for testing segmentation functionality.

1. **Install Python 3.8+**

2. **Navigate to server directory**:
   ```bash
   cd server
   ```

3. **Create virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

4. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

5. **Run server**:
   ```bash
   python api/main.py
   ```

The server will be available at `http://localhost:8000`

## Usage Guide

### Loading CT Scans

1. Tap **"Load NIfTI File"** button
2. Select a .nii or .nii.gz file from your device
3. Wait for the file to load and process

### Navigating Slices

- Use the **slice slider** to navigate through the volume
- Current slice number and total slices are displayed
- Swipe gestures can be added for touch navigation

### Adjusting Window/Level

1. Use **preset buttons** for common tissue types:
   - Liver, Bone, Lung, Soft Tissue
2. Or manually adjust **Min/Max sliders** for custom windowing

### Applying Image Processing

1. **Brightness/Contrast**: Use sliders for real-time adjustment
2. **Filters**: Toggle switches to apply:
   - Gaussian Blur (with radius control)
   - Sharpen
   - Edge Detection
   - CLAHE

### Performing Segmentation

1. Navigate to desired slice
2. Apply any desired image processing
3. Tap **"Segment Slice"** button
4. Wait for server response
5. View segmentation mask overlay (red regions)

### Settings

- **API Endpoint**: Configure server URL
- **Mask Opacity**: Adjust overlay transparency
- **Show/Hide Mask**: Toggle segmentation display

## API Interface

The app communicates with a segmentation server via REST API:

### Endpoint: `POST /segment`

**Request**:
- Content-Type: `multipart/form-data`
- Body: Image file (PNG format)
- Fields: `width`, `height`, `format`

**Response**:
```json
{
  "success": true,
  "mask": "base64_encoded_mask_image",
  "message": "Segmentation completed successfully"
}
```

### Health Check: `GET /health`

**Response**:
```json
{
  "status": "healthy",
  "message": "Segmentation API is running"
}
```

## Performance Considerations

- **Slice Caching**: Previously viewed slices are cached for smooth navigation
- **GPU Processing**: Window/level adjustments use optimized algorithms
- **Background Processing**: Image processing doesn't block UI
- **Memory Management**: Large volumes are handled efficiently

## Customization

### Adding New Filters

1. Add filter function to `utils/image_processor.dart`
2. Add UI controls in main app
3. Update `_updateSliceDisplay()` method

### Custom Window/Level Presets

Modify `WindowLevelPreset.presets` in `models/nifti_volume.dart`:

```dart
static const List<WindowLevelPreset> presets = [
  WindowLevelPreset(name: 'Custom', windowMin: -100, windowMax: 200),
  // Add more presets...
];
```

### AI Model Integration

Replace the demo server in `server/api/main.py` with your actual AI model:

```python
def segment_with_ai_model(image_array):
    # Load your trained model
    # model = load_model('path/to/model')
    
    # Preprocess image
    # processed_image = preprocess(image_array)
    
    # Run inference
    # mask = model.predict(processed_image)
    
    return mask
```

## Troubleshooting

### Common Issues

1. **File Loading Errors**:
   - Ensure NIfTI file is valid and not corrupted
   - Check file permissions
   - Verify file format (.nii or .nii.gz)

2. **Segmentation Failures**:
   - Check server connectivity
   - Verify API endpoint URL
   - Ensure server is running

3. **Performance Issues**:
   - Large files may take time to load
   - Reduce image processing operations for better performance
   - Close other apps to free memory

### Debug Mode

Enable debug logging by modifying the app's logging configuration.

## Dependencies

### Flutter Dependencies
- `file_picker`: File selection
- `image`: Image processing
- `archive`: .gz file support
- `http`: API communication
- `provider`: State management
- `shared_preferences`: Settings storage

### Python Dependencies
- `flask`: Web server
- `flask-cors`: CORS support
- `pillow`: Image processing
- `numpy`: Numerical operations
- `opencv-python`: Computer vision

## License

This project is for educational and research purposes. Ensure compliance with medical software regulations for clinical use.

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## Support

For issues and questions:
1. Check troubleshooting section
2. Review code comments
3. Create GitHub issue with details