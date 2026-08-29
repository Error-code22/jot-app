import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A drawing canvas widget that allows freehand drawing.
/// Supports color selection, stroke width, and export to image.
class DrawingCanvas extends StatefulWidget {
  final Function(File imageFile)? onDrawingSaved;
  final Function(List<DrawingPoint> points)? onDrawingUpdated;

  const DrawingCanvas({
    super.key,
    this.onDrawingSaved,
    this.onDrawingUpdated,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<DrawingPoint> _points = [];
  final GlobalKey _canvasKey = GlobalKey();
  
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _isErasing = false;
  
  final List<Color> _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        _buildToolbar(context),
        
        // Canvas
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RepaintBoundary(
                key: _canvasKey,
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: DrawingPainter(_points),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          // Color picker
          ...(_colors.map((color) => _buildColorButton(color))),
          
          const SizedBox(width: 8),
          
          // Stroke width slider
          Expanded(
            child: Slider(
              value: _strokeWidth,
              min: 1,
              max: 20,
              onChanged: (value) => setState(() => _strokeWidth = value),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Eraser toggle
          IconButton(
            icon: Icon(
              _isErasing ? Icons.brush : Icons.auto_fix_high,
              color: _isErasing ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => setState(() => _isErasing = !_isErasing),
            tooltip: _isErasing ? 'Switch to brush' : 'Switch to eraser',
          ),
          
          // Clear button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearCanvas,
            tooltip: 'Clear canvas',
          ),
          
          // Save button
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _saveDrawing,
            tooltip: 'Save drawing',
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedColor == color && !_isErasing;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedColor = color;
        _isErasing = false;
      }),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    final point = DrawingPoint(
      offset: details.localPosition,
      color: _isErasing ? Colors.white : _selectedColor,
      strokeWidth: _isErasing ? _strokeWidth * 3 : _strokeWidth,
    );
    setState(() => _points.add(point));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final point = DrawingPoint(
      offset: details.localPosition,
      color: _isErasing ? Colors.white : _selectedColor,
      strokeWidth: _isErasing ? _strokeWidth * 3 : _strokeWidth,
    );
    setState(() => _points.add(point));
  }

  void _onPanEnd(DragEndDetails details) {
    widget.onDrawingUpdated?.call(_points);
  }

  void _clearCanvas() {
    setState(() => _points.clear());
    widget.onDrawingUpdated?.call(_points);
  }

  Future<void> _saveDrawing() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      
      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'drawing-${const Uuid().v4()}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      widget.onDrawingSaved?.call(file);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Drawing saved'),
            action: SnackBarAction(
              label: 'Insert',
              onPressed: () => widget.onDrawingSaved?.call(file),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving drawing: $e');
    }
  }
}

/// Data class for a drawing point
class DrawingPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  DrawingPoint({
    required this.offset,
    required this.color,
    required this.strokeWidth,
  });
}

/// Custom painter for drawing
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final paint = Paint()
        ..color = points[i].color
        ..strokeWidth = points[i].strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(points[i].offset, points[i + 1].offset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
