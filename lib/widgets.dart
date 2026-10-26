import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';

const paper = Color(0xFFFAF6ED);
const ink = Color(0xFF363D34);
const moss = Color(0xFF657355);
const muted = Color(0xFF827D71);

void tell(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = '삭제',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class StickerImage extends StatelessWidget {
  const StickerImage({
    super.key,
    required this.store,
    required this.sticker,
    this.fit = BoxFit.contain,
  });
  final DiaryStore store;
  final Sticker? sticker;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => sticker == null
      ? const Icon(Icons.broken_image_outlined, color: muted)
      : Image.file(
          store.imageFile(sticker!),
          fit: fit,
          cacheWidth: 800,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined, color: muted),
          ),
        );
}

class PaperPattern extends CustomPainter {
  const PaperPattern({this.checker = false});
  final bool checker;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = checker ? const Color(0xFFE9E4DA) : const Color(0xFFDCD5C5);
    final step = checker ? 16.0 : 25.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        if (checker) {
          if (((x / step).round() + (y / step).round()).isEven) {
            canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
          }
        } else {
          canvas.drawCircle(Offset(x, y), .8, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(PaperPattern oldDelegate) =>
      oldDelegate.checker != checker;
}

class EmptyNote extends StatelessWidget {
  const EmptyNote({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.button,
  });
  final IconData icon;
  final String title, message;
  final Widget? button;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(23),
            decoration: const BoxDecoration(
              color: Color(0xFFEDE8DA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: moss),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.7),
          ),
          if (button != null) ...[const SizedBox(height: 26), button!],
        ],
      ),
    ),
  );
}

class DiaryThumbnail extends StatelessWidget {
  const DiaryThumbnail({super.key, required this.store, required this.diary});
  final DiaryStore store;
  final Diary diary;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: .707,
    child: ClipRect(
      child: IgnorePointer(
        child: ExcludeSemantics(
          // Render at a fixed page size and scale the whole composition, including
          // text, rather than reflowing the text into a small tile.
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 400,
              height: 400 / .707,
              child: DiaryPage(store: store, diary: diary),
            ),
          ),
        ),
      ),
    ),
  );
}

class DiaryPage extends StatelessWidget {
  const DiaryPage({
    super.key,
    required this.store,
    required this.diary,
    this.selected,
    this.onSelect,
    this.onMove,
    this.child,
    this.onBlank,
  });
  final DiaryStore store;
  final Diary diary;
  final String? selected;
  final ValueChanged<String>? onSelect;
  final void Function(String, Offset)? onMove;
  final VoidCallback? onBlank;
  final Widget? child;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: .707,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth, h = constraints.maxHeight;
        return ClipRect(
          child: Container(
            color: const Color(0xFFFFFDF7),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBlank,
                    child: CustomPaint(painter: _Lines()),
                  ),
                ),
                Positioned(
                  top: h * .055,
                  left: w * .075,
                  right: w * .075,
                  child: Text(
                    dateLabel(diary.date),
                    style: TextStyle(
                      fontSize: w * .04,
                      color: muted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Positioned(
                  top: h * .12,
                  left: w * .075,
                  right: w * .075,
                  bottom: h * .07,
                  child:
                      child ??
                      IgnorePointer(
                        ignoring: onSelect != null,
                        child: SingleChildScrollView(
                          child: Text(
                            diary.body,
                            style: TextStyle(
                              fontSize: w * .043,
                              height: 1.9,
                              color: ink,
                            ),
                          ),
                        ),
                      ),
                ),
                for (final p in diary.placements)
                  Positioned(
                    key: ValueKey(p.id),
                    left: p.x * w - p.width * w / 2,
                    top: p.y * h - p.width * w / 2,
                    width: p.width * w,
                    height: p.width * w,
                    child: Transform.rotate(
                      angle: p.angle,
                      child: IgnorePointer(
                        ignoring: child != null,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onSelect == null
                              ? null
                              : () => onSelect!(p.id),
                          onPanStart: onMove == null
                              ? null
                              : (_) => onSelect?.call(p.id),
                          onPanUpdate: onMove == null
                              ? null
                              : (details) {
                                  // Gesture deltas are measured in the rotated local coordinate space.
                                  final d = details.delta;
                                  onMove!(
                                    p.id,
                                    Offset(
                                      (d.dx * math.cos(p.angle) -
                                              d.dy * math.sin(p.angle)) /
                                          w,
                                      (d.dx * math.sin(p.angle) +
                                              d.dy * math.cos(p.angle)) /
                                          h,
                                    ),
                                  );
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              border: selected == p.id
                                  ? Border.all(color: moss, width: 1.5)
                                  : null,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: StickerImage(
                              store: store,
                              sticker: store.sticker(p.stickerId),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Lines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFEFEADD)
      ..strokeWidth = .6;
    for (
      double y = size.height * .165;
      y < size.height * .95;
      y += size.width * .0817
    ) {
      canvas.drawLine(
        Offset(size.width * .065, y),
        Offset(size.width * .935, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_Lines oldDelegate) => false;
}
