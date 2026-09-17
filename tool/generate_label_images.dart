import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:medigram_app/widgets/medicine_bottle_label.dart';

/// Generates the labelled medicine product-shot images used by the product
/// cards (`MedicineLabelsPage`).
///
/// This is a small desktop Flutter app (NOT a test) so the bottles are drawn
/// by the real renderer with real system fonts — no test-font placeholder
/// boxes. Run it with:
///
///   flutter run -d windows -t tool\generate_label_images.dart
///
/// It saves one PNG per medicine to
/// `web/assets/products/labels/<medicine-slug>.png` (960x1280 px) and exits.
Future<void> main(List<String> args) async {
  final outDir = args.isNotEmpty ? args[0] : 'web/assets/products/labels';
  runApp(_GeneratorApp(outDir: outDir, names: _medicineNames));
}

/// Medicines to generate labelled shots for. The first six match the sample
/// catalogue from the pharmaexport source; the last one is a generic fallback
/// product shot any card can use.
const List<String> _medicineNames = [
  'Pregabalin 300mg',
  'Sildenafil 100mg',
  'Tadalafil 20mg',
  'Azithromycin 250mg',
  'Tapentadol 100mg',
  'Gabapentin 800mg',
  'Medicine',
];

/// Same normalisation the product cards use to map a medicine name to its
/// image file: 'Pregabalin 300mg' -> 'pregabalin-300mg'.
String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

class _GeneratorApp extends StatelessWidget {
  final String outDir;
  final List<String> names;

  const _GeneratorApp({required this.outDir, required this.names});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _GeneratorHome(outDir: outDir, names: names),
    );
  }
}

class _GeneratorHome extends StatefulWidget {
  final String outDir;
  final List<String> names;

  const _GeneratorHome({required this.outDir, required this.names});

  @override
  State<_GeneratorHome> createState() => _GeneratorHomeState();
}

class _GeneratorHomeState extends State<_GeneratorHome> {
  final GlobalKey _boundaryKey = GlobalKey();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    while (_index < widget.names.length) {
      // Make sure the current medicine is painted before capturing.
      await WidgetsBinding.instance.endOfFrame;
      await _captureCurrent(widget.names[_index]);
      if (!mounted) return;
      setState(() => _index += 1);
    }
    // Let the "done" state paint, then leave.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    exit(0);
  }

  Future<void> _captureCurrent(String name) async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0); // 960x1280 PNG
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = Directory(widget.outDir);
    await dir.create(recursive: true);
    final file = File('${dir.path}/${_slug(name)}.png');
    await file.writeAsBytes(bytes);
    // ignore: avoid_print
    print('generated ${file.path} (${bytes.length} bytes)');
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= widget.names.length;
    return Scaffold(
      backgroundColor: const Color(0xFFEDF5FC),
      body: Center(
        child: done
            ? const Text('All medicine images generated - closing...')
            : RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  width: 480,
                  height: 640,
                  color: const Color(0xFFEDF5FC),
                  alignment: Alignment.center,
                  child: MedicineBottleLabel(
                    medicineName: widget.names[_index],
                    subtitle: 'Sample Manufacturer',
                    footer: 'MOQ 10 units',
                    width: 175,
                    height: 310,
                  ),
                ),
              ),
      ),
    );
  }
}
