import 'package:flutter/material.dart';

class CropDiseaseScreen extends StatelessWidget {
  const CropDiseaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Disease Assistant')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Crop disease detection is not supported on Web.\nPlease use an Android device.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}