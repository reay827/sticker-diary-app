import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:image/image.dart' as img;
import 'widgets.dart';

class PhotoRegionPicker extends StatefulWidget {
  const PhotoRegionPicker({super.key, required this.photo});
  final Uint8List photo;
  @override
  State<PhotoRegionPicker> createState() => _PhotoRegionPickerState();
}

class _PhotoRegionPickerState extends State<PhotoRegionPicker> {
  Rect region = const Rect.fromLTWH(0, 0, 1, 1);
  Offset? start;
  late final info = img.PngDecoder().startDecode(widget.photo)!;
  Offset _relative(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0),
    (point.dy / size.height).clamp(0.0, 1.0),
  );
  bool get usable => region.width >= .04 && region.height >= .04;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('오려낼 범위 선택')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Text(
              '남기고 싶은 대상 주위로 드래그해 네모를 그려 주세요.\n이 범위 안에서 배경을 다시 제거해요.',
              style: TextStyle(color: muted, height: 1.6),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: AspectRatio(
                  aspectRatio: info.width / info.height,
                  child: LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      key: const ValueKey('photo-region-canvas'),
                      dragStartBehavior: DragStartBehavior.down,
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => setState(() {
                        start = _relative(details.localPosition, box.biggest);
                        region = Rect.fromPoints(start!, start!);
                      }),
                      onPanUpdate: (details) => setState(
                        () => region = Rect.fromPoints(
                          start!,
                          _relative(details.localPosition, box.biggest),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.memory(widget.photo, fit: BoxFit.fill),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _RegionPainter(region),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Text(
                  usable ? '다시 드래그하면 선택 범위를 바꿀 수 있어요.' : '조금 더 넓게 선택해 주세요.',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: usable
                        ? () => Navigator.pop(context, region)
                        : null,
                    child: const Text('이 범위에서 오려내기'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter(this.region);
  final Rect region;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      region.left * size.width,
      region.top * size.height,
      region.right * size.width,
      region.bottom * size.height,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(shade, Paint()..color = const Color(0x88000000));
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    for (final p in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(p, 5, Paint()..color = moss);
    }
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.region != region;
}
