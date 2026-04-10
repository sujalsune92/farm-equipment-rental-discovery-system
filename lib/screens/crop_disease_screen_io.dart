import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/app_theme.dart';

class CropDiseaseScreen extends StatefulWidget {
  const CropDiseaseScreen({super.key});

  @override
  State<CropDiseaseScreen> createState() => _CropDiseaseScreenState();
}

class _CropDiseaseScreenState extends State<CropDiseaseScreen> {
  final _picker = ImagePicker();
  File? _imageFile;
  String? _predictedLabel;
  double? _confidence;
  String? _remedy;
  String? _error;
  bool _loadingModel = false;
  bool _running = false;
  Interpreter? _interpreter;
  List<String> _labels = [];
  static const List<String> _defaultLabels = [
    'Apple___Apple_scab',
    'Apple___Black_rot',
    'Apple___Cedar_apple_rust',
    'Apple___healthy',
    'Blueberry___healthy',
    'Cherry_(including_sour)___Powdery_mildew',
    'Cherry_(including_sour)___healthy',
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
    'Corn_(maize)___Common_rust_',
    'Corn_(maize)___Northern_Leaf_Blight',
    'Corn_(maize)___healthy',
    'Grape___Black_rot',
    'Grape___Esca_(Black_Measles)',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
    'Grape___healthy',
    'Orange___Haunglongbing_(Citrus_greening)',
    'Peach___Bacterial_spot',
    'Peach___healthy',
    'Pepper,_bell___Bacterial_spot',
    'Pepper,_bell___healthy',
    'Potato___Early_blight',
    'Potato___Late_blight',
    'Potato___healthy',
    'Raspberry___healthy',
    'Soybean___healthy',
    'Squash___Powdery_mildew',
    'Strawberry___Leaf_scorch',
    'Strawberry___healthy',
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites Two-spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy',
  ];

  static const _modelAsset = 'assets/models/model.tflite';
  static const _labelsAsset = 'assets/models/labels.txt';
  static const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _geminiModel = 'gemini-1.0-pro';

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    setState(() => _loadingModel = true);
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      try {
        final raw = await rootBundle.loadString(_labelsAsset);
        _labels = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();
        if (_labels.isEmpty) _labels = _defaultLabels;
      } catch (_) {
        _labels = _defaultLabels;
      }
      _error = null;
    } catch (e) {
      debugPrint('Model load error: $e');
      final windowsHint = Platform.isWindows
          ? '\nEnsure libtensorflowlite_c-win.dll is present in '
              '${Directory(Platform.resolvedExecutable).parent.path}\\blobs.'
          : '';
      _error = 'Model load failed: $e$windowsHint';
    } finally {
      if (mounted) setState(() => _loadingModel = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _predictedLabel = null;
      _confidence = null;
      _remedy = null;
    });
  }

  Future<void> _captureImage() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _predictedLabel = null;
      _confidence = null;
      _remedy = null;
    });
  }

  Future<void> _runInference() async {
    if (_imageFile == null || _interpreter == null) return;
    setState(() => _running = true);
    try {
      final bytes = await _imageFile!.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image');

      const inputSize = 224;
      final resized = img.copyResize(decoded, width: inputSize, height: inputSize);

      final imageAsList = List.generate(inputSize, (y) {
        return List.generate(inputSize, (x) {
          final p = resized.getPixel(x, y);
          final r = p.r / 255.0;
          final g = p.g / 255.0;
          final b = p.b / 255.0;
          return [r, g, b];
        });
      });

      final input = [imageAsList];
      final outputClasses = _labels.isNotEmpty
          ? _labels.length
          : _interpreter!.getOutputTensor(0).shape.last;
      final output = List.generate(1, (_) => List<double>.filled(outputClasses, 0));
      _interpreter!.run(input, output);

      final scores = output.first;
      int maxIdx = 0;
      double maxScore = scores[0];
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }
      setState(() {
        _predictedLabel = _labels.isNotEmpty && maxIdx < _labels.length ? _labels[maxIdx] : 'Class $maxIdx';
        _confidence = maxScore;
        _error = null;
      });
    } catch (e) {
      debugPrint('Inference error: $e');
      _error = 'Inference failed: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inference failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _generateRemedy() async {
    if (_predictedLabel == null) return;
    setState(() => _running = true);
    try {
      if (_geminiApiKey.isEmpty) {
        throw Exception('Set GEMINI_API_KEY via --dart-define to use remedies');
      }
      final model = GenerativeModel(model: _geminiModel, apiKey: _geminiApiKey);
      final prompt = 'Crop disease: $_predictedLabel. Provide concise remedies and precautions for farmers.';
      final response = await model.generateContent([Content.text(prompt)]);
      setState(() => _remedy = response.text ?? 'No remedy generated.');
      _error = null;
    } catch (e) {
      debugPrint('Gemini error: $e');
      _error = 'Remedy generation failed: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Remedy generation failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Disease Assistant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                  ],
                  const Text('Step 1: Upload leaf image'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                            )
                          : const Center(child: Text('Tap to select image')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _captureImage,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 2: Run detection'),
                  const SizedBox(height: 8),
                  if (_loadingModel)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Loading model...'),
                    ),
                  ElevatedButton(
                    onPressed: (_running || _loadingModel) ? null : _runInference,
                    child: (_running || _loadingModel)
                        ? const CircularProgressIndicator.adaptive()
                        : const Text('Analyze image'),
                  ),
                  if (_predictedLabel != null) ...[
                    const SizedBox(height: 16),
                    Text('Prediction: $_predictedLabel', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (_confidence != null) Text('Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _running ? null : _generateRemedy,
                      child: const Text('Get remedy from Gemini'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_remedy != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recommended remedy', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_remedy!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}